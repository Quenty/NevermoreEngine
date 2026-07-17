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
  type DeployConfig,
} from '../../utils/build/deploy-config.js';
import { OpenCloudClient } from '../../utils/open-cloud/open-cloud-client.js';
import { RateLimiter } from '../../utils/open-cloud/rate-limiter.js';
import { DeployArgs } from './index.js';

interface BasePlaceRef {
  targetName: string;
  placeLabel: string;
  basePlace: BasePlaceConfig;
}

/** A pending change: set `ref.basePlace.version` to `to`. */
interface PinChange {
  ref: BasePlaceRef;
  from?: number;
  to: number;
}

export interface VersionPromoteArgs extends DeployArgs {
  from?: string;
  to?: string;
}

function _plural(count: number): string {
  return count === 1 ? '' : 's';
}

function _requireTarget(config: DeployConfig, targetName: string): void {
  if (!config.targets[targetName]) {
    throw new Error(
      [
        `Target "${targetName}" not found in deploy.nevermore.json.`,
        `Available targets: ${Object.keys(config.targets).join(', ')}`,
      ].join('\n')
    );
  }
}

/** Collect every basePlace across the given targets, keeping live references. */
function _collectBasePlaceRefs(
  config: DeployConfig,
  targetNames: string[]
): BasePlaceRef[] {
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
  return refs;
}

/**
 * Gate the change set on --dryrun / confirmation, apply it in place, and write
 * the config back. `changes` may include no-op entries; only entries whose
 * version actually differs are counted and applied. Returns nothing — messaging
 * is handled here so the two commands stay consistent.
 */
async function _commitPinChangesAsync(
  configPath: string,
  config: DeployConfig,
  changes: PinChange[],
  args: { dryrun?: boolean; yes?: boolean }
): Promise<void> {
  const changed = changes.filter((c) => c.from !== c.to);
  if (changed.length === 0) {
    OutputHelper.info('Nothing to change — pins are already up to date.');
    return;
  }

  if (args.dryrun) {
    OutputHelper.info(
      `[DRYRUN] Would update ${changed.length} pin${_plural(
        changed.length
      )} in ${configPath}`
    );
    return;
  }

  if (!args.yes) {
    const { confirm } = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'confirm',
        message: `Update ${changed.length} version pin${_plural(
          changed.length
        )} in deploy.nevermore.json?`,
        default: true,
      },
    ]);
    if (!confirm) {
      OutputHelper.info('Aborted — no changes written.');
      return;
    }
  }

  // Mutate in place — every ref.basePlace points into `config`.
  for (const change of changed) {
    change.ref.basePlace.version = change.to;
  }

  await fs.writeFile(configPath, JSON.stringify(config, null, 2) + '\n');
  OutputHelper.info(
    `Updated ${changed.length} version pin${_plural(
      changed.length
    )} in ${configPath}`
  );
  OutputHelper.hint(
    'Commit deploy.nevermore.json, then deploy to roll base places forward.'
  );
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

  if (args.target) {
    _requireTarget(config, args.target);
  }

  const targetNames = args.target ? [args.target] : Object.keys(config.targets);
  const refs = _collectBasePlaceRefs(config, targetNames);

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
    `Resolving latest version for ${uniquePlaceIds.length} base place${_plural(
      uniquePlaceIds.length
    )}...`
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

  const changes: PinChange[] = refs.map((ref) => ({
    ref,
    from: ref.basePlace.version,
    to: latestByPlaceId.get(ref.basePlace.placeId)!,
  }));

  const columns: TableColumn<PinChange>[] = [
    { header: 'Target', value: (c) => c.ref.targetName },
    { header: 'Place', value: (c) => c.ref.placeLabel },
    { header: 'Base place', value: (c) => String(c.ref.basePlace.placeId) },
    { header: 'Version', value: (c) => _formatChange(c) },
  ];

  console.log('');
  console.log(formatTable(changes, columns, { indent: '  ' }));
  console.log('');

  await _commitPinChangesAsync(configPath, config, changes, args);
}

