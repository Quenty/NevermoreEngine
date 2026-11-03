import { CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  AggregatedBatchReporter,
  type Reporter,
  type JobPhase,
  type ProgressSummary,
} from '@quenty/cli-output-helpers/reporting';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { getApiKeyAsync } from '@quenty/nevermore-cli-helpers';
import { runBatchAsync } from '../../utils/batch/batch-runner.js';
import { renderBatchOutcome } from '../../utils/testing/parsers/batch-log-renderer.js';
import { emitDiagnostic } from '../../utils/testing/parsers/batch-log-parser.js';
import { type DeployTarget } from '@quenty/nevermore-deploy';
import { type BuildContext } from '@quenty/nevermore-template-helpers';
import { createBasePlaceResolver } from '../../utils/build/base-place-resolver-factory.js';
import {
  type JobContext,
  BatchScriptJobContext,
  CloudJobContext,
  LocalJobContext,
} from '../../utils/job-context/index.js';
import { OpenCloudClient } from '../../utils/open-cloud/open-cloud-client.js';
import { RateLimiter } from '../../utils/open-cloud/rate-limiter.js';
import {
  discoverAllTestableBatchTargetsAsync,
  discoverChangedTestableBatchTargetsAsync,
  type BatchTarget,
} from '../../utils/batch/changed-packages-utils.js';
import {
  type LiveStateTracker,
  type BatchTestResult,
  CompositeReporter,
  GithubCommentTableReporter,
  GroupedReporter,
  JsonFileReporter,
  SpinnerReporter,
  SummaryTableReporter,
  createTestCommentConfig,
} from '../../utils/testing/reporting/index.js';
import {
  executePreparedTestAsync,
  runSingleTestAsync,
  type SingleTestOptions,
  type SingleTestResult,
} from '../../utils/testing/runner/test-runner.js';
import { type CombinedPlaceChunk } from '../../utils/testing/runner/combined-project-generator.js';
import { readPrebuiltBatchBundleAsync } from '../../utils/testing/runner/prebuilt-batch-bundle.js';
import { isCI } from '../../utils/nevermore-cli-utils.js';

interface BatchTestArgs extends NevermoreGlobalArgs {
  cloud?: boolean;
  apiKey?: string;
  base?: string;
  concurrency?: number;
  all?: boolean;
  output?: string;
  limit?: number;
  logs?: boolean;
  aggregated?: boolean;
  batchPlaceId?: number;
  batchUniverseId?: number;
  maxPlaceMb?: number;
  timeout?: number;
  bundle?: string;
}

export const batchTestCommand: CommandModule<
  NevermoreGlobalArgs,
  BatchTestArgs
