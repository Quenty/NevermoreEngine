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
  type BatchDeployResult,
  createDeployCommentConfig,
} from '../../utils/deploy/deploy-github-columns.js';
import { OpenCloudClient } from '../../utils/open-cloud/open-cloud-client.js';
import { RateLimiter } from '../../utils/open-cloud/rate-limiter.js';
import { CloudJobContext } from '../../utils/job-context/cloud-job-context.js';
import { runBatchAsync } from '../../utils/batch/batch-runner.js';
import { type BatchTarget } from '../../utils/batch/changed-packages-utils.js';
import { isCI, readPackageNameAsync } from '../../utils/nevermore-cli-utils.js';
import {
  loadDeployConfigAsync,
  resolveDeployConfigPath,
  resolveDeployTargetPlaces,
} from '../../utils/build/deploy-config.js';
import { handleInitAsync } from './deploy-init.js';
import { selectTargetAsync } from './select-target.js';

const MULTI_PLACE_CONCURRENCY = 3;

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
    if (args.dryrun) {
      OutputHelper.info(`[DRYRUN] Would build and upload`);
      return;
    }

    const cwd = process.cwd();
    const packageName = (await readPackageNameAsync(cwd)) ?? path.basename(cwd);

    const { targetName, autoDetected: targetAutoDetected } =
      await selectTargetAsync(cwd, {
        explicitTarget: args.target,
        publish: args.publish ?? false,
      });

    const config = await loadDeployConfigAsync(resolveDeployConfigPath(cwd));
    const places = resolveDeployTargetPlaces(config, targetName);
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
          };
        })
      : [
          {
            name: packageName,
            packageName,
            path: cwd,
            target: places[0]!,
          },
        ];

    const publish = args.publish ?? false;
    const showLogs = args.logs ?? false;
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

    const reporter = new CompositeReporter(
      targetNames,
      (state: LiveStateTracker) => {
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
    // Captured only for the single-place success message printed after the run.
    let publishedVersion: number | undefined;
    let publishedPlaceId: number | undefined;

    try {
      const results = await runBatchAsync<BatchTarget, BatchDeployResult>({
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

          const { version, target: uploadedTarget } = await uploadPlaceAsync({
            builtPlace,
            args,
            client,
            reporter: pkgReporter,
            packageName: buildTarget.name,
          });

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
      if (results.summary.failed > 0) exitCode = 1;
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      exitCode = 1;
    } finally {
      await context.disposeAsync();
    }

    await reporter.stopAsync();

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

    if (exitCode !== 0) process.exit(exitCode);
  }
}
