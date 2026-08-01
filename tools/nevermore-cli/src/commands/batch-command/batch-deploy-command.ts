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
import {
  buildDeployMetadataAttributes,
  gatherGitDeployInfo,
  injectDeployMetadataAsync,
} from '../../utils/deploy/deploy-metadata.js';
import { OpenCloudClient } from '../../utils/open-cloud/open-cloud-client.js';
import { RateLimiter } from '../../utils/open-cloud/rate-limiter.js';
import { CloudJobContext } from '../../utils/job-context/cloud-job-context.js';
import {
  createBasePlaceResolver,
  createLockOnlyBasePlaceResolver,
} from '../../utils/build/base-place-resolver-factory.js';
import {
  type BatchTarget,
  discoverAllTargetPackagesAsync,
  discoverChangedTargetPackagesAsync,
  flattenToBatchTargets,
} from '../../utils/batch/changed-packages-utils.js';
import {
  isCI,
  readPackageVersionAsync,
} from '../../utils/nevermore-cli-utils.js';
import { parseTestLogs } from '../../utils/testing/test-log-parser.js';
import { parseWatchOption } from '@quenty/nevermore-deploy';
import { registerWatchesAsync } from '../../utils/watch/register-watches.js';

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
  smokeTest?: boolean;
  watch?: string;
  watchShareApiKey?: boolean;
  watchUseGhAuth?: boolean;
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
      })
      .option('smoke-test', {
        describe:
          'Run a post-deploy smoke test on targets with basePlace ' +
          '(executes server scripts via Open Cloud and waits for errors)',
        type: 'boolean',
        default: false,
      })
      .option('watch', {
        describe:
          'After deploying, register a cloud watch for every place with a "watch" field, ' +
          'so it rebuilds when its base place changes. Takes the register endpoint ' +
          'URL, ending in the lease: https://<watch-service>/v1/register/7d',
        type: 'string',
      })
      .option('watch-use-gh-auth', {
        describe:
          'Let the GitHub CLI supply the watch token when no environment variable does. ' +
          'Off by default: registering sends the token to the watch service, so it should be one you handed over.',
        type: 'boolean',
        default: false,
      })
      .option('watch-share-api-key', {
        describe:
          'Share the Open Cloud API key with the watch service, so it can read private base places, ' +
          'see "saved" versions, and report versions in the same vocabulary as the lock file. ' +
          'Off by default — the key is stored by the service.',
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
  // Parsed up front so a typo'd duration fails before anything is deployed.
  const watchOption =
    args.watch == null ? undefined : parseWatchOption(args.watch);

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
    // Registration is idempotent and derives from committed config plus the
    // lock file, so it runs for real even on a dryrun — that is what makes the
    // watch path testable without shipping a build.
    if (watchOption) {
      OutputHelper.info(
        '[DRYRUN] Registering watches and firing them, to prove routing works. ' +
          'Neither touches the deploy.'
      );
      const allPackages = await discoverAllTargetPackagesAsync(targetName);
      await registerWatchesAsync({
        option: watchOption,
        monitorName: targetName,
        resolver: createLockOnlyBasePlaceResolver(),
        useGhAuth: args.watchUseGhAuth,
        triggerAfterRegister: true,
        candidates: flattenToBatchTargets(allPackages).map((buildTarget) => ({
          targetName,
          packageName: buildTarget.packageName,
          packagePath: buildTarget.path,
          place: buildTarget.target,
        })),
      });
    }
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
  const basePlaceResolver = createBasePlaceResolver(client, args);
  const context = new CloudJobContext(reporter, client, basePlaceResolver);

  // Gathered once so every deployed package shares one timestamp and commit.
  const deployGitInfo = gatherGitDeployInfo();
  const deployTimestamp = new Date().toISOString();

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
          packageName: buildTarget.name,
        });

        const injected = await injectDeployMetadataAsync(
          builtPlace,
          buildDeployMetadataAttributes(
            deployGitInfo,
            {
              target: targetName,
              published: publish,
              timestamp: deployTimestamp,
              universeId: buildTarget.target.universeId,
              placeId: buildTarget.target.placeId,
              packageVersion: await readPackageVersionAsync(buildTarget.path),
            },
            buildTarget.manifestPlaces
          )
        );

        let version: number;
        try {
          ({ version } = await uploadPlaceAsync({
            builtPlace: injected.builtPlace,
            args: { apiKey, publish },
            client,
            reporter: pkgReporter,
            packageName: buildTarget.name,
          }));
        } finally {
          await injected.cleanupAsync();
        }

        // Eagerly release build artifacts after upload
        await context.releaseBuiltPlaceAsync(builtPlace);

        let logs: string;
        if (args.smokeTest && buildTarget.target.basePlace) {
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

    if (watchOption) {
      // Deliberately every package with this target, not just the ones that
      // deployed. One monitor holds the repo's watches for a target and a
      // re-apply replaces its whole list, so registering only what changed
      // would delete the watches of every package that happened not to change
      // this run. Packages that did not deploy still have a lock entry, which
      // is the correct baseline for them.
      const allPackages = await discoverAllTargetPackagesAsync(targetName);
      await registerWatchesAsync({
        option: watchOption,
        monitorName: targetName,
        resolver: basePlaceResolver,
        useGhAuth: args.watchUseGhAuth,
        robloxApiKey: args.watchShareApiKey ? apiKey : undefined,
        candidates: flattenToBatchTargets(allPackages).map((buildTarget) => ({
          targetName,
          packageName: buildTarget.packageName,
          packagePath: buildTarget.path,
          place: buildTarget.target,
        })),
      });
    }
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
