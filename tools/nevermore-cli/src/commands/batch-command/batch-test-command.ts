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

interface BatchTestArgs extends NevermoreGlobalArgs {
  apiKey?: string;
  base?: string;
  concurrency?: number;
  all?: boolean;
  output?: string;
  limit?: number;
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

  const names = packages.map((p) => p.name).join(', ');
  OutputHelper.info(`Testing ${packages.length} packages: ${names}`);

  if (args.dryrun) {
    OutputHelper.info('[DRYRUN] Would run tests for the above packages.');
    return;
  }

  const isGitHubActions = !!process.env.GITHUB_ACTIONS;
  const total = packages.length;
  const concurrency = args.concurrency ?? 3;
  const liveComment = new LiveTestComment(packages, concurrency);

  await liveComment.postInitialAsync();

  const callbacks: BatchTestCallbacks = {
    onPackageStart: (pkg) => {
      if (isGitHubActions) {
        console.log(`::group::${pkg.name}`);
      }
      OutputHelper.info(`Testing ${pkg.name}...`);
      liveComment.markRunning(pkg.name);
    },
    onPackageResult: (result) => {
      if (result.success) {
        OutputHelper.info(`${result.packageName} passed (${formatDurationMs(result.durationMs)})`);
      } else {
        OutputHelper.error(`${result.packageName} failed (${formatDurationMs(result.durationMs)})`);
        if (result.logs) {
          console.log(result.logs);
        }
        if (result.error) {
          OutputHelper.error(result.error);
        }
      }
      if (isGitHubActions) {
        console.log('::endgroup::');
      }
      liveComment.markComplete(result);
    },
    onProgress: (completed, _total, elapsedMs) => {
      let eta = '';
      if (completed > 0) {
        const remainingMs = (elapsedMs / completed) * (total - completed);
        eta = ` (~${formatDurationMs(remainingMs)} remaining)`;
      }
      OutputHelper.info(`Progress: ${completed}/${total} packages completed${eta}`);
    },
  };

  const apiKey = await getApiKeyAsync(args);
  const results = await runBatchTestsAsync({
    packages,
    apiKey,
    concurrency,
    callbacks,
  });

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
