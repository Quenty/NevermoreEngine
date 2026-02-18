import * as fs from 'fs/promises';
import { CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  type Reporter,
  type LiveStateTracker,
  CompositeReporter,
  GroupedReporter,
  JsonFileReporter,
  SpinnerReporter,
  SummaryTableReporter,
} from '@quenty/cli-output-helpers/reporting';
import { resolvePackagePath } from '@quenty/nevermore-template-helpers';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { getApiKeyAsync } from '../../utils/auth/credential-store.js';
import { runBatchAsync } from '../../utils/batch/batch-runner.js';
import { uploadPlaceAsync } from '../../utils/build/upload.js';
import { type BatchDeployResult } from '../../utils/deploy/deploy-github-columns.js';
import { OpenCloudClient } from '../../utils/open-cloud/open-cloud-client.js';
import { RateLimiter } from '../../utils/open-cloud/rate-limiter.js';
import { CloudJobContext } from '../../utils/job-context/cloud-job-context.js';
import {
  discoverAllTargetPackagesAsync,
  discoverChangedTargetPackagesAsync,
} from '../../utils/batch/changed-packages-utils.js';
import { isCI } from '../../utils/nevermore-cli-utils.js';
import { parseTestLogs } from '../../utils/testing/test-log-parser.js';

const SMOKE_TEST_SCRIPT_PATH = resolvePackagePath(
  import.meta.url,
  'build-scripts', 'smoke-test-server.luau'
);

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
        default: 'test',
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
  const targetName = args.target ?? 'test';

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
  const context = new CloudJobContext(client);

  await reporter.startAsync();

  try {
    const publish = args.publish ?? false;
    const results = await runBatchAsync<BatchDeployResult>({
      packages,
      concurrency,
      reporter,
      bufferOutput: isGrouped,
      executeAsync: async (pkg, pkgReporter) => {
        const builtPlace = await context.buildPlaceAsync({
          targetName,
          outputFileName: publish ? 'publish.rbxl' : 'deploy.rbxl',
          packagePath: pkg.path,
          reporter: pkgReporter,
          packageName: pkg.name,
        });

        const { version } = await uploadPlaceAsync({
          builtPlace,
          args: { apiKey, publish },
          client,
          reporter: pkgReporter,
          packageName: pkg.name,
        });

        // Eagerly release build artifacts after upload
        await context.releaseBuiltPlaceAsync(builtPlace);

        // Run smoke test for targets with basePlace
        let logs: string;
        if (pkg.target.basePlace) {
          const smokeResult = await _runSmokeTestAsync(
            pkgReporter,
            pkg.name,
            pkg.target.universeId,
            pkg.target.placeId,
            version,
            client
          );
          logs = smokeResult.logs;
          if (!smokeResult.success) {
            return {
              packageName: pkg.name,
              placeId: pkg.target.placeId,
              success: false,
              logs,
            };
          }
        } else {
          const action = publish ? 'Published' : 'Saved';
          logs = `${action} v${version}`;
        }

        return {
          packageName: pkg.name,
          placeId: pkg.target.placeId,
          success: true,
          logs,
        };
      },
    });

    await reporter.stopAsync();

    process.exit(results.summary.failed > 0 ? 1 : 0);
  } finally {
    await context.disposeAsync();
  }
}

async function _runSmokeTestAsync(
  reporter: Reporter,
  packageName: string,
  universeId: number,
  placeId: number,
  version: number,
  client: OpenCloudClient
): Promise<{ success: boolean; logs: string }> {
  let scriptContent: string;
  try {
    scriptContent = await fs.readFile(SMOKE_TEST_SCRIPT_PATH, 'utf-8');
  } catch {
    throw new Error(`Smoke test script not found: ${SMOKE_TEST_SCRIPT_PATH}`);
  }

  reporter.onPackagePhaseChange(packageName, 'scheduling');
  const task = await client.createExecutionTaskAsync(
    universeId,
    placeId,
    version,
    scriptContent
  );

  const completedTask = await client.pollTaskCompletionAsync(
    task.path,
    (state) => {
      if (state === 'PROCESSING') {
        reporter.onPackagePhaseChange(packageName, 'executing');
      }
    }
  );

  const rawLogs = await client.getRawTaskLogsAsync(task.path);
  const parsed = parseTestLogs(rawLogs);

  const infraSuccess = completedTask.state === 'COMPLETE';
  return {
    success: infraSuccess && parsed.success,
    logs: parsed.logs,
  };
}
