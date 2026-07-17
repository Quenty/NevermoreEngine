import inquirer from 'inquirer';
import * as fs from 'fs/promises';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  formatTable,
  type TableColumn,
} from '@quenty/cli-output-helpers/reporting';
import { getApiKeyAsync } from '@quenty/nevermore-cli-helpers';
import {
  loadDeployConfigAsync,
  resolveDeployConfigPath,
  resolveDeployTargetPlaces,
  type BasePlaceConfig,
} from '../../utils/build/deploy-config.js';
import { OpenCloudClient } from '../../utils/open-cloud/open-cloud-client.js';
import { RateLimiter } from '../../utils/open-cloud/rate-limiter.js';
import { DeployArgs } from './index.js';

interface BasePlaceRef {
  targetName: string;
  placeLabel: string;
  basePlace: BasePlaceConfig;
}

interface UpgradeRow {
  ref: BasePlaceRef;
  from?: number;
  to: number;
  changed: boolean;
}

/**
 * `nevermore deploy version upgrade [target]` — re-pin every `basePlace` in
 * deploy.nevermore.json to its current latest published version. Without a
 * target it walks every target; pass one to scope it. `--dryrun` previews the
 * change set without writing.
 */
export async function handleVersionUpgradeAsync(
  args: DeployArgs
): Promise<void> {
  const cwd = process.cwd();
  const configPath = resolveDeployConfigPath(cwd);
  const config = await loadDeployConfigAsync(configPath);

  if (args.target && !config.targets[args.target]) {
    throw new Error(
      [
        `Target "${args.target}" not found in deploy.nevermore.json.`,
        `Available targets: ${Object.keys(config.targets).join(', ')}`,
      ].join('\n')
    );
  }

  const targetNames = args.target ? [args.target] : Object.keys(config.targets);

  // Collect every basePlace across the selected targets. Each entry keeps a
  // live reference into the parsed config so we can mutate it in place.
  const refs: BasePlaceRef[] = [];
  for (const targetName of targetNames) {
    for (const place of resolveDeployTargetPlaces(config, targetName)) {
      if (place.basePlace) {
        refs.push({
          targetName,
          placeLabel: place.name ?? targetName,
          basePlace: place.basePlace,
        });
      }
    }
  }

  if (refs.length === 0) {
    OutputHelper.warn(
      args.target
        ? `Target "${args.target}" has no basePlace to pin.`
        : 'No basePlace found in deploy.nevermore.json — nothing to pin.'
    );
    return;
  }

  // Resolve the latest version once per unique base place id — several targets
  // (e.g. integration/prod) commonly point at the same base place.
  const uniquePlaceIds = [...new Set(refs.map((r) => r.basePlace.placeId))];
  OutputHelper.info(
    `Resolving latest version for ${uniquePlaceIds.length} base place${
      uniquePlaceIds.length === 1 ? '' : 's'
    }...`
  );

  const apiKey = await getApiKeyAsync(args);
  const client = new OpenCloudClient({
    apiKey,
    rateLimiter: new RateLimiter(),
  });

  const latestByPlaceId = new Map<number, number>();
  await Promise.all(
    uniquePlaceIds.map(async (placeId) => {
      const ref = refs.find((r) => r.basePlace.placeId === placeId)!;
      const latest = await client.getLatestPlaceVersionAsync(
        ref.basePlace.universeId,
        placeId
      );
      latestByPlaceId.set(placeId, latest);
    })
  );

  const rows: UpgradeRow[] = refs.map((ref) => {
    const to = latestByPlaceId.get(ref.basePlace.placeId)!;
    const from = ref.basePlace.version;
    return { ref, from, to, changed: from !== to };
  });

  const columns: TableColumn<UpgradeRow>[] = [
    { header: 'Target', value: (r) => r.ref.targetName },
    { header: 'Place', value: (r) => r.ref.placeLabel },
    { header: 'Base place', value: (r) => String(r.ref.basePlace.placeId) },
    {
      header: 'Version',
      value: (r) =>
        `${r.from != null ? `v${r.from}` : '(latest)'} → v${r.to}${
          r.changed ? '' : '  (unchanged)'
        }`,
    },
  ];

  console.log('');
  console.log(formatTable(rows, columns, { indent: '  ' }));
  console.log('');

  const changedRows = rows.filter((r) => r.changed);
  if (changedRows.length === 0) {
    OutputHelper.info(
      'All base places are already pinned to their latest version.'
    );
    return;
  }

  if (args.dryrun) {
    OutputHelper.info(
      `[DRYRUN] Would update ${changedRows.length} pin${
        changedRows.length === 1 ? '' : 's'
      } in ${configPath}`
    );
    return;
  }

  if (!args.yes) {
    const { confirm } = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'confirm',
        message: `Update ${changedRows.length} version pin${
          changedRows.length === 1 ? '' : 's'
        } in deploy.nevermore.json?`,
        default: true,
      },
    ]);
    if (!confirm) {
      OutputHelper.info('Aborted — no changes written.');
      return;
    }
  }

  // Mutate in place — every ref.basePlace points into `config`.
  for (const row of changedRows) {
    row.ref.basePlace.version = row.to;
  }

  await fs.writeFile(configPath, JSON.stringify(config, null, 2) + '\n');
  OutputHelper.info(
    `Updated ${changedRows.length} version pin${
      changedRows.length === 1 ? '' : 's'
    } in ${configPath}`
  );
  OutputHelper.hint(
    'Commit deploy.nevermore.json, then deploy to roll base places forward.'
  );
}
