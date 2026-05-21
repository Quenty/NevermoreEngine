import * as path from 'path';
import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  type Reporter,
  type LiveStateTracker,
  CompositeReporter,
  GithubCommentTableReporter,
  JsonFileReporter,
  SimpleReporter,
  SpinnerReporter,
} from '@quenty/cli-output-helpers/reporting';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { getApiKeyAsync } from '@quenty/nevermore-cli-helpers';
import { uploadPlaceAsync } from '../../utils/build/upload.js';
import { createDeployCommentConfig } from '../../utils/deploy/deploy-github-columns.js';
import { OpenCloudClient } from '../../utils/open-cloud/open-cloud-client.js';
import { RateLimiter } from '../../utils/open-cloud/rate-limiter.js';
import { CloudJobContext } from '../../utils/job-context/cloud-job-context.js';
import { isCI, readPackageNameAsync } from '../../utils/nevermore-cli-utils.js';
import { handleInitAsync } from './deploy-init.js';
import { selectTargetAsync } from './select-target.js';

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
            describe: 'Override universe ID from deploy.nevermore.json',
            type: 'number',
          })
          .option('place-id', {
            describe: 'Override place ID from deploy.nevermore.json',
            type: 'number',
          })
          .option('place-file', {
            describe:
              'Upload a pre-built .rbxl file instead of building via rojo',
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

    const useSpinner = process.stdout.isTTY && !args.verbose;
    const showLogs = args.logs ?? false;
    const publish = args.publish ?? false;
    const deployLabels = {
      successLabel: publish ? 'Published' : 'Deployed',
      failureLabel: publish ? 'PUBLISH FAILED' : 'DEPLOY FAILED',
    };
    const actionVerb = publish ? 'Publishing' : 'Deploying';

    // Spinner embeds the target in its header; SimpleReporter has no header, so
    // surface auto-detection here like before.
    if (!useSpinner && targetAutoDetected) {
      OutputHelper.info(`Using target '${targetName}'.`);
    }

    const reporter = new CompositeReporter(
      [packageName],
      (state: LiveStateTracker) => {
        const reporters: Reporter[] = [
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
              1
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

    const startMs = Date.now();
    reporter.onPackageStart(packageName);

    let exitCode = 0;
    let publishedVersion: number | undefined;
    try {
      const builtPlace = await context.buildPlaceAsync({
        targetName,
        outputFileName: args.publish ? 'publish.rbxl' : 'deploy.rbxl',
        overrides: args,
        reporter,
        packageName,
      });

      const { version } = await uploadPlaceAsync({
        builtPlace,
        args,
        client,
        reporter,
        packageName,
      });
      publishedVersion = version;

      const durationMs = Date.now() - startMs;
      const action = args.publish ? 'Published' : 'Saved';
      reporter.onPackageResult({
        packageName,
        success: true,
        logs: `${action} v${version}`,
        durationMs,
        progressSummary: { kind: 'version', version },
      });
    } catch (err) {
      const durationMs = Date.now() - startMs;
      const errorMessage = err instanceof Error ? err.message : String(err);

      reporter.onPackageResult({
        packageName,
        success: false,
        logs: '',
        durationMs,
        error: errorMessage,
      });
      exitCode = 1;
    } finally {
      await context.disposeAsync();
    }

    await reporter.stopAsync();

    if (publishedVersion !== undefined) {
      if (args.publish) {
        OutputHelper.info(`Published v${publishedVersion} — live in game.`);
      } else {
        OutputHelper.info(`Saved v${publishedVersion} — not yet live.`);
        OutputHelper.hint('Use --publish to make it live in game.');
      }
    }

    if (exitCode !== 0) process.exit(exitCode);
  }
}
