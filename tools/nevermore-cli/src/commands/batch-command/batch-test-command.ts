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

interface BatchTestArgs extends NevermoreGlobalArgs {
  apiKey?: string;
  base?: string;
  concurrency?: number;
  all?: boolean;
  output?: string;
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
  const packages = args.all
    ? await discoverAllTestablePackagesAsync()
    : await discoverChangedTestablePackagesAsync(args.base!);

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

  const callbacks: BatchTestCallbacks = {
    onPackageStart: (pkg) => {
      if (isGitHubActions) {
        console.log(`::group::${pkg.name}`);
      }
      OutputHelper.info(`Testing ${pkg.name}...`);
    },
    onPackageResult: (result) => {
      if (result.success) {
        OutputHelper.info(`${result.packageName} passed (${(result.durationMs / 1000).toFixed(1)}s)`);
      } else {
        OutputHelper.error(`${result.packageName} failed (${(result.durationMs / 1000).toFixed(1)}s)`);
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
    },
    onProgress: (completed, _total, elapsedMs) => {
      let eta = '';
      if (completed > 0) {
        const avgMs = elapsedMs / completed;
        const remainingMs = avgMs * (total - completed);
        const remainingSec = Math.ceil(remainingMs / 1000);
        if (remainingSec >= 60) {
          const min = Math.floor(remainingSec / 60);
          const sec = remainingSec % 60;
          eta = ` (~${min}m${sec}s remaining)`;
        } else {
          eta = ` (~${remainingSec}s remaining)`;
        }
      }
      OutputHelper.info(`Progress: ${completed}/${total} packages completed${eta}`);
    },
  };

  const apiKey = await getApiKeyAsync(args);
  const results = await runBatchTestsAsync({
    packages,
    apiKey,
    concurrency: args.concurrency,
    callbacks,
  });

  _printResultsTable(results);

  if (args.output) {
    await fs.writeFile(args.output, JSON.stringify(results, null, 2));
    OutputHelper.info(`Results written to ${args.output}`);
  }

  if (results.summary.failed > 0) {
    process.exit(1);
  }
}

function _printResultsTable(results: BatchTestSummary): void {
  console.log('');
  console.log('Package'.padEnd(40) + 'Status'.padEnd(10) + 'Duration');
  console.log('-'.repeat(60));

  for (const result of results.packages) {
    const status = result.success ? 'Passed' : 'FAILED';
    const duration = `${(result.durationMs / 1000).toFixed(1)}s`;
    console.log(result.packageName.padEnd(40) + status.padEnd(10) + duration);
  }

  console.log('');
  console.log(
    `${results.summary.total} tested, ${results.summary.passed} passed, ${results.summary.failed} failed`
  );
}
