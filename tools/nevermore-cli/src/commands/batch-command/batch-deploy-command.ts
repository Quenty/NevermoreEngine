import { CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  type Reporter,
  type LiveStateTracker,
  CompositeReporter,
  GithubCommentTableReporter,
  GroupedReporter,
  JsonFileReporter,
  SpinnerReporter,
  SummaryTableReporter,
} from '@quenty/cli-output-helpers/reporting';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { getApiKeyAsync } from '../../utils/auth/credential-store.js';
import { OpenCloudClient } from '../../utils/open-cloud/open-cloud-client.js';
import { RateLimiter } from '../../utils/open-cloud/rate-limiter.js';
import {
  discoverAllTargetPackagesAsync,
  discoverChangedTargetPackagesAsync,
} from '../../utils/testing/changed-tests-utils.js';
import { runBatchDeployAsync } from '../../utils/deploy/batch-deploy-runner.js';
import { createDeployCommentConfig } from '../../utils/deploy/deploy-github-columns.js';
import { isCI } from '../../utils/nevermore-cli-utils.js';

interface BatchDeployArgs extends NevermoreGlobalArgs {
  apiKey?: string;
  publish?: boolean;
  base?: string;
  concurrency?: number;
  all?: boolean;
  output?: string;
  limit?: number;
  logs?: boolean;
  target?: string;
}

export const batchDeployCommand: CommandModule<
  NevermoreGlobalArgs,
  BatchDeployArgs
> = {
  command: 'deploy',
  describe: 'Deploy changed packages with deploy targets',
  builder: (yargs) => {
    return yargs
      .option('target', {
        describe: 'Deploy target name in deploy.nevermore.json',
        type: 'string',
        default: 'deploy',
      })
      .option('api-key', {
        describe: 'Roblox Open Cloud API key',
        type: 'string',
      })
      .option('publish', {
        describe: 'Publish places (default: Saved)',
        type: 'boolean',
        default: false,
      })
      .option('all', {
        describe: 'Deploy all packages with deploy targets, not just changed',
        type: 'boolean',
        default: false,
      })
      .option('base', {
        describe: 'Git ref to diff against for change detection',
        type: 'string',
        default: 'origin/main',
      })
      .option('concurrency', {
        describe: 'Max parallel deploys',
        type: 'number',
        default: 3,
      })
      .option('output', {
        describe: 'Write JSON results to this file',
        type: 'string',
      })
      .option('limit', {
        describe: 'Max number of packages to deploy (for debugging)',
        type: 'number',
      })
      .option('logs', {
        describe: 'Show build/upload logs for all packages (not just failures)',
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

async function _runAsync(args: BatchDeployArgs): Promise<void> {
  const targetName = args.target ?? 'deploy';

  let packages = args.all
    ? await discoverAllTargetPackagesAsync(targetName)
    : await discoverChangedTargetPackagesAsync(args.base!, targetName);

  if (args.limit && args.limit > 0) {
    packages = packages.slice(0, args.limit);
  }

  if (packages.length === 0) {
    OutputHelper.warn(
      `No packages found with a "${targetName}" target. Packages need a deploy.nevermore.json with a "${targetName}" target.\n` +
        'Run "nevermore deploy init" inside a package to set one up.'
    );
    return;
  }

  if (args.dryrun) {
    const names = packages.map((p) => p.name).join(', ');
    OutputHelper.info(
      `[DRYRUN] Would deploy ${packages.length} packages: ${names}`
    );
    return;
  }

  const concurrency = args.concurrency ?? 3;
  const isGrouped = !process.stdout.isTTY || args.verbose || isCI();
  const packageNames = packages.map((p) => p.name);
  const deployLabels = {
    successLabel: 'Deployed',
    failureLabel: 'DEPLOY FAILED',
  };

  const reporter = new CompositeReporter(
    packageNames,
    (state: LiveStateTracker) => {
      const reporters: Reporter[] = [
        isGrouped
          ? new GroupedReporter(state, {
              showLogs: args.logs ?? false,
              verbose: args.verbose,
              actionVerb: 'Deploying',
              ...deployLabels,
            })
          : new SpinnerReporter(state, {
              showLogs: args.logs ?? false,
              actionVerb: 'Deploying',
              ...deployLabels,
            }),
        new SummaryTableReporter(state, {
          ...deployLabels,
          summaryVerb: 'deployed',
        }),
        new GithubCommentTableReporter(
          state,
          createDeployCommentConfig(),
          concurrency
        ),
      ];
      if (args.output) {
        reporters.push(new JsonFileReporter(state, args.output));
      }
      return reporters;
    }
  );

  const apiKey = await getApiKeyAsync(args);
  const client = new OpenCloudClient({
    apiKey,
    rateLimiter: new RateLimiter(),
  });

  await reporter.startAsync();

  const results = await runBatchDeployAsync({
    packages,
    client,
    apiKey,
    targetName,
    concurrency,
    reporter,
    bufferOutput: isGrouped,
    publish: args.publish,
  });

  await reporter.stopAsync();

  process.exit(results.summary.failed > 0 ? 1 : 0);
}
