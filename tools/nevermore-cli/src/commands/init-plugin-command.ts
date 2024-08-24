/**
 * Initialize a new plugin command
 */

import { Argv, CommandModule } from 'yargs';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { TemplateHelper } from '@quenty/nevermore-template-helpers';
import { NevermoreGlobalArgs } from '../args/global-args';
import {
  getTemplatePathByName,
  runCommandAsync,
} from '../utils/nevermore-cli-utils';

export interface initGameArgs extends NevermoreGlobalArgs {
  pluginName: string;
}

/**
 * Creates a new plugin with Nevermore dependencies
 */
export class InitPluginCommand<T> implements CommandModule<T, initGameArgs> {
  public command = 'init-plugin [plugin-name]';
  public describe =
    'Initializes a new plugin template.';

  public builder(args: Argv<T>) {
    args.positional('plugin-name', {
      describe: 'Name of the new package folder.',
      demandOption: false,
      type: 'string',
    });
    return args as Argv<initGameArgs>;
  }

  public async handler(args: initGameArgs) {
    const rawPluginName = await InitPluginCommand._ensurePluginName(args);

    const pluginName = TemplateHelper.camelize(rawPluginName).toLowerCase();
    const pluginNameProper = TemplateHelper.camelize(rawPluginName);

    const srcRoot = process.cwd();
    const templatePath = getTemplatePathByName('plugin-template');

    OutputHelper.info(
      `Creating a new plugin at '${srcRoot}' with template '${templatePath}'`
    );

    await TemplateHelper.createDirectoryContentsAsync(
      templatePath,
      srcRoot,
      {
        pluginName: pluginName,
        pluginNameProper: pluginNameProper,
      },
      args.dryrun
    );

    const packages = [
      '@quenty/loader',
      '@quenty/servicebag',
    ];

    await runCommandAsync(args, 'npm', ['install', ...packages], {
      cwd: srcRoot,
    });

    try {
      await runCommandAsync(args, 'selene', ['generate-roblox-std'], {
        cwd: srcRoot,
      });
    } catch {
      OutputHelper.info(
        'Failed to run `selene generate-roblox-std`, is selene installed?'
      );
    }
  }

  private static async _ensurePluginName(args: initGameArgs): Promise<string> {
    let { pluginName } = args;

    if (!pluginName) {
      pluginName = path.basename(process.cwd());
    }

    InitPluginCommand._validatePluginName(pluginName);

    return pluginName;
  }

  private static _validatePluginName(name: string): void {
    if (!name) {
      throw new Error('The project name is required.');
    }

    if (name.length === 0) {
      throw new Error('The project name cannot be empty string.');
    }
  }
}