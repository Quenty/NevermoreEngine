/**
 * Initialize a new game command
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

export interface InitGameArgs extends NevermoreGlobalArgs {
  gameName: string;
}

/**
 * Creates a new game with Nevermore dependencies
 */
export class InitGameCommand<T> implements CommandModule<T, InitGameArgs> {
  public command = 'init [game-name]';
  public describe =
    'Initializes a new game template.';

  public builder(args: Argv<T>) {
    args.positional('game-name', {
      describe: 'Name of the new package folder.',
      demandOption: false,
      type: 'string',
    });
    return args as Argv<InitGameArgs>;
  }

  public async handler(args: InitGameArgs) {
    const rawGameName = await InitGameCommand._ensureGameName(args);

    const gameName = TemplateHelper.camelize(rawGameName).toLowerCase();
    const gameNameProper = TemplateHelper.camelize(rawGameName);

    const srcRoot = process.cwd();
    const templatePath = getTemplatePathByName('game-template');

    OutputHelper.info(
      `Creating a new game at '${srcRoot}' with template '${templatePath}'`
    );

    await TemplateHelper.createDirectoryContentsAsync(
      templatePath,
      srcRoot,
      {
        gameName: gameName,
        gameNameProper: gameNameProper,
      },
      args.dryrun
    );

    const packages = [
      '@quenty/loader',
      '@quenty/servicebag',
      '@quenty/binder',
      '@quenty/clienttranslator',
      '@quenty/cmdrservice',
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

  private static async _ensureGameName(args: InitGameArgs): Promise<string> {
    let { gameName } = args;

    if (!gameName) {
      gameName = path.basename(process.cwd());
    }

    InitGameCommand._validateGameName(gameName);

    return gameName;
  }

  private static _validateGameName(name: string): void {
    if (!name) {
      throw new Error('The project name is required.');
    }

    if (name.length === 0) {
      throw new Error('The project name cannot be empty string.');
    }
  }
}
