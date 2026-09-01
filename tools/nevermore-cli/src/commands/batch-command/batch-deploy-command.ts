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
import {
  buildWatchMonitorName,
  parseWatchOption,
  type BasePlaceResolver,
  type WatchOption,
} from '@quenty/nevermore-deploy';
import {
  registerWatchesAsync,
  type WatchCandidate,
} from '../../utils/watch/register-watches.js';

const SMOKE_TEST_SCRIPT_PATH = resolvePackagePath(
  import.meta.url,
  'build-scripts',
  'smoke-test-server.lua'
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
    // Renew anyway. Registration derives from committed config plus the lock,
    // so it does not need this run to have deployed anything — and the lease is
    // the only thing keeping the watch alive. Returning here instead is how a
    // repo whose scheduled builds all diff clean quietly stops being watched,
    // with no failure anywhere to notice.
    if (watchOption) {
      OutputHelper.info(
        'Renewing watches anyway, so the lease does not lapse.'
      );
      await _registerWatchesAsync({
        targetName,
        option: watchOption,
        // Nothing deployed, so the lock is the whole truth about what each
        // place was built from.
        resolver: createLockOnlyBasePlaceResolver(),
        useGhAuth: args.watchUseGhAuth,
        shareApiKey: args.watchShareApiKey,
        resolveApiKeyAsync: () => getApiKeyAsync(args),
        dryrun: args.dryrun,
      });
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
      // Under its own monitor names, never the ones a real run owns.
      //
      // Re-registering replaces a monitor's entire watch list, and a dryrun
      // cannot reproduce a real registration: the Open Cloud key is resolved
      // after this point, so it would register anonymously — stripping the key
      // from the live monitor, moving every source back to the anonymous
      // driver and its content-hash vocabulary, dropping the baselines, and
      // deleting any "saved" watch outright, because an anonymous
      // registration skips those.
      await _registerWatchesAsync({
        targetName,
        option: watchOption,
        resolver: createLockOnlyBasePlaceResolver(),
        useGhAuth: args.watchUseGhAuth,
        shareApiKey: args.watchShareApiKey,
        dryrun: true,
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
            createDeployCommentConfig(deployLabels),
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
          packagePath: buildTarget.path,
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
              basePlaceId: buildTarget.target.basePlace?.placeId,
              basePlaceVersion: builtPlace.basePlaceVersion,
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

    // Only after a clean run, matching `deploy run`. A package that resolved its
    // base place and then failed to upload has a lock naming a version it never
    // shipped; registering that as the baseline tells the service the watch is
    // up to date, so the rebuild never fires and the next successful run
    // re-registers the same wrong baseline. The failure becomes permanent and
    // invisible.
    if (watchOption && results.summary.failed === 0) {
      await _registerWatchesAsync({
        targetName,
        option: watchOption,
        resolver: basePlaceResolver,
        useGhAuth: args.watchUseGhAuth,
        shareApiKey: args.watchShareApiKey,
        resolveApiKeyAsync: async () => apiKey,
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

/**
 * Register one monitor per package, covering every package with this target.
 *
 * Per package rather than one for the batch, because `deploy run --watch`
 * registers a package's places too. Two names for one package's watches means
 * two monitors on the same base place, so one artist publish dispatches twice
 * and each rebuild races the other's lock write. Both paths take the name from
 * `buildWatchMonitorName`, so registering from either replaces the same list.
 *
 * Every package with the target, never just the ones that deployed: a re-apply
 * replaces a monitor's whole list, and a package that didn't change still has a
 * lock entry, which is exactly the right baseline for it.
 */
async function _registerWatchesAsync(options: {
  targetName: string;
  option: WatchOption;
  resolver: BasePlaceResolver;
  useGhAuth?: boolean;
  /** Whether `--watch-share-api-key` was passed. A dryrun never shares one. */
  shareApiKey?: boolean;
  /** Called only if a key is actually going to be sent. */
  resolveApiKeyAsync?: () => Promise<string>;
  dryrun?: boolean;
}): Promise<void> {
  const { targetName } = options;

  if (options.dryrun) {
    OutputHelper.info(
      '[DRYRUN] Registering separate dryrun watches and firing them, to ' +
        'prove routing works. This does not build or upload here — but ' +
        'firing really does dispatch the workflow once per package, and ' +
        'each of those runs a real deploy on the runner.'
    );
    if (options.shareApiKey) {
      OutputHelper.warn(
        '[DRYRUN] Registering without the Open Cloud key, so a "saved" base ' +
          'place is skipped here even though a real run would watch it.'
      );
    }
  }

  const robloxApiKey =
    options.shareApiKey && !options.dryrun
      ? await options.resolveApiKeyAsync?.()
      : undefined;

  const allPackages = await discoverAllTargetPackagesAsync(targetName);

  // Places that never asked to be watched are dropped here rather than passed
  // in to be reported as skips. Most places in a batch are in that state, and
  // per-package registration would otherwise warn about each package that has
  // no watch at all. A place that asked and can't be watched still goes
  // through, because that is the case worth saying out loud.
  const byPackage = new Map<string, WatchCandidate[]>();
  for (const buildTarget of flattenToBatchTargets(allPackages)) {
    if (buildTarget.target.watch == null) {
      continue;
    }
    const candidates = byPackage.get(buildTarget.packageName) ?? [];
    candidates.push({
      targetName,
      packageName: buildTarget.packageName,
      packagePath: buildTarget.path,
      place: buildTarget.target,
    });
    byPackage.set(buildTarget.packageName, candidates);
  }

  if (byPackage.size === 0) {
    OutputHelper.warn(
      `--watch was requested, but no place in a "${targetName}" target has a ` +
        '"watch" field. Add one naming the workflow that rebuilds it.'
    );
    return;
  }

  for (const [packageName, candidates] of byPackage) {
    await registerWatchesAsync({
      option: options.option,
      monitorName: buildWatchMonitorName({
        packageName,
        targetName,
        dryrun: options.dryrun,
      }),
      resolver: options.resolver,
      useGhAuth: options.useGhAuth,
      robloxApiKey,
      // Firing proves the workflow really receives the selector, which is the
      // half that historically breaks. Only a dryrun asks for it.
      triggerAfterRegister: options.dryrun,
      candidates,
    });
  }
}

function _annotateSmokeTestFailure(logs: string): string {
  const header =
    'Post-deploy smoke test failed. The deploy itself succeeded, but a server ' +
    "script errored on boot. ('TaskScript' in any stack trace below refers to " +
    "Nevermore's smoke-test-server.lua, which loadstring()s each Script under " +
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
  const parsed = parseTestLogs(rawLogs.text);

  const infraSuccess = completedTask.state === 'COMPLETE';
  return {
    success: infraSuccess && parsed.success,
    logs: parsed.logs,
  };
}
