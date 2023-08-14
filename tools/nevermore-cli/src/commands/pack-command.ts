/**
 * Initialize a new game command
 */

import { Argv, CommandModule } from 'yargs';
import * as path from 'path';
import { TemplateHelper } from '@quenty/nevermore-template-helpers';
import { NevermoreGlobalArgs } from '../args/global-args';
import {
  getTemplatePathByName,
  runCommandAsync,
} from '../utils/nevermore-cli-utils';

export interface PackArgs extends NevermoreGlobalArgs {
  packageDirectory: string;
}

/**
 * Creates a new game with Nevermore dependencies
 */
export class PackCommand<T> implements CommandModule<T, PackArgs> {
  public command = 'pack';
  public describe =
    'Packs the package into a reusable rbxm file for upload to Roblox';

  public builder(args: Argv<T>) {
    args.positional('packageDirectory', {
      describe:
        'The directory for the package to pack. Defaults to the current directory if not specified.',
      demandOption: false,
      type: 'string',
    });
    return args as Argv<PackArgs>;
  }

  public async handler(args: PackArgs) {
    const packageDirectory = args.packageDirectory || process.cwd();
    const templatePath = getTemplatePathByName('pack-template');
    const packageName = path.basename(packageDirectory);

    const outputDirectory = path.join(packageDirectory, 'pack');

    await TemplateHelper.ensureFolderAsync(outputDirectory, args.dryrun);
    await TemplateHelper.createDirectoryContentsAsync(
      templatePath,
      outputDirectory,
      {
        packageName: packageName,
        exactPackageName: 'exactPackageName',
        commit: 'commit',
      },
      args.dryrun
    );

    await runCommandAsync(
      args,
      'rojo',
      ['build', outputDirectory, '--output', `pack.rbxm`],
      {
        cwd: packageDirectory,
      }
    );
  }
}