/**
 * `nevermore deploy version promote <from> <to>` — copy the base-place version
 * pins from one target to another (e.g. promote validated `production-demo`
 * pins to `production`). Places are matched by their base place id, so the same
 * source content lines up even when the two targets name their places
 * differently. Pure config edit — no network. `--dryrun` previews.
 */
export async function handleVersionPromoteAsync(
  args: VersionPromoteArgs
): Promise<void> {
  const fromTarget = args.from;
  const toTarget = args.to;
  if (!fromTarget || !toTarget) {
    throw new Error(
      'Usage: nevermore deploy version copy <from-target> <to-target>'
    );
  }
  if (fromTarget === toTarget) {
    throw new Error('The <from> and <to> targets must be different.');
  }

  const cwd = process.cwd();
  const configPath = resolveDeployConfigPath(cwd);
  const config = await loadDeployConfigAsync(configPath);

  _requireTarget(config, fromTarget);
  _requireTarget(config, toTarget);

  // Map base place id -> pinned version from the source target. A source with
  // the same base place pinned to two different versions is inconsistent, so
  // fail loudly rather than pick one arbitrarily.
  const versionByPlaceId = new Map<number, number>();
  for (const ref of _collectBasePlaceRefs(config, [fromTarget])) {
    const version = ref.basePlace.version;
    if (version == null) {
      continue;
    }
    const existing = versionByPlaceId.get(ref.basePlace.placeId);
    if (existing != null && existing !== version) {
      throw new Error(
        `Target "${fromTarget}" pins base place ${ref.basePlace.placeId} to ` +
          `two different versions (v${existing} and v${version}). ` +
          `Run "nevermore deploy version upgrade ${fromTarget}" to make it consistent first.`
      );
    }
    versionByPlaceId.set(ref.basePlace.placeId, version);
  }

  if (versionByPlaceId.size === 0) {
    OutputHelper.warn(
      `Target "${fromTarget}" has no pinned base place versions to copy. ` +
        `Run "nevermore deploy version upgrade ${fromTarget}" first.`
    );
    return;
  }

  const toRefs = _collectBasePlaceRefs(config, [toTarget]);
  if (toRefs.length === 0) {
    OutputHelper.warn(`Target "${toTarget}" has no basePlace to copy pins to.`);
    return;
  }

  const changes: PinChange[] = [];
  const unmatched: BasePlaceRef[] = [];
  for (const ref of toRefs) {
    const source = versionByPlaceId.get(ref.basePlace.placeId);
    if (source == null) {
      unmatched.push(ref);
      continue;
    }
    changes.push({ ref, from: ref.basePlace.version, to: source });
  }

  const columns: TableColumn<PinChange>[] = [
    { header: 'Place', value: (c) => c.ref.placeLabel },
    { header: 'Base place', value: (c) => String(c.ref.basePlace.placeId) },
    { header: 'Version', value: (c) => _formatChange(c) },
  ];

  console.log('');
  OutputHelper.info(`Promoting pins from "${fromTarget}" to "${toTarget}":`);
  console.log(formatTable(changes, columns, { indent: '  ' }));
  console.log('');

  if (unmatched.length > 0) {
    OutputHelper.warn(
      `${unmatched.length} place${_plural(
        unmatched.length
      )} in "${toTarget}" had no matching pin in "${fromTarget}" (left unchanged): ` +
        unmatched
          .map((r) => `${r.placeLabel} (${r.basePlace.placeId})`)
          .join(', ')
    );
  }

  await _commitPinChangesAsync(configPath, config, changes, args);
}

function _formatChange(change: PinChange): string {
  const from = change.from != null ? `v${change.from}` : '(latest)';
  const unchanged = change.from === change.to ? '  (unchanged)' : '';
  return `${from} → v${change.to}${unchanged}`;
}