> = {
  command: 'test',
  describe: 'Run tests for changed packages with test targets',
  builder: (yargs) => {
    return (
      yargs
        .option('cloud', {
          describe: 'Run tests via Open Cloud instead of locally',
          type: 'boolean',
          default: false,
        })
        .option('api-key', {
          describe: 'Roblox Open Cloud API key (--cloud only)',
          type: 'string',
        })
        .option('all', {
          describe: 'Test all packages with test targets, not just changed',
          type: 'boolean',
          default: false,
        })
        .option('base', {
          describe: 'Git ref to diff against for change detection',
          type: 'string',
          default: 'origin/main',
        })
        .option('concurrency', {
          describe: 'Max parallel tests (0 = unlimited, default: unlimited)',
          type: 'number',
        })
        .option('output', {
          describe: 'Write JSON results to this file',
          type: 'string',
        })
        .option('limit', {
          describe: 'Max number of packages to test (for local debugging)',
          type: 'number',
        })
        .option('logs', {
          describe: 'Show execution logs for all packages (not just failures)',
          type: 'boolean',
          default: false,
        })
        .option('aggregated', {
          describe:
            'Build all packages into a single place and execute one batch script',
          type: 'boolean',
          default: true,
        })
        .option('batch-place-id', {
          describe:
            'Override placeId for the aggregated batch upload (--aggregated only)',
          type: 'number',
        })
        .option('batch-universe-id', {
          describe:
            'Override universeId for the aggregated batch upload (--aggregated only)',
          type: 'number',
        })
        .option('max-place-mb', {
          describe:
            'Size budget in MB for one combined place (--aggregated only). Larger batches are split into several places that run in parallel. Open Cloud rejects place uploads over 150 MB. (default: 90 with --cloud, unlimited locally)',
          type: 'number',
        })
        .option('timeout', {
          describe:
            'Max script execution time in seconds for the whole batch. Sent to the Open Cloud API so Roblox cancels server-side on overrun. Max 300s (API limit). (default: 300)',
          type: 'number',
        })
        .option('bundle', {
          describe:
            'Run the places in a *.nevermore.tests.tar written by "batch bundle" instead of finding ' +
            'and building packages. The bundle never chooses where it is uploaded: ' +
            'that is --batch-place-id/--batch-universe-id, or else the test place this ' +
            'checkout gives one of its packages.',
          type: 'string',
        })
        // Accepted only to fail with a useful message. A batch runs one shared
        // script across packages, so there is nothing for arbitrary Luau to mean
        // here — but yargs strict mode would otherwise reject it with a bare
        // "Unknown argument" that does not say where to go instead.
        .option('script-text', {
          hidden: true,
          type: 'string',
        })
        .check((args) => {
          if (args.scriptText !== undefined) {
            throw new Error(
              '--script-text is not supported by "batch test", which runs one shared script for all packages.\n' +
                'Run it against a single package instead:\n' +
                '  cd <package> && nevermore test --cloud --script-text \'print("hi")\''
            );
          }
          if (args.bundle !== undefined) {
            if (args.all || args.limit !== undefined) {
              throw new Error(
                '--bundle runs every package in the bundle; drop --all and --limit.'
              );
            }
            if (args.aggregated === false) {
              throw new Error(
                '--bundle runs an aggregated batch; drop --no-aggregated.'
              );
            }
          }
          return true;
        })
    );
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

async function _runAsync(args: BatchTestArgs): Promise<void> {
  const prebuilt =
    args.bundle !== undefined
      ? await _loadPrebuiltRunAsync(args, args.bundle)
      : undefined;
  let exitCode: number | undefined;
  try {
    exitCode = await _runPackagesAsync(args, prebuilt);
  } finally {
    await prebuilt?.buildContext.cleanupAsync();
  }

  // Node.js fetch (undici) keeps TCP connections alive in a global pool,
  // which prevents the event loop from draining. Explicit exit required.
  if (exitCode !== undefined) {
    process.exit(exitCode);
  }
}

async function _runPackagesAsync(
  args: BatchTestArgs,
  prebuilt: PrebuiltRun | undefined
): Promise<number | undefined> {
  let packages: BatchTarget[];
  if (prebuilt) {
    packages = prebuilt.packages;
  } else {
    packages = args.all
      ? await discoverAllTestableBatchTargetsAsync()
      : await discoverChangedTestableBatchTargetsAsync(args.base!);
    if (args.limit && args.limit > 0) {
      packages = packages.slice(0, args.limit);
    }
  }

  if (packages.length === 0) {
    OutputHelper.warn(
      'No testable packages found. Packages need a deploy.nevermore.json with a "test" target.\n' +
        'Run "nevermore deploy init" inside a package to set one up.'
    );
    return undefined;
  }

  if (args.dryrun) {
    const names = packages.map((p) => p.name).join(', ');
    OutputHelper.info(
      `[DRYRUN] Would test ${packages.length} packages: ${names}`
    );
    return undefined;
  }

  const cloud = args.cloud ?? false;
  const concurrency =
    args.concurrency === undefined || args.concurrency === 0
      ? Infinity
      : args.concurrency;
  const isGrouped = !process.stdout.isTTY || args.verbose || isCI();
  const packageNames = packages.map((p) => p.name);
  const aggregated = args.aggregated ?? true;
  // Decided once, here, and passed down. Three separate isCI() lookups — the
  // renderer, OutputHelper's group markers and GroupedReporter — could each
  // answer differently, and a half-grouped log is worse than an ungrouped one.
  const presentation = { useGroups: isCI(), color: !process.env.NO_COLOR };
  let aggregatedReporter: AggregatedBatchReporter | undefined;

  const reporter = new CompositeReporter(
    packageNames,
    (state: LiveStateTracker) => {
      // An aggregated run is one execution, so there is no per-package progress
      // to report and no per-package moment to report it at.
      if (aggregated) {
        aggregatedReporter = new AggregatedBatchReporter(packages.length, {
          actionVerb: 'Testing',
        });
      }

      const reporters: Reporter[] = [
        aggregatedReporter ??
          (isGrouped
            ? new GroupedReporter(state, {
                showLogs: args.logs ?? false,
                verbose: args.verbose,
                actionVerb: 'Testing',
                expectsTestCounts: true,
              })
            : new SpinnerReporter(state, {
                showLogs: args.logs ?? false,
                actionVerb: 'Testing',
              })),
        // Told to expect counts for the same reason the grouped reporter and
        // the PR comment are: a green row with nothing behind it reads exactly
        // like a package that tested something.
        new SummaryTableReporter(state, { expectsTestCounts: true }),
      ];
      if (args.output) {
        reporters.push(new JsonFileReporter(state, args.output));
      }
      if (isCI()) {
        reporters.push(
          new GithubCommentTableReporter(
            state,
            createTestCommentConfig(),
            concurrency
          )
        );
      }
      return reporters;
    }
  );

  let client: OpenCloudClient;
  if (cloud) {
    const apiKey = await getApiKeyAsync(args);
    client = new OpenCloudClient({ apiKey, rateLimiter: new RateLimiter() });
  } else {
    client = new OpenCloudClient({
      apiKey: () => getApiKeyAsync(args),
      rateLimiter: new RateLimiter(),
    });
  }

  const timeoutMs = (args.timeout ?? 300) * 1000;

  // In aggregated mode, the inner context gets a broadcast reporter that translates
  // phase changes from the shared '_batch_' operation to all real packages
  const innerReporter: Reporter = aggregated
    ? _createBroadcastReporter(reporter, packageNames)
    : reporter;

  // Local runs get a resolver too — a package with a basePlace still has to
  // merge it, and the client resolves its API key lazily so a run that never
  // touches one is not prompted for credentials.
  const basePlaceResolver = createBasePlaceResolver(client, args);

  const innerContext: JobContext = cloud
    ? new CloudJobContext(innerReporter, client, basePlaceResolver)
    : new LocalJobContext(innerReporter, client, basePlaceResolver);

  const batchContext = aggregated
    ? new BatchScriptJobContext(innerContext, packages, {
        batchPlaceId: prebuilt?.target.placeId ?? args.batchPlaceId,
        batchUniverseId: prebuilt?.target.universeId ?? args.batchUniverseId,
        batchTimeoutMs: timeoutMs,
        // Only an upload is size-limited, so a local run stays one place
        // unless asked to split.
        maxChunkBytes:
          args.maxPlaceMb !== undefined
            ? args.maxPlaceMb * 1024 * 1024
            : cloud
            ? undefined
            : Infinity,
        reporter,
        prebuilt: prebuilt && {
          chunks: prebuilt.chunks,
          buildContext: prebuilt.buildContext,
        },
      })
    : undefined;
  const context: JobContext = batchContext ?? innerContext;

  await reporter.startAsync();

  let exitCode = 0;
  try {
    // Run the batch before the per-package loop asks for anything, for two
    // reasons. The run is shown once, in order, before any per-package result
    // could interleave with it; and the shared build, upload and execution
    // happen outside every package's async context, so the verbose output they
    // produce stops being captured into whichever package first reached the
    // shared promise — which is how the upload URL and a 78-line build list
    // came to be filed under two arbitrary packages.
    if (batchContext && aggregatedReporter) {
      // Retried the same way a package's run is. Running the batch up here took
      // it out from under the per-package retry wrapper that used to cover it,
      // and a cloud task that times out once is exactly what that retry is for.
      const outcome = await _retryOnTransientAsync('batch execution', () =>
        batchContext.getExecutionOutcomeAsync()
      );

      aggregatedReporter.printRun(renderBatchOutcome(outcome, presentation));

      for (const { level, message } of outcome.diagnostics) {
        emitDiagnostic(level, message, presentation.useGroups);
      }
    }

    const results = await runBatchAsync<BatchTarget, BatchTestResult>({
      items: packages,
      concurrency,
      reporter,
      bufferOutput: isGrouped,
      stateTracker: reporter.state,
      executeAsync: async (pkg) => {
        const result = await _runWithRetryAsync(
          pkg,
          context,
          timeoutMs,
          aggregated,
          prebuilt?.hasJestConfig.get(pkg.name)
        );

        return {
          packageName: pkg.name,
          placeId: pkg.target.placeId,
          success: result.success,
          logs: result.logs,
          // Aggregated mode reports per-package pcall time; the outer
          // wall-clock would otherwise be identical for every package
          // (they all await the same shared batch execution).
          durationMs: result.durationMs,
          progressSummary: result.testCounts
            ? { kind: 'test-counts' as const, ...result.testCounts }
            : undefined,
          // Every reporter downstream reads state through resolveResultStatus,
          // so a run judged without its logs is marked once here rather than
          // being re-derived by each of them.
          caveats: result.logsLost
            ? (['logs-lost'] as const).slice()
            : undefined,
          error: result.error,
        };
      },
    });
    if (results.summary.failed > 0) exitCode = 1;
  } catch (err) {
    OutputHelper.error(OutputHelper.formatErrorChain(err));
    exitCode = 1;
  } finally {
    await context.disposeAsync();
  }

  await reporter.stopAsync();
  return exitCode;
}

async function _runWithRetryAsync(
  pkg: BatchTarget,
  context: JobContext,
  timeoutMs: number,
  aggregated: boolean,
  prebuiltHasJestConfig: boolean | undefined
): Promise<SingleTestResult> {
  const opts: SingleTestOptions = {
    packagePath: pkg.path,
    packageName: pkg.name,
    timeoutMs,
    target: pkg.target,
    // One fetch serves every package here, so its provenance is reported once
    // for the whole batch rather than restated per package.
    suppressCountsProvenance: aggregated,
  };

  if (prebuiltHasJestConfig !== undefined) {
    return _retryOnTransientAsync(pkg.name, async () =>
      executePreparedTestAsync(
        context,
        {
          builtPlace: await context.buildPlaceAsync(opts),
          scriptContent: '',
          hasJestConfig: prebuiltHasJestConfig,
        },
        opts
      )
    );
  }

  return _retryOnTransientAsync(pkg.name, () =>
    runSingleTestAsync(context, opts)
  );
}

interface PrebuiltRun {
  target: DeployTarget;
  packages: BatchTarget[];
  chunks: CombinedPlaceChunk[];
  hasJestConfig: Map<string, boolean>;
  buildContext: BuildContext;
}

async function _loadPrebuiltRunAsync(
  args: BatchTestArgs,
  bundleFile: string
): Promise<PrebuiltRun> {
  const bundle = await readPrebuiltBatchBundleAsync(bundleFile);
  let target: DeployTarget;
  try {
    target = await _resolvePrebuiltTargetAsync(
      args,
      new Set(bundle.packages.map((p) => p.name))
    );
  } catch (err) {
    await bundle.buildContext.cleanupAsync();
    throw err;
  }

  OutputHelper.info(
    `Running ${bundle.packages.length} prebuilt package${
      bundle.packages.length === 1 ? '' : 's'
    } in ${bundle.chunks.length} place${
      bundle.chunks.length === 1 ? '' : 's'
    } on place ${target.placeId}.`
  );

  return {
    target,
    packages: bundle.packages.map((p) => ({
      name: p.name,
      packageName: p.name,
      path: process.cwd(),
      target,
    })),
    chunks: bundle.chunks,
    hasJestConfig: new Map(
      bundle.packages.map((p) => [p.name, p.hasJestConfig])
    ),
    buildContext: bundle.buildContext,
  };
}

/**
 * Where a bundle uploads to, picked the way a normal batch run picks it: the
 * test place of one of its packages, read from this checkout rather than from
 * the bundle.
 */
async function _resolvePrebuiltTargetAsync(
  args: BatchTestArgs,
  bundledNames: Set<string>
): Promise<DeployTarget> {
  const known = await discoverAllTestableBatchTargetsAsync();
  const base = known.find((t) => bundledNames.has(t.name)) ?? known[0];
  const universeId = args.batchUniverseId ?? base?.target.universeId;
  const placeId = args.batchPlaceId ?? base?.target.placeId;
  if (!universeId || !placeId) {
    throw new Error(
      'No test place to upload the bundle to: this checkout has no testable ' +
        'package. Pass --batch-place-id and --batch-universe-id.'
    );
  }
  return { universeId, placeId, project: '' };
}

/**
 * Run something once more if it failed for a reason that tends not to repeat.
 *
 * Shared so the batch execution and a single package's run agree on what counts
 * as transient — the batch used to inherit this by being triggered from inside
 * a package's run, and stopped when it moved out to the command.
 */
async function _retryOnTransientAsync<T>(
  label: string,
  runAsync: () => Promise<T>
): Promise<T> {
  try {
    return await runAsync();
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);

    if (message.includes('timed out') || message.includes('fetch failed')) {
      OutputHelper.warn(`${label}: transient failure, retrying...`);
      return await runAsync();
    }

    throw err;
  }
}

function _createBroadcastReporter(
  target: Reporter,
  packageNames: string[]
): Reporter {
  // Phases from the inner context apply to the whole batch in aggregated mode.
  // The cloud poll loop re-fires 'executing' on every poll tick, and we don't
  // want that to keep flushing identical updates downstream — dedupe on the
  // last broadcast phase so each transition is reported exactly once.
  let lastBroadcastPhase: JobPhase | undefined;
  return {
    startAsync: async () => {},
    stopAsync: async () => {},
    onPackageStart: () => {},
    onPackageResult: () => {},
    onPackagePhaseChange: (_name: string, phase: JobPhase) => {
      if (lastBroadcastPhase === phase) return;
      lastBroadcastPhase = phase;
      for (const name of packageNames) {
        target.onPackagePhaseChange(name, phase);
      }
    },
    onPackageProgressUpdate: (_name: string, progress: ProgressSummary) => {
      // Upload progress (byte transfer) is genuinely informative when fanned
      // out. Poll progress during 'executing' is just an incrementing counter
      // duplicated across every row, so skip it once we're in lock-step.
      if (lastBroadcastPhase === 'executing') return;
      for (const name of packageNames) {
        target.onPackageProgressUpdate(name, progress);
      }
    },
  };
}
