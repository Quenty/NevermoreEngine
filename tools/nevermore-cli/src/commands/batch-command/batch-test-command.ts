import * as fs from 'fs/promises';
import { CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { getApiKeyAsync } from '../../utils/auth/credential-store.js';
import {
  discoverAllTestablePackagesAsync,
  discoverChangedTestablePackagesAsync,
} from '../../utils/testing/changed-tests-utils.js';
import {
  runBatchTestsAsync,
  BatchTestSummary,
  type BatchTestCallbacks,
} from '../../utils/testing/batch-test-runner.js';
import { formatDurationMs } from '../../utils/nevermore-cli-utils.js';
import { LiveTestComment } from '../../utils/testing/live-test-comment.js';
import { BatchTestReporter } from '../../utils/testing/batch-test-reporter.js';

interface BatchTestArgs extends NevermoreGlobalArgs {
  apiKey?: string;
  base?: string;
  concurrency?: number;
  all?: boolean;
  output?: string;
  limit?: number;
  logs?: boolean;
}

export const batchTestCommand: CommandModule<NevermoreGlobalArgs, BatchTestArgs> = {
  command: 'test',
  describe: 'Run tests for changed packages with test targets',
  builder: (yargs) => {
    return yargs
      .option('api-key', {
        describe: 'Roblox Open Cloud API key',
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
        describe: 'Max parallel tests',
        type: 'number',
        default: 3,
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
    OutputHelper.info(`[DRYRUN] Would test ${packages.length} packages: ${names}`);
    return;
  }

  const concurrency = args.concurrency ?? 3;
  const liveComment = new LiveTestComment(packages, concurrency);
  const reporter = new BatchTestReporter(packages, { verbose: args.verbose, showLogs: args.logs ?? false });

  await liveComment.postInitialAsync();

  const callbacks: BatchTestCallbacks = {
    onPackageStart: (pkg) => {
      reporter.onPackageStart(pkg.name);
      liveComment.markRunning(pkg.name);
    },
    onPackagePhaseChange: (name, phase) => {
      reporter.onPackagePhaseChange(name, phase);
      liveComment.markPhase(name, phase);
    },
    onPackageResult: (result, bufferedOutput) => {
      reporter.onPackageResult(result, bufferedOutput);
      liveComment.markComplete(result);
    },
  };

  const apiKey = await getApiKeyAsync(args);

  reporter.start();

  const results = await runBatchTestsAsync({
    packages,
    apiKey,
    concurrency,
    callbacks,
    bufferOutput: reporter.mode === 'grouped',
  });

  reporter.stop();

  await liveComment.flushAsync();
  _printResultsTable(results);

  if (args.output) {
    await fs.writeFile(args.output, JSON.stringify(results, null, 2));
    OutputHelper.info(`Results written to ${args.output}`);
  }

  // Node.js fetch (undici) keeps TCP connections alive in a global pool,
  // which prevents the event loop from draining. Explicit exit required.
  process.exit(results.summary.failed > 0 ? 1 : 0);
}

function _printResultsTable(results: BatchTestSummary): void {
  console.log('');
  console.log('Package'.padEnd(40) + 'Status'.padEnd(10) + 'Duration');
  console.log('-'.repeat(60));

  for (const result of results.packages) {
    const status = result.success
      ? OutputHelper.formatSuccess('Passed')
      : OutputHelper.formatError('FAILED');
    const duration = OutputHelper.formatDim(formatDurationMs(result.durationMs));
    console.log(result.packageName.padEnd(40) + status.padEnd(20) + duration);
  }

  console.log('');
  const passed = OutputHelper.formatSuccess(`${results.summary.passed} passed`);
  const failed = results.summary.failed > 0
    ? OutputHelper.formatError(`${results.summary.failed} failed`)
    : `${results.summary.failed} failed`;
  const totalTime = OutputHelper.formatDim(`in ${formatDurationMs(results.summary.durationMs)}`);
  console.log(`${results.summary.total} tested, ${passed}, ${failed} ${totalTime}`);
}
