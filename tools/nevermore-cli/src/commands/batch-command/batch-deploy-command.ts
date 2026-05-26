import * as fs from 'fs/promises';
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
import { resolvePackagePath } from '@quenty/nevermore-template-helpers';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { getApiKeyAsync } from '@quenty/nevermore-cli-helpers';
import { runBatchAsync } from '../../utils/batch/batch-runner.js';
import { uploadPlaceAsync } from '../../utils/build/upload.js';
import {
  type BatchDeployResult,
  createDeployCommentConfig,
} from '../../utils/deploy/deploy-github-columns.js';
import { OpenCloudClient } from '../../utils/open-cloud/open-cloud-client.js';
import { RateLimiter } from '../../utils/open-cloud/rate-limiter.js';
import { CloudJobContext } from '../../utils/job-context/cloud-job-context.js';
import {
  type BatchTarget,
  discoverAllTargetPackagesAsync,
  discoverChangedTargetPackagesAsync,
  flattenToBatchTargets,
} from '../../utils/batch/changed-packages-utils.js';
import { isCI } from '../../utils/nevermore-cli-utils.js';
import { parseTestLogs } from '../../utils/testing/test-log-parser.js';

const SMOKE_TEST_SCRIPT_PATH = resolvePackagePath(
  import.meta.url,
  'build-scripts',
  'smoke-test-server.luau'
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

  const discovered = args.all
    ? await discoverAllTargetPackagesAsync(targetName)
    : await discoverChangedTargetPackagesAsync(args.base!, targetName);
  let batchTargets = flattenToBatchTargets(discovered);

  if (args.limit && args.limit > 0) {
    batchTargets = batchTargets.slice(0, args.limit);
  }

  if (batchTargets.length === 0) {
    if (args.all) {
      OutputHelper.warn(
        `No packages have a "${targetName}" target. Packages need a deploy.nevermore.json with a "${targetName}" target.\n` +
          'Run "nevermore deploy init" inside a package to set one up.'
      );
    } else {
      OutputHelper.warn(
        `No packages changed since ${args.base} have a "${targetName}" target.\n` +
          'Use --all to deploy every package with this target, or --base <ref> to change the comparison ref.'
      );
    }
    return;
  }

  if (args.dryrun) {
    const names = batchTargets.map((p) => p.name).join(', ');
    OutputHelper.info(
      `[DRYRUN] Would deploy ${batchTargets.length} targets: ${names}`
    );
    return;
  }

  const concurrency = args.concurrency ?? 3;
  const isGrouped = !process.stdout.isTTY || args.verbose || isCI();
  const targetNames = batchTargets.map((p) => p.name);
  const publish = args.publish ?? false;
  const deployLabels = {
    successLabel: publish ? 'Published' : 'Deployed',
    failureLabel: publish ? 'PUBLISH FAILED' : 'DEPLOY FAILED',
  };
  const actionVerb = publish ? 'Publishing' : 'Deploying';

  const reporter = new CompositeReporter(
    targetNames,
    (state: LiveStateTracker) => {
      const reporters: Reporter[] = [
        isGrouped
          ? new GroupedReporter(state, {
              showLogs: args.logs ?? false,
              verbose: args.verbose,
              actionVerb,
              ...deployLabels,
            })
          : new SpinnerReporter(state, {
              showLogs: args.logs ?? false,
              actionVerb,
              ...deployLabels,
            }),
        new SummaryTableReporter(state, {
          ...deployLabels,
          summaryVerb: publish ? 'published' : 'deployed',
        }),
      ];
      if (args.output) {
        reporters.push(new JsonFileReporter(state, args.output));
      }
      if (isCI()) {
        reporters.push(
          new GithubCommentTableReporter(
            state,
            createDeployCommentConfig(),
            concurrency
          )
        );
      }
      return reporters;
    }
  );

  const apiKey = await getApiKeyAsync(args);
  const client = new OpenCloudClient({
    apiKey,
    rateLimiter: new RateLimiter(),
  });
  const context = new CloudJobContext(reporter, client);

  await reporter.startAsync();

  let exitCode = 0;
  try {
    const results = await runBatchAsync<BatchTarget, BatchDeployResult>({
      items: batchTargets,
      concurrency,
      reporter,
      bufferOutput: isGrouped,
      executeAsync: async (buildTarget, pkgReporter) => {
        const builtPlace = await context.buildPlaceAsync({
          target: buildTarget.target,
          outputFileName: publish ? 'publish.rbxl' : 'deploy.rbxl',
          packagePath: buildTarget.path,
          packageName: buildTarget.name,
        });

        const { version } = await uploadPlaceAsync({
          builtPlace,
          args: { apiKey, publish },
          client,
          reporter: pkgReporter,
          packageName: buildTarget.name,
        });

        // Eagerly release build artifacts after upload
        await context.releaseBuiltPlaceAsync(builtPlace);

        // Run smoke test for targets with basePlace
        let logs: string;
        if (buildTarget.target.basePlace) {
          OutputHelper.verbose('Running post-deploy smoke test...');
          const smokeResult = await _runSmokeTestAsync(
            pkgReporter,
            buildTarget.name,
            buildTarget.target.universeId,
            buildTarget.target.placeId,
            version,
            client
          );
          logs = smokeResult.logs;
          if (!smokeResult.success) {
            return {
              packageName: buildTarget.name,
              placeId: buildTarget.target.placeId,
              success: false,
              logs: _annotateSmokeTestFailure(logs),
              failureLabel: 'SMOKE TEST FAILED',
            };
          }
        } else {
          const action = publish ? 'Published' : 'Saved';
          logs = `${action} v${version}`;
        }

        return {
          packageName: buildTarget.name,
          placeId: buildTarget.target.placeId,
          success: true,
          logs,
          progressSummary: {
            kind: 'version',
            version,
            url: `https://www.roblox.com/games/${buildTarget.target.placeId}`,
          },
        };
      },
    });
    if (results.summary.failed > 0) exitCode = 1;
  } catch (err) {
    OutputHelper.error(err instanceof Error ? err.message : String(err));
    exitCode = 1;
  } finally {
    await context.disposeAsync();
  }

  await reporter.stopAsync();
  process.exit(exitCode);
}

function _annotateSmokeTestFailure(logs: string): string {
  const header =
    'Post-deploy smoke test failed. The deploy itself succeeded, but a server ' +
    "script errored on boot. ('TaskScript' in any stack trace below refers to " +
    "Nevermore's smoke-test-server.luau, which loadstring()s each Script under " +
    'ServerScriptService — if you see "loadstring() is not available", set ' +
    '$properties.LoadStringEnabled = true on ServerScriptService in your ' +
    'rojo project.)';
  return `${header}\n\n${logs}`;
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
