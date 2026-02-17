import { CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { type Reporter } from '@quenty/cli-output-helpers/reporting';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { getApiKeyAsync } from '../../utils/auth/credential-store.js';
import { runBatchAsync } from '../../utils/batch/batch-runner.js';
import {
  type JobContext,
  CloudJobContext,
  LocalJobContext,
} from '../../utils/job-context/index.js';
import { OpenCloudClient } from '../../utils/open-cloud/open-cloud-client.js';
import { RateLimiter } from '../../utils/open-cloud/rate-limiter.js';
import {
  discoverAllTestablePackagesAsync,
  discoverChangedTestablePackagesAsync,
  type TargetPackage,
} from '../../utils/batch/changed-packages-utils.js';
import {
  type LiveStateTracker,
  type BatchTestResult,
  type BatchTestSummary,
  CompositeReporter,
  GithubCommentTableReporter,
  GroupedReporter,
  JsonFileReporter,
  SpinnerReporter,
  SummaryTableReporter,
  createTestCommentConfig,
} from '../../utils/testing/reporting/index.js';
import {
  runSingleTestAsync,
  type SingleTestResult,
} from '../../utils/testing/runner/test-runner.js';
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
}

export const batchTestCommand: CommandModule<
  NevermoreGlobalArgs,
  BatchTestArgs
> = {
  command: 'test',
  describe: 'Run tests for changed packages with test targets',
  builder: (yargs) => {
    return yargs
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
        describe: 'Max parallel tests (default: 1 local, 3 cloud)',
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
      });
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
  let packages = args.all
    ? await discoverAllTestablePackagesAsync()
    : await discoverChangedTestablePackagesAsync(args.base!);

  if (args.limit && args.limit > 0) {
    packages = packages.slice(0, args.limit);
  }

  if (packages.length === 0) {
    OutputHelper.warn(
      'No testable packages found. Packages need a deploy.nevermore.json with a "test" target.\n' +
        'Run "nevermore deploy init" inside a package to set one up.'
    );
    return;
  }

  if (args.dryrun) {
    const names = packages.map((p) => p.name).join(', ');
    OutputHelper.info(
      `[DRYRUN] Would test ${packages.length} packages: ${names}`
    );
    return;
  }

  const cloud = args.cloud ?? false;
  const concurrency = args.concurrency ?? 3;
  const isGrouped = !process.stdout.isTTY || args.verbose || isCI();
  const packageNames = packages.map((p) => p.name);

  const reporter = new CompositeReporter(
    packageNames,
    (state: LiveStateTracker) => {
      const reporters: Reporter[] = [
        isGrouped
          ? new GroupedReporter(state, {
              showLogs: args.logs ?? false,
              verbose: args.verbose,
              actionVerb: 'Testing',
            })
          : new SpinnerReporter(state, {
              showLogs: args.logs ?? false,
              actionVerb: 'Testing',
            }),
        new SummaryTableReporter(state),
        new GithubCommentTableReporter(
          state,
          createTestCommentConfig(),
          concurrency
        ),
      ];
      if (args.output) {
        reporters.push(new JsonFileReporter(state, args.output));
      }
      return reporters;
    }
  );

  let client: OpenCloudClient | undefined;
  if (cloud) {
    const apiKey = await getApiKeyAsync(args);
    client = new OpenCloudClient({ apiKey, rateLimiter: new RateLimiter() });
  }

  const context: JobContext = client
    ? new CloudJobContext(client)
    : new LocalJobContext();

  await reporter.startAsync();

  const timeoutMs = 120_000;
  let results: BatchTestSummary;
  try {
    results = await runBatchAsync<BatchTestResult>({
      packages,
      concurrency,
      reporter,
      bufferOutput: isGrouped,
      executeAsync: async (pkg, pkgReporter) => {
        const result = await _runWithRetryAsync(
          pkg,
          context,
          timeoutMs,
          pkgReporter
        );

        return {
          packageName: pkg.name,
          placeId: pkg.target.placeId,
          success: result.success,
          logs: result.logs,
        };
      },
    });
  } finally {
    await context.disposeAsync();
  }

  await reporter.stopAsync();

  // Node.js fetch (undici) keeps TCP connections alive in a global pool,
  // which prevents the event loop from draining. Explicit exit required.
  process.exit(results.summary.failed > 0 ? 1 : 0);
}

async function _runWithRetryAsync(
  pkg: TargetPackage,
  context: JobContext,
  timeoutMs: number,
  reporter: Reporter
): Promise<SingleTestResult> {
  const opts = {
    packagePath: pkg.path,
    packageName: pkg.name,
    timeoutMs,
  };

  try {
    return await runSingleTestAsync(context, reporter, opts);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);

    if (message.includes('timed out') || message.includes('fetch failed')) {
      OutputHelper.warn(`${pkg.name}: transient failure, retrying...`);
      return await runSingleTestAsync(context, reporter, opts);
    }

    throw err;
  }
}
