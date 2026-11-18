/**
 * Initialize a new game command
 */

import { Argv, CommandModule } from 'yargs';
import * as path from 'path';
import { execa } from 'execa';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  resolveTemplatePath,
  TemplateHelper,
} from '@quenty/nevermore-template-helpers';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { runCommandAsync } from '../../utils/nevermore-cli-utils.js';
export interface InitGameArgs extends NevermoreGlobalArgs {
  gameName: string;
}

/**
 * Creates a new game with Nevermore dependencies
 */
export class InitGameCommand<T> implements CommandModule<T, InitGameArgs> {
  public command = ['game [game-name]', '$0 [game-name]'] as any;
  public describe = 'Scaffold a new game with Nevermore dependencies';

  public builder(args: Argv<T>) {
    args.positional('game-name', {
      describe: 'Name of the new package folder.',
      demandOption: false,
      type: 'string',
    });
    return args as Argv<InitGameArgs>;
  }

  /**
   * Call before scaffolding so a missing pnpm doesn't leave a half-written
   * project behind.
   *
   * This deliberately never runs `npm install -g pnpm` for the user. pnpm 11+
   * writes its native binary from an install script, and npm 12 blocks install
   * scripts by default, so a global reinstall replaced a working pnpm with a
   * shim pointing at a binary that was never written.
   */
  public static async ensurePnpmAvailableAsync(
    args: NevermoreGlobalArgs
  ): Promise<void> {
    if (args.dryrun || (await InitGameCommand._isPnpmAvailableAsync())) {
      return;
    }

    throw new Error(
      'pnpm is not installed or not working. Install it with ' +
        '`npm install -g --allow-scripts=pnpm pnpm` (or `corepack enable pnpm`), ' +
        'then run this command again.'
    );
  }

  public static async initToolChainAsync(
    args: NevermoreGlobalArgs,
    srcRoot: string,
    packages: string[]
  ): Promise<void> {
    await runCommandAsync(args, 'pnpm', ['add', ...packages], {
      cwd: srcRoot,
    });

    try {
      await runCommandAsync(args, 'git', ['init'], {
        cwd: srcRoot,
      });
    } catch {
      OutputHelper.error(
        'Failed to initialize git repository, is git installed?'
      );
    }

    try {
      await runCommandAsync(args, 'aftman', ['install'], {
        cwd: srcRoot,
      });
    } catch {
      OutputHelper.error('Failed to install aftman, is aftman installed?');
    }

    try {
      await runCommandAsync(args, 'pnpm', ['run', 'format'], {
        cwd: srcRoot,
      });
    } catch {
      OutputHelper.error(
        'Failed to run `pnpm run format`, is stylua installed?'
      );
    }

    try {
      await runCommandAsync(args, 'selene', ['generate-roblox-std'], {
        cwd: srcRoot,
      });
    } catch {
      OutputHelper.error(
        'Failed to run `selene generate-roblox-std`, is selene installed?'
      );
    }
  }

  public async handler(args: InitGameArgs) {
    const rawGameName = await InitGameCommand._ensureGameName(args);
    await InitGameCommand.ensurePnpmAvailableAsync(args);

    const gameName = TemplateHelper.toPackageName(rawGameName);
    const gameNameProper = TemplateHelper.camelize(rawGameName);

    const srcRoot = process.cwd();
    const templatePath = resolveTemplatePath(import.meta.url, 'game-template');

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

    await InitGameCommand.initToolChainAsync(args, srcRoot, packages);
  }

  private static async _isPnpmAvailableAsync(): Promise<boolean> {
    try {
      await execa('pnpm', ['--version'], { timeout: 30_000 });
      return true;
    } catch {
      return false;
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
