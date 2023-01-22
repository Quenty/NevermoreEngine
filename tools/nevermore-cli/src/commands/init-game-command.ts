/**
 * Initialize a new game command
 */

import { Argv, CommandModule } from 'yargs';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { TemplateHelper } from '@quenty/nevermore-template-helpers';
import { NevermoreGlobalArgs } from '../args/global-args';
import execa = require('execa');

export interface InitGameArgs extends NevermoreGlobalArgs {
  gameName: string;
}

/**
 * Creates a new game with Nevermore dependencies
 */
export class InitGameCommand<T> implements CommandModule<T, InitGameArgs> {
  public command = 'init [game-name]';
  public describe =
    'Initializes a new game to use Nevermore with Cmdr and a few other packages.';

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
    const templatePath = path.join(
      __dirname,
      '..',
      '..',
      'templates',
      'game-template'
    );

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

    await InitGameCommand._runCommandAsync(
      args,
      'npm',
      ['install', ...packages],
      {
        cwd: srcRoot,
      }
    );

    try {
      await InitGameCommand._runCommandAsync(
        args,
        'selene',
        ['generate-roblox-std'],
        {
          cwd: srcRoot,
        }
      );
    } catch {
      OutputHelper.info(
        'Failed to run `selene generate-roblox-std`, is selene installed?'
      );
    }
  }

  private static async _runCommandAsync(
    initGameArgs: InitGameArgs,
    command: string,
    args: string[],
    options?: execa.CommonOptions<string>
  ): Promise<any> {
    if (initGameArgs.dryrun) {
      OutputHelper.info(
        `[DRYRUN]: Would have ran \`${command} ${args.join(' ')}\``
      );
    } else {
      OutputHelper.info(`Running \`${command} ${args.join(' ')}\``);

      const commandExec = execa(command, args, options);

      if (commandExec.stdout) {
        commandExec.stdout.pipe(process.stdout);
      }

      if (commandExec.stderr) {
        commandExec.stderr.pipe(process.stderr);
      }

      const result = await commandExec;

      OutputHelper.info(`Finished running '${result.command}'`);

      return result;
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
