import * as path from 'path';
import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  type Reporter,
  type LiveStateTracker,
  CompositeReporter,
  GithubCommentTableReporter,
  GroupedReporter,
  JsonFileReporter,
  SimpleReporter,
  SpinnerReporter,
  SummaryTableReporter,
} from '@quenty/cli-output-helpers/reporting';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { getApiKeyAsync } from '@quenty/nevermore-cli-helpers';
import { uploadPlaceAsync } from '../../utils/build/upload.js';
import {
  createBasePlaceResolver,
  createLockOnlyBasePlaceResolver,
} from '../../utils/build/base-place-resolver-factory.js';
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
import { runBatchAsync } from '../../utils/batch/batch-runner.js';
import { type BatchTarget } from '../../utils/batch/changed-packages-utils.js';
import {
  isCI,
  readPackageNameAsync,
  readPackageVersionAsync,
} from '../../utils/nevermore-cli-utils.js';
import {
  formatTargetSelector,
  isBasePlaceVersionKeyword,
  loadDeployConfigAsync,
  parseTargetSelector,
  parseWatchOption,
  resolveDeployConfigPath,
  resolveDeployTargetPlaces,
  toManifestPlaceInfo,
  type BasePlaceResolver,
  type DeployConfig,
} from '@quenty/nevermore-deploy';
import {
  registerWatchesAsync,
  type RegisterWatchesResult,
} from '../../utils/watch/register-watches.js';
import {
  runLocalWatchLoopAsync,
  type LocalWatchEntry,
} from '../../utils/watch/local-watch-loop.js';
import {
  describeNotifyWatchFallback,
  tryRegisterNotifyWatchesAsync,
} from '../../utils/watch/register-notify-watches.js';
import { runStreamWatchLoopAsync } from '../../utils/watch/stream-watch-loop.js';
import { WebSocketWatchStream } from '../../utils/watch/websocket-watch-stream.js';
import { handleInitAsync } from './deploy-init.js';
import {
  handleVersionUpgradeAsync,
  handleVersionPromoteAsync,
  type VersionPromoteArgs,
} from './version-command.js';
import { selectTargetAsync } from './select-target.js';

const MULTI_PLACE_CONCURRENCY = 10;

/**
 * Which base places a local watch polls.
 *
 * Deliberately looser than the cloud plan. `watch` is a GitHub workflow path —
 * a dispatch address — and nothing is dispatched locally, so requiring it would
 * only stop a developer hot-reloading a place that never intends to use CI.
 * `"saved"` is fair game too: the service cannot poll it yet, but this machine
 * has Open Cloud credentials and can.
 *
 * An exact version pin is still excluded, for the same reason as always: it
 * means "hold this still", so there is nothing to follow.
 */
async function _buildLocalWatchEntriesAsync(
  config: DeployConfig,
  targetName: string,
  packagePath: string,
  resolver: BasePlaceResolver
): Promise<LocalWatchEntry[]> {
  const entries: LocalWatchEntry[] = [];
  for (const place of resolveDeployTargetPlaces(config, targetName)) {
    const basePlace = place.basePlace;
    if (basePlace == null) {
      continue;
    }
    if (
      basePlace.version != null &&
      !isBasePlaceVersionKeyword(basePlace.version)
    ) {
      continue;
    }
    const versionType = basePlace.version ?? 'published';
    entries.push({
      label: formatTargetSelector({ targetName, placeName: place.name }),
      universeId: basePlace.universeId,
      placeId: basePlace.placeId,
      versionType,
      baseline: await resolver.peekAsync(packagePath, basePlace),
    });
  }
  return entries;
}

export interface DeployArgs extends NevermoreGlobalArgs {
  apiKey?: string;
  publish?: boolean;
  force?: boolean;
  universeId?: number;
  placeId?: number;
  target?: string;
  project?: string;
  scriptTemplate?: string;
  createPlace?: boolean;
  placeFile?: string;
  output?: string;
  logs?: boolean;
  watch?: string;
  watchShareApiKey?: boolean;
  watchUseGhAuth?: boolean;
}

