/**
 * Initialize a new game command
 */

import { Argv, CommandModule } from 'yargs';
import * as path from 'path';
import * as fs from 'fs';
import * as Handlebars from 'handlebars';
import { OutputHelper } from '../helper';
import { NevermoreGlobalArgs } from '../args/global-args';
import execa = require('execa');
import * as util from 'util';

const existsAsync = util.promisify(fs.exists);

export interface InitGameArgs extends NevermoreGlobalArgs {
  gameName: string;
}

/**
 * Makes the string upper camel case
 */
function camelize(str: string) {
  return str
    .replace(/(?:^\w|[A-Z]|\b\w)/g, function (word: string, index: number) {
      return word.toUpperCase();
    })
    .replace(/\s+/g, '');
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
    args.option('dryrun', {
      describe: 'Whether this run should be a dryrun.',
      demandOption: false,
      type: 'boolean',
      default: false,
    });
    return args as Argv<InitGameArgs>;
  }

  public async handler(args: InitGameArgs) {
    const rawGameName = await InitGameCommand._ensureGameName(args);

    const gameName = camelize(rawGameName).toLowerCase();
    const gameNameProper = camelize(rawGameName);

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

    await InitGameCommand._createDirectoryContentsAsync(
      templatePath,
      srcRoot,
      {
        gameName: gameName,
        gameNameProper: gameNameProper,
      },
      args
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

  private static async _createDirectoryContentsAsync(
    templatePath: string,
    targetPath: string,
    input: any,
    args: InitGameArgs
  ) {
    // read all files/folders (1 level) from template folder
    const filesToCreate = await fs.promises.readdir(templatePath);
    for (const originalName of filesToCreate) {
      const origFilePath = path.join(templatePath, originalName);

      if (originalName == 'ENSURE_FOLDER_CREATED') {
        continue;
      }

      const compiledName = (Handlebars as any).default.compile(originalName);
      const newName = compiledName(input);
      const stats = await fs.promises.stat(origFilePath);

      if (stats.isFile()) {
        // read file content and transform it using template engine
        const contents = await fs.promises.readFile(origFilePath, 'utf8');
        const compiled = (Handlebars as any).default.compile(contents);
        const result = compiled(input);
        const newFilePath = path.join(targetPath, newName);

        if (args.dryrun) {
          OutputHelper.info(`[DRYRUN]: Write file ${newFilePath}`);
          console.log(`${result}`);
        } else {
          if (!(await existsAsync(newFilePath))) {
            await fs.promises.writeFile(newFilePath, result, 'utf8');
            OutputHelper.info(`Created '${newFilePath}'`);
          } else {
            OutputHelper.error(
              `File already exists ${newFilePath} will not overwrite`
            );
          }
        }
      } else if (stats.isDirectory()) {
        const newDirPath = path.join(targetPath, originalName);
        if (args.dryrun) {
          OutputHelper.info(`[DRYRUN]: Write folder ${newDirPath}`);
        } else {
          // create folder in destination folder
          if (!(await existsAsync(newDirPath))) {
            await fs.promises.mkdir(newDirPath);
          }
        }

        // copy files/folder inside current folder recursively
        await InitGameCommand._createDirectoryContentsAsync(
          path.join(templatePath, originalName),
          path.join(targetPath, newName),
          input,
          args
        );
      }
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
    if (name.length === 0) {
      throw new Error('The project name cannot be empty string.');
    }
  }
}
