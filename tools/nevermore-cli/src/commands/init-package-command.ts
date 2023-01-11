/**
 * Initialize a new game command
 */

import { Argv, CommandModule } from 'yargs';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { TemplateHelper } from '@quenty/nevermore-template-helpers';
import { NevermoreGlobalArgs } from '../args/global-args';

export interface InitPackageArgs extends NevermoreGlobalArgs {
  packageName: string;
  description: string;
}

/**
 * Creates a new package within Nevermore
 */
export class InitPackageCommand<T>
  implements CommandModule<T, InitPackageArgs>
{
  public command = 'init-package [package-name] [description]';
  public describe = 'Initializes a new package within Nevermore.';

  public builder(args: Argv<T>) {
    args.positional('package-name', {
      describe: 'Name of the new package folder.',
      demandOption: true,
      type: 'string',
    });
    args.positional('description', {
      describe: 'The description of the package.',
      demandOption: true,
      type: 'string',
    });
    return args as Argv<InitPackageArgs>;
  }

  public async handler(args: InitPackageArgs) {
    const rawPackageName = await InitPackageCommand._ensurePackageName(args);

    const packageName = TemplateHelper.camelize(rawPackageName).toLowerCase();
    const packageNameProper = TemplateHelper.camelize(rawPackageName);
    const description = await InitPackageCommand._ensureDescription(args);

    const srcRoot = process.cwd();
    const templatePath = path.join(
      __dirname,
      '..',
      '..',
      'templates',
      'nevermore-library-package-template'
    );

    OutputHelper.info(
      `Initializing a new package at '${srcRoot}' with template '${templatePath}'`
    );

    await TemplateHelper.createDirectoryContentsAsync(
      templatePath,
      srcRoot,
      {
        packageName: packageName,
        packageNameProper: packageNameProper,
        description: description,
      },
      args.dryrun
    );
  }

  private static async _ensurePackageName(
    args: InitPackageArgs
  ): Promise<string> {
    let { packageName } = args;

    if (!packageName) {
      packageName = path.basename(process.cwd());
    }

    InitPackageCommand.validatePackageName(packageName);

    return packageName;
  }

  private static validatePackageName(name: string): void {
    if (!name) {
      throw new Error('The project name is required.');
    }

    if (name.length === 0) {
      throw new Error('The project name cannot be empty string.');
    }
  }

  private static async _ensureDescription(
    args: InitPackageArgs
  ): Promise<string> {
    let { description } = args;

    InitPackageCommand.validateDescription(description);

    return description;
  }

  private static validateDescription(description: string): void {
    if (!description) {
      throw new Error('The description is required.');
    }

    if (description.length === 0) {
      throw new Error('The description cannot be empty string.');
    }
  }
}