export class DeployCommand<T> implements CommandModule<T, DeployArgs> {
  public command = 'deploy [target]';
  public describe = 'Build and upload via Roblox Open Cloud';

  public builder = (args: Argv<T>) => {
    args.command(
      'init',
      'Create a deploy.nevermore.json for the current package',
      (yargs) => {
        return yargs
          .option('universe-id', {
            describe: 'Roblox universe ID',
            type: 'number',
          })
          .option('place-id', {
            describe: 'Roblox place ID',
            type: 'number',
          })
          .option('target', {
            describe:
              'Deploy target name (auto-detects "test" or "integration" if omitted)',
            type: 'string',
          })
          .option('project', {
            describe: 'Rojo project file (relative to package)',
            type: 'string',
          })
          .option('script-template', {
            describe:
              'Luau script template to execute via Open Cloud (relative to package)',
            type: 'string',
          })
          .option('force', {
            describe: 'Overwrite existing deploy.nevermore.json',
            type: 'boolean',
            default: false,
          })
          .option('create-place', {
            describe:
              'Auto-create a new place in the universe (uses cookie auth)',
            type: 'boolean',
            default: false,
          });
      },
      async (initArgs) => {
        try {
          await handleInitAsync(initArgs as unknown as DeployArgs);
        } catch (err) {
          OutputHelper.error(err instanceof Error ? err.message : String(err));
          process.exit(1);
        }
      }
    );

    args.command(
      'version',
      'Manage pinned base place versions in deploy.nevermore.json',
      (yargs) => {
        return yargs
          .command(
            'upgrade [target]',
            'Re-pin every numeric basePlace to its latest published version',
            (upgradeYargs) => {
              return upgradeYargs
                .positional('target', {
                  describe:
                    'Only upgrade this target (default: all targets in the config)',
                  type: 'string',
                })
                .option('api-key', {
                  describe: 'Roblox Open Cloud API key',
                  type: 'string',
                });
            },
            async (upgradeArgs) => {
              try {
                await handleVersionUpgradeAsync(
                  upgradeArgs as unknown as DeployArgs
                );
              } catch (err) {
                OutputHelper.error(
                  err instanceof Error ? err.message : String(err)
                );
                process.exit(1);
              }
            }
          )
          .command(
            'promote <from> <to>',
            'Promote base place version pins from one target to another',
            (promoteYargs) => {
              return promoteYargs
                .positional('from', {
                  describe:
                    'Target to promote pins from (e.g. production-demo)',
                  type: 'string',
                })
                .positional('to', {
                  describe: 'Target to promote pins to (e.g. production)',
                  type: 'string',
                });
            },
            async (promoteArgs) => {
              try {
                await handleVersionPromoteAsync(
                  promoteArgs as unknown as VersionPromoteArgs
                );
              } catch (err) {
                OutputHelper.error(
                  err instanceof Error ? err.message : String(err)
                );
                process.exit(1);
              }
            }
          )
          .demandCommand(1, 'Specify a version action, e.g. "upgrade".');
      },
      () => {}
    );

    args.command(
      ['run [target]', '$0 [target]'],
      'Deploy a target from deploy.nevermore.json',
      (yargs) => {
        return yargs
          .positional('target', {
            describe:
              'Deploy target name from deploy.nevermore.json (defaults to the only target if there is just one, otherwise "test")',
            type: 'string',
          })
          .option('api-key', {
            describe: 'Roblox Open Cloud API key',
            type: 'string',
          })
          .option('publish', {
            describe: 'Publish the place (default: Saved)',
            type: 'boolean',
            default: false,
          })
          .option('universe-id', {
            describe:
              'Override universe ID from deploy.nevermore.json (single-place targets only)',
            type: 'number',
          })
          .option('place-id', {
            describe:
              'Override place ID from deploy.nevermore.json (single-place targets only)',
            type: 'number',
          })
          .option('place-file', {
            describe:
              'Upload a pre-built .rbxl file instead of building via rojo (single-place targets only)',
            type: 'string',
          })
          .option('output', {
            describe: 'Write JSON results to this file',
            type: 'string',
          })
          .option('logs', {
            describe: 'Show build/upload logs (not just on failure)',
            type: 'boolean',
            default: false,
          })
          .option('watch', {
            describe:
              'After deploying, register a cloud watch so this target rebuilds when its base place changes. ' +
              'Takes the register endpoint URL, ending in the lease: https://<watch-service>/v1/register/7d',
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
              'Share the Open Cloud API key with the watch service, so it can read a private base place, ' +
              'see "saved" versions, and report versions in the same vocabulary as the lock file. ' +
              'Off by default — the key is stored by the service.',
            type: 'boolean',
            default: false,
          });
      },
      async (runArgs) => {
        try {
          await DeployCommand._handleRunAsync(runArgs as unknown as DeployArgs);
        } catch (err) {
          OutputHelper.error(err instanceof Error ? err.message : String(err));
          process.exit(1);
        }
      }
    );

    return args as Argv<DeployArgs>;
  };

