/**
 * Initialize a new game command
 */

import { Argv, CommandModule } from 'yargs';
import * as fs from 'fs';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  resolveTemplatePath,
  TemplateHelper,
} from '@quenty/nevermore-template-helpers';
import { NevermoreGlobalArgs } from '../../args/global-args.js';

export interface InitPackageArgs extends NevermoreGlobalArgs {
  packageName: string;
  description: string;
  packageTemplate: 'library' | 'service';
}

/**
 * Creates a new package within Nevermore
 */
export class InitPackageCommand<T>
  implements CommandModule<T, InitPackageArgs>
{
  public command = 'package [package-name] [description] [package-template]';
  public describe = 'Scaffold a new package within Nevermore';

  public builder = (args: Argv<T>) => {
    let result = args
      .positional('package-name', {
        describe: 'Name of the new package folder.',
        demandOption: false,
        type: 'string',
      })
      .positional('description', {
        describe: 'The description of the package.',
        demandOption: false,
        type: 'string',
      })
      .positional('package-template', {
        describe: 'The template type to use.',
        default: 'library',
        choices: ['library', 'service'],
      });

    return result as any;
  };

  public handler = async (args: InitPackageArgs) => {
    let rawPackageName = await InitPackageCommand._ensurePackageName(args);

    const packageName = TemplateHelper.camelize(rawPackageName).toLowerCase();
    const packageNameProper = TemplateHelper.camelize(rawPackageName);
    const description = await InitPackageCommand._ensureDescription(args);

    const srcRoot = process.cwd();
    const templatePath = resolveTemplatePath(
      import.meta.url,
      `nevermore-${args.packageTemplate}-package-template`
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
  };

  private static _readExistingPackageJson(): Record<string, any> | null {
    const packageJsonPath = path.join(process.cwd(), 'package.json');
    try {
      const content = fs.readFileSync(packageJsonPath, 'utf-8');
      return JSON.parse(content);
    } catch {
      return null;
    }
  }

  private static _extractNameFromPackageJson(
    pkg: Record<string, any>
  ): string | null {
    const name = pkg.name;
    if (typeof name !== 'string' || name.length === 0) {
      return null;
    }
    // Strip scope prefix (e.g. "@quenty/brio" -> "brio")
    const slashIndex = name.indexOf('/');
    return slashIndex >= 0 ? name.substring(slashIndex + 1) : name;
  }

  private static async _ensurePackageName(
    args: InitPackageArgs
  ): Promise<string> {
    let { packageName } = args;

    if (!packageName) {
      const pkg = InitPackageCommand._readExistingPackageJson();
      if (pkg) {
        packageName = InitPackageCommand._extractNameFromPackageJson(pkg) ?? '';
      }
    }

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

    if (!description) {
      const pkg = InitPackageCommand._readExistingPackageJson();
      if (
        pkg &&
        typeof pkg.description === 'string' &&
        pkg.description.length > 0
      ) {
        description = pkg.description;
      }
    }

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
