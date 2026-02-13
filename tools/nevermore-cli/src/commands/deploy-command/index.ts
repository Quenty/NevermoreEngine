import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { buildAndUploadAsync } from '../../utils/build/build-and-upload.js';
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
  public command = 'deploy <subcommand>';
  public describe = 'Build and upload a place via Roblox Open Cloud';

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
    const targetName = args.target ?? 'test';

    const result = await buildAndUploadAsync(args, targetName, args.publish ? 'publish.rbxl' : 'deploy.rbxl');
    if (!result) {
      OutputHelper.info(`[DRYRUN] Would build and upload`);
      return;
    }

    if (args.publish) {
      OutputHelper.info(`Published v${result.version} — live in game.`);
    } else {
      OutputHelper.info(`Saved v${result.version} — not yet live.`);
      OutputHelper.hint('Use --publish to make it live in game.');
    }
  }
}
