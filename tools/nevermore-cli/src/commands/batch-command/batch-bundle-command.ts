import * as path from 'path';
import { CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { BaseReporter } from '@quenty/cli-output-helpers/reporting';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import {
  BatchScriptJobContext,
  LocalJobContext,
} from '../../utils/job-context/index.js';
import {
  discoverAllTestableBatchTargetsAsync,
  discoverChangedTestableBatchTargetsAsync,
  discoverDeployBatchTargetsAsync,
} from '../../utils/batch/changed-packages-utils.js';
import { gatherGitDeployInfo } from '../../utils/deploy/deploy-metadata.js';
import {
  DEPLOY_BUNDLE_FILE_SUFFIX,
  type PrebuiltDeployPlace,
  writePrebuiltDeployBundleAsync,
} from '../../utils/deploy/prebuilt-deploy-bundle.js';
import { readPackageVersionAsync } from '../../utils/nevermore-cli-utils.js';
import { prepareTestAsync } from '../../utils/testing/runner/test-runner.js';
import {
  BUNDLE_FILE_SUFFIX,
  writePrebuiltBatchBundleAsync,
} from '../../utils/testing/runner/prebuilt-batch-bundle.js';

interface BatchBundleArgs extends NevermoreGlobalArgs {
  file: string;
  test?: boolean;
  deploy?: boolean;
  target?: string;
  base?: string;
  all?: boolean;
  limit?: number;
  maxPlaceMb?: number;
}

export const batchBundleCommand: CommandModule<
  NevermoreGlobalArgs,
  BatchBundleArgs
> = {
  command: 'bundle <file>',
  describe:
    'Build what "batch test" or "batch deploy" would run into one bundle file, without an API key. ' +
    'Run it later with "batch test --bundle <file>" or "batch deploy --bundle <file>".',
  builder: (yargs) => {
    return yargs
      .positional('file', {
        describe: `File to write, conventionally <name>${BUNDLE_FILE_SUFFIX} or <name>${DEPLOY_BUNDLE_FILE_SUFFIX}`,
        type: 'string',
        demandOption: true,
      })
      .option('test', {
        describe: 'Bundle the combined test places "batch test" would run',
        type: 'boolean',
      })
      .option('deploy', {
        describe:
          'Bundle the places "batch deploy" would deploy, without their base place, which the deploying run merges',
        type: 'boolean',
      })
      .option('target', {
        describe: 'Deploy target name in deploy.nevermore.json (--deploy only)',
        type: 'string',
      })
      .option('all', {
        describe: 'Bundle every package, not just changed ones',
        type: 'boolean',
        default: false,
      })
      .option('base', {
        describe: 'Git ref to diff against for change detection',
        type: 'string',
        default: 'origin/main',
      })
      .option('limit', {
        describe: 'Max number of packages to bundle (for debugging)',
        type: 'number',
      })
      .option('max-place-mb', {
        describe:
          'Size budget in MB for one combined place (--test only). Larger batches are split into several places. (default: 90, under the Open Cloud upload limit)',
        type: 'number',
      })
      .check((args) => {
        if (args.test === args.deploy || (!args.test && !args.deploy)) {
          throw new Error('Pass exactly one of --test or --deploy.');
        }
        if (args.test && args.target !== undefined) {
          throw new Error(
            '--target picks a deploy target; it applies to --deploy only.'
          );
        }
        if (args.deploy && args.maxPlaceMb !== undefined) {
          throw new Error(
            '--max-place-mb sizes combined test places; it applies to --test only.'
          );
        }
        return true;
      }) as any;
  },
  handler: async (args) => {
    try {
      if (args.deploy) {
        await _writeDeployBundleAsync(args);
      } else {
        await _writeTestBundleAsync(args);
      }
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
    }
  },
};

async function _writeTestBundleAsync(args: BatchBundleArgs): Promise<void> {
  let packages = args.all
    ? await discoverAllTestableBatchTargetsAsync()
    : await discoverChangedTestableBatchTargetsAsync(args.base!);
  if (args.limit && args.limit > 0) {
    packages = packages.slice(0, args.limit);
  }

  if (args.dryrun) {
    OutputHelper.info(
      `[DRYRUN] Would bundle ${packages.length} packages: ${packages
        .map((p) => p.name)
        .join(', ')}`
    );
    return;
  }

  if (packages.length === 0) {
    OutputHelper.warn('No testable packages found; writing an empty bundle.');
    await writePrebuiltBatchBundleAsync(args.file, [], new Map());
    return;
  }

  // No client: building never uploads, so there is no key to need.
  const batchContext = new BatchScriptJobContext(
    new LocalJobContext(new BaseReporter()),
    packages,
    {
      maxChunkBytes:
        args.maxPlaceMb !== undefined
          ? args.maxPlaceMb * 1024 * 1024
          : undefined,
    }
  );

  try {
    // Prepared one at a time so every package's deploy-metadata stamp lands in
    // the shared place before it is packed, and the last package's stamp wins.
    // A live aggregated run stamps only after the shared place has uploaded,
    // so its specs never see a stamp at all.
    const hasJestConfig = new Map<string, boolean>();
    for (const pkg of packages) {
      const prepared = await prepareTestAsync(batchContext, {
        packagePath: pkg.path,
        packageName: pkg.name,
        target: pkg.target,
      });
      hasJestConfig.set(pkg.name, prepared.hasJestConfig);
    }

    const chunks = await batchContext.getBuiltChunksAsync();
    await writePrebuiltBatchBundleAsync(args.file, chunks, hasJestConfig);
    OutputHelper.info(
      `Wrote ${packages.length} package${packages.length === 1 ? '' : 's'} in ${
        chunks.length
      } place${chunks.length === 1 ? '' : 's'} to ${args.file}.`
    );
  } finally {
    await batchContext.disposeAsync();
  }
}

async function _writeDeployBundleAsync(args: BatchBundleArgs): Promise<void> {
  const targetName = args.target ?? 'test';
  const batchTargets = await discoverDeployBatchTargetsAsync({
    targetName,
    all: args.all,
    base: args.base!,
    limit: args.limit,
  });

  if (args.dryrun) {
    OutputHelper.info(
      `[DRYRUN] Would bundle ${batchTargets.length} places: ${batchTargets
        .map((p) => p.name)
        .join(', ')}`
    );
    return;
  }

  if (batchTargets.length === 0) {
    OutputHelper.warn(
      `No changed packages have a "${targetName}" target; writing an empty bundle.`
    );
  }

  const context = new LocalJobContext(new BaseReporter());
  try {
    const places: PrebuiltDeployPlace[] = [];
    for (const buildTarget of batchTargets) {
      const built = await context.buildPlaceAsync({
        target: buildTarget.target,
        packagePath: buildTarget.path,
        packageName: buildTarget.name,
        outputFileName: 'deploy.rbxl',
        deferBasePlaceMerge: true,
      });
      places.push({
        name: buildTarget.name,
        rbxlPath: built.rbxlPath,
        projectPath: path.resolve(buildTarget.path, buildTarget.target.project),
        packageVersion: await readPackageVersionAsync(buildTarget.path),
      });
    }

    await writePrebuiltDeployBundleAsync(
      args.file,
      targetName,
      gatherGitDeployInfo(),
      places
    );
    OutputHelper.info(
      `Wrote ${places.length} place${places.length === 1 ? '' : 's'} to ${
        args.file
      }.`
    );
  } finally {
    await context.disposeAsync();
  }
}