  public handler = async () => {};

  private static async _handleRunAsync(args: DeployArgs): Promise<void> {
    // Parsed before anything is built so a typo'd duration fails immediately
    // rather than after a full deploy has already shipped.
    const watchOption =
      args.watch == null ? undefined : parseWatchOption(args.watch);

    const cwd = process.cwd();
    const packageName = (await readPackageNameAsync(cwd)) ?? path.basename(cwd);
    const packageVersion = await readPackageVersionAsync(cwd);

    const { targetName, autoDetected: targetAutoDetected } =
      await selectTargetAsync(cwd, {
        explicitTarget: args.target,
        publish: args.publish ?? false,
      });

    const config = await loadDeployConfigAsync(resolveDeployConfigPath(cwd));
    const places = resolveDeployTargetPlaces(config, targetName);
    const manifestPlaces = places.map(toManifestPlaceInfo);
    const isMultiPlace = places.length > 1;

    if (isMultiPlace) {
      const overrides: string[] = [];
      if (args.universeId != null) overrides.push('--universe-id');
      if (args.placeId != null) overrides.push('--place-id');
      if (args.placeFile != null) overrides.push('--place-file');
      if (overrides.length > 0) {
        throw new Error(
          `Target "${targetName}" has ${places.length} places; ` +
            `${overrides.join(', ')} only applies to single-place targets.`
        );
      }
    }

    const batchTargets: BatchTarget[] = isMultiPlace
      ? places.map((place, i) => {
          const suffix = place.name ?? `places[${i}]`;
          return {
            name: `${packageName} - ${suffix}`,
            packageName,
            path: cwd,
            target: place,
            manifestPlaces,
          };
        })
      : [
          {
            name: packageName,
            packageName,
            path: cwd,
            target: places[0]!,
            manifestPlaces,
          },
        ];

    // Registering a watch is idempotent and derives entirely from committed
    // config and the lock file, so it is safe to do for real on a dryrun — and
    // doing it for real is the only way to exercise the watch path without
    // shipping a build.
    if (args.dryrun) {
      OutputHelper.info('[DRYRUN] Would build and upload');
      if (watchOption) {
        OutputHelper.info(
          '[DRYRUN] Registering a separate dryrun watch and firing it, to ' +
            'prove routing works. This does not build or upload here — but ' +
            'firing really does dispatch the workflow, which runs a real ' +
            'deploy on the runner. That is the half being proved.'
        );
        if (args.watchShareApiKey) {
          OutputHelper.warn(
            '[DRYRUN] Registering without the Open Cloud key, so a "saved" ' +
              'base place is skipped here even though a real run would watch it.'
          );
        }
        const watchedTarget = parseTargetSelector(targetName).targetName;
        // Under its own monitor name, never the one a real run owns.
        //
        // Re-registering replaces a monitor's entire watch list, and a dryrun
        // cannot reproduce a real registration: the Open Cloud key is resolved
        // after this point, so it would register anonymously — stripping the key
        // from the live monitor, moving every source back to the anonymous
        // driver and its content-hash vocabulary, dropping the baselines, and
        // deleting any "saved" watch outright, because an anonymous
        // registration skips those.
        await registerWatchesAsync({
          option: watchOption,
          monitorName: `${packageName}/${watchedTarget}/dryrun`,
          resolver: createLockOnlyBasePlaceResolver(),
          useGhAuth: args.watchUseGhAuth,
          triggerAfterRegister: true,
          candidates: resolveDeployTargetPlaces(config, watchedTarget).map(
            (place) => ({
              targetName: watchedTarget,
              packageName,
              packagePath: cwd,
              place,
            })
          ),
        });
      }
      return;
    }

    const publish = args.publish ?? false;
    const showLogs = args.logs ?? false;

    // Gathered once so every place in a multi-place deploy shares one timestamp
    // and commit.
    const deployGitInfo = gatherGitDeployInfo();
    const deployTimestamp = new Date().toISOString();
    const useSpinner = process.stdout.isTTY && !args.verbose;
    const isGrouped = !process.stdout.isTTY || args.verbose || isCI();
    const deployLabels = {
      successLabel: publish ? 'Published' : 'Deployed',
      failureLabel: publish ? 'PUBLISH FAILED' : 'DEPLOY FAILED',
    };
    const actionVerb = publish ? 'Publishing' : 'Deploying';
    const targetNames = batchTargets.map((t) => t.name);

    // Spinner embeds the target in its header; SimpleReporter has no header, so
    // surface auto-detection here like before. (Multi-place uses GroupedReporter
    // / SummaryTableReporter, which both name the target separately.)
    if (!useSpinner && !isMultiPlace && targetAutoDetected) {
      OutputHelper.info(`Using target '${targetName}'.`);
    }

    const apiKey = await getApiKeyAsync(args);
    const client = new OpenCloudClient({
      apiKey,
      rateLimiter: new RateLimiter(),
    });

    // Captured only for the success message printed after the run.
    let publishedVersion: number | undefined;
    let publishedPlaceId: number | undefined;

    // One deploy, start to finish. Factored out because a local watch runs it
    // again on every base place change, and each pass needs its own reporter,
    // resolver and job context — sharing them across passes would replay a
    // finished progress display and reuse an already-flushed lock.
    const runDeployPassAsync = async (
      refresh: boolean
    ): Promise<{ failed: number; resolver: BasePlaceResolver }> => {
      const reporter = _buildReporter();
      // A rebuild triggered by the base place moving must re-resolve the pin,
      // or it rebuilds the version it already shipped.
      const basePlaceResolver = createBasePlaceResolver(client, {
        frozenLockfile: refresh ? false : args.frozenLockfile,
        refreshBasePlace: refresh || args.refreshBasePlace,
      });
      const context = new CloudJobContext(reporter, client, basePlaceResolver);

      await reporter.startAsync();
      let failed = 0;
      try {
        const results = await _runBatchAsync(context, reporter);
        failed = results.summary.failed;
      } finally {
        await context.disposeAsync();
      }
      await reporter.stopAsync();
      return { failed, resolver: basePlaceResolver };
    };

    function _buildReporter(): CompositeReporter {
      return new CompositeReporter(targetNames, (state: LiveStateTracker) => {
        const reporters: Reporter[] = [];
        if (isMultiPlace) {
          reporters.push(
            isGrouped
              ? new GroupedReporter(state, {
                  showLogs,
                  verbose: args.verbose,
                  actionVerb,
                  ...deployLabels,
                })
              : new SpinnerReporter(state, {
                  showLogs,
                  actionVerb,
                  actionContext: `to target '${targetName}'`,
                  ...deployLabels,
                })
          );
          reporters.push(
            new SummaryTableReporter(state, {
              ...deployLabels,
              summaryVerb: publish ? 'published' : 'deployed',
            })
          );
        } else {
          reporters.push(
            useSpinner
              ? new SpinnerReporter(state, {
                  showLogs,
                  actionVerb,
                  actionContext: `to target '${targetName}'`,
                  ...deployLabels,
                })
              : new SimpleReporter(state, {
                  alwaysShowLogs: showLogs,
                  successMessage: 'Deploy complete!',
                  failureMessage: 'Deploy failed!',
                })
          );
        }
        if (args.output) {
          reporters.push(new JsonFileReporter(state, args.output));
        }
        if (isCI()) {
          reporters.push(
            new GithubCommentTableReporter(
              state,
              createDeployCommentConfig(),
              isMultiPlace ? MULTI_PLACE_CONCURRENCY : 1
            )
          );
        }
        return reporters;
      });
    }

    function _runBatchAsync(context: CloudJobContext, reporter: Reporter) {
      return runBatchAsync<BatchTarget, BatchDeployResult>({
        items: batchTargets,
        concurrency: isMultiPlace ? MULTI_PLACE_CONCURRENCY : 1,
        reporter,
        bufferOutput: isMultiPlace && isGrouped,
        executeAsync: async (buildTarget, pkgReporter) => {
          const builtPlace = await context.buildPlaceAsync({
            target: buildTarget.target,
            outputFileName: publish ? 'publish.rbxl' : 'deploy.rbxl',
            packagePath: buildTarget.path,
            packageName: buildTarget.name,
            overrides: isMultiPlace ? undefined : args,
          });

          const injected = await injectDeployMetadataAsync(
            builtPlace,
            buildDeployMetadataAttributes(
              deployGitInfo,
              {
                target: targetName,
                published: publish,
                timestamp: deployTimestamp,
                universeId: args.universeId ?? buildTarget.target.universeId,
                placeId: args.placeId ?? buildTarget.target.placeId,
                packageVersion,
              },
              buildTarget.manifestPlaces
            )
          );

          let uploadResult: Awaited<ReturnType<typeof uploadPlaceAsync>>;
          try {
            uploadResult = await uploadPlaceAsync({
              builtPlace: injected.builtPlace,
              args,
              client,
              reporter: pkgReporter,
              packageName: buildTarget.name,
            });
          } finally {
            await injected.cleanupAsync();
          }
          const { version, target: uploadedTarget } = uploadResult;

          await context.releaseBuiltPlaceAsync(builtPlace);

          if (!isMultiPlace) {
            publishedVersion = version;
            publishedPlaceId = uploadedTarget.placeId;
          }

          const action = publish ? 'Published' : 'Saved';
          return {
            packageName: buildTarget.name,
            placeId: uploadedTarget.placeId,
            success: true,
            logs: `${action} v${version}`,
            progressSummary: {
              kind: 'version',
              version,
              url: `https://www.roblox.com/games/${uploadedTarget.placeId}`,
            },
          };
        },
      });
    }

    let exitCode = 0;
    let watchResult: RegisterWatchesResult | undefined;
    const watchedTarget = parseTargetSelector(targetName).targetName;

    try {
      const first = await runDeployPassAsync(args.refreshBasePlace ?? false);
      if (first.failed > 0) exitCode = 1;

      // Only after a clean deploy: what happens next records the base place
      // version that just shipped, which is not a fact yet if the deploy failed.
      if (watchOption && first.failed === 0) {
        if (isCI()) {
          // The monitor is named for the whole target, so it has to carry every
          // place in that target — not just the ones this invocation deployed.
          // Re-registering replaces its watch list, so a narrowed selector
          // (`integration.places.hub`) would otherwise delete the sibling
          // places' watches. Places that did not deploy keep their lock baseline.
          watchResult = await registerWatchesAsync({
            option: watchOption,
            // Scoped to this package and target, so deploying one package can
            // never replace the watch list another package registered.
            monitorName: `${packageName}/${watchedTarget}`,
            resolver: first.resolver,
            useGhAuth: args.watchUseGhAuth,
            robloxApiKey: args.watchShareApiKey ? apiKey : undefined,
            candidates: resolveDeployTargetPlaces(config, watchedTarget).map(
              (place) => ({
                targetName: watchedTarget,
                packageName,
                packagePath: cwd,
                place,
              })
            ),
          });
        } else {
          // Locally the rebuild belongs here, not on a runner, so the watch
          // asks to be told rather than to dispatch. Being told beats polling —
          // no Open Cloud quota per developer, and the rebuild starts when the
          // change lands — but polling still works everywhere, so it is what
          // this falls back to.
          const localEntries = await _buildLocalWatchEntriesAsync(
            config,
            watchedTarget,
            cwd,
            first.resolver
          );
          const redeployAsync = async () => {
            const pass = await runDeployPassAsync(true);
            if (pass.failed > 0) {
              throw new Error('deploy failed');
            }
          };

          const notify = await tryRegisterNotifyWatchesAsync({
            option: watchOption,
            monitorName: `${packageName}/${watchedTarget}`,
            entries: localEntries,
            useGhAuth: args.watchUseGhAuth,
            robloxApiKey: args.watchShareApiKey ? apiKey : undefined,
          });

          // Streaming is preferred but never required: whatever the reason it
          // is unavailable, polling from here still works.
          let pollInstead = true;
          if (notify.success) {
            // Anything the stream throws is still just "streaming did not
            // work", and the promise above says polling covers that however it
            // happens. Letting it escape to the handler's catch would exit the
            // run instead — reporting a failure for a watch that could simply
            // have carried on here.
            let loop;
            try {
              loop = await runStreamWatchLoopAsync({
                entries: notify.entries,
                stream: new WebSocketWatchStream({
                  registerUrl: watchOption.registerUrl,
                }),
                // The stream says a place moved; Open Cloud says what it moved
                // to. The two speak different version vocabularies, and only
                // this one matches what the lock records.
                source: client,
                monitorId: notify.monitorId,
                credential: notify.credential,
                redeployAsync,
              });
            } catch (err) {
              OutputHelper.warn(
                'Could not hold the watch stream: ' +
                  (err instanceof Error ? err.message : String(err))
              );
              loop = undefined;
            }
            if (loop && loop.failures > 0) exitCode = 1;
            // The service could not read any of these places — a private base
            // place, say. This machine has credentials it does not, so the
            // watch carries on here rather than waiting on a socket that will
            // never say anything.
            //
            // A lapsed lease or a refused handshake ends the stream just as
            // finally, and the user asked to keep watching either way — exiting
            // there would report success while silently doing nothing.
            pollInstead =
              loop == null ||
              loop.unobservable ||
              loop.monitorGone ||
              loop.rejected;
            if (pollInstead) {
              OutputHelper.info(
                'Watching from here instead, using your own Open Cloud key.'
              );
            }
          } else if (notify.reason !== 'no_entries') {
            OutputHelper.verbose(
              `Polling instead of streaming: ${describeNotifyWatchFallback(
                notify
              )}.`
            );
          }

          if (pollInstead) {
            const loop = await runLocalWatchLoopAsync({
              entries: localEntries,
              source: client,
              durationMs: watchOption.durationMs,
              redeployAsync,
            });
            if (loop.failures > 0) exitCode = 1;
          }
        }
      }
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      exitCode = 1;
    }

    if (publishedVersion !== undefined) {
      const placeUrl =
        publishedPlaceId !== undefined
          ? `https://www.roblox.com/games/${publishedPlaceId}`
          : undefined;
      if (publish) {
        OutputHelper.info(
          placeUrl
            ? `Published v${publishedVersion} — live in game. ${placeUrl}`
            : `Published v${publishedVersion} — live in game.`
        );
      } else {
        OutputHelper.info(
          placeUrl
            ? `Saved v${publishedVersion} — not yet live. ${placeUrl}`
            : `Saved v${publishedVersion} — not yet live.`
        );
        OutputHelper.hint('Use --publish to make it live in game.');
      }
    }

    if (watchResult && watchResult.registered > 0) {
      OutputHelper.hint(
        'The watch rebuilds this target when its base place moves. Re-run ' +
          'with --watch to renew the lease before it expires.'
      );
    }

    if (exitCode !== 0) process.exit(exitCode);
  }
}
