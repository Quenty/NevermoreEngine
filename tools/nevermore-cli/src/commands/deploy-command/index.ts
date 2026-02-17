import * as path from 'path';
import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  type Reporter,
  type LiveStateTracker,
  CompositeReporter,
  SimpleReporter,
} from '@quenty/cli-output-helpers/reporting';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { getApiKeyAsync } from '../../utils/auth/credential-store.js';
import { buildPlaceAsync } from '../../utils/build/build.js';
import { uploadPlaceAsync } from '../../utils/build/upload.js';
import { OpenCloudClient } from '../../utils/open-cloud/open-cloud-client.js';
import { RateLimiter } from '../../utils/open-cloud/rate-limiter.js';
import { readPackageNameAsync } from '../../utils/nevermore-cli-utils.js';
import { handleInitAsync } from './deploy-init.js';

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
            describe: 'Deploy target name',
            type: 'string',
            default: 'test',
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
            describe: 'Deploy target name from deploy.nevermore.json',
            type: 'string',
            default: 'test',
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
            describe: 'Upload a pre-built .rbxl file instead of building via rojo',
            type: 'string',
          });
      },
      async (runArgs) => {
        try {
          await DeployCommand._handleRunAsync(
            runArgs as unknown as DeployArgs
          );
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
    const packageName =
      (await readPackageNameAsync(cwd)) ?? path.basename(cwd);
    const targetName = args.target ?? 'test';

    const reporter = new CompositeReporter(
      [packageName],
      (state: LiveStateTracker) => {
        const reporters: Reporter[] = [
          new SimpleReporter(state, {
            alwaysShowLogs: false,
            successMessage: 'Deploy complete!',
            failureMessage: 'Deploy failed!',
          }),
        ];
        return reporters;
      }
    );

    await reporter.startAsync();

    const startMs = Date.now();
    reporter.onPackageStart(packageName);

    try {
      const buildResult = await buildPlaceAsync({
        targetName,
        outputFileName: args.publish ? 'publish.rbxl' : 'deploy.rbxl',
        overrides: args,
        reporter,
        packageName,
      });

      const apiKey = await getApiKeyAsync(args);
      const client = new OpenCloudClient({ apiKey, rateLimiter: new RateLimiter() });

      const { version } = await uploadPlaceAsync({
        buildResult,
        args,
        client,
        reporter,
        packageName,
      });

      const durationMs = Date.now() - startMs;
      const action = args.publish ? 'Published' : 'Saved';
      reporter.onPackageResult({
        packageName,
        success: true,
        logs: `${action} v${version}`,
        durationMs,
      });

      if (args.publish) {
        OutputHelper.info(`Published v${version} — live in game.`);
      } else {
        OutputHelper.info(`Saved v${version} — not yet live.`);
        OutputHelper.hint('Use --publish to make it live in game.');
      }
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

      await reporter.stopAsync();
      throw err;
    }

    await reporter.stopAsync();
  }
}
