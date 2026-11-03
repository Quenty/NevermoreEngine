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
  type BatchTarget,
} from '../../utils/batch/changed-packages-utils.js';
import { prepareTestAsync } from '../../utils/testing/runner/test-runner.js';
import {
  BUNDLE_FILE_SUFFIX,
  writePrebuiltBatchBundleAsync,
} from '../../utils/testing/runner/prebuilt-batch-bundle.js';

interface BatchBundleArgs extends NevermoreGlobalArgs {
  file: string;
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
    'Build the test places for changed packages into one bundle file, without an API key. ' +
    'Run it with "batch test --bundle <file>".',
  builder: (yargs) => {
    return yargs
      .positional('file', {
        describe: `File to write, conventionally <name>${BUNDLE_FILE_SUFFIX}`,
        type: 'string',
        demandOption: true,
      })
      .option('all', {
        describe: 'Bundle all packages with test targets, not just changed',
        type: 'boolean',
        default: false,
      })
      .option('base', {
        describe: 'Git ref to diff against for change detection',
        type: 'string',
        default: 'origin/main',
      })
      .option('limit', {
        describe: 'Max number of packages to bundle (for local debugging)',
        type: 'number',
      })
      .option('max-place-mb', {
        describe:
          'Size budget in MB for one combined place. Larger batches are split into several places. (default: 90, under the Open Cloud upload limit)',
        type: 'number',
      }) as any;
  },
  handler: async (args) => {
    try {
      await _runAsync(args);
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
    }
  },
};

async function _runAsync(args: BatchBundleArgs): Promise<void> {
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

  await _writeBundleAsync(args, packages);
}

async function _writeBundleAsync(
  args: BatchBundleArgs,
  packages: BatchTarget[]
): Promise<void> {
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
