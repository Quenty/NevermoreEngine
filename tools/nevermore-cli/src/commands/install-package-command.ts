/**
 * Install Nevermore packages from npm
 */

import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { NevermoreGlobalArgs } from '../args/global-args.js';
import { runCommandAsync } from '../utils/nevermore-cli-utils.js';
import {
  buildAddPackagesCommand,
  detectPackageManagerAsync,
  isPackageManager,
  PACKAGE_MANAGERS,
  PackageManager,
} from '../utils/package-manager-utils.js';

export interface InstallPackageArgs extends NevermoreGlobalArgs {
  packages: string[];
  packageManager?: string;
}

/**
 * Install a Nevermore package from npm
 */
export class InstallPackageCommand<T>
  implements CommandModule<T, InstallPackageArgs>
{
  public command = 'install [packages..]';
  public aliases = ['i'];
  public describe = 'Install Nevermore packages from npm';

  private static _validatePackageName(name: string): void {
    if (!name) {
      throw new Error('Package name is required!');
    }
  }

  /**
   * Lists the published `@quenty/*` package names, without the scope.
   *
   * The registry caps search results at 250 per request, well under the number
   * of published packages, so this pages through until the reported total is
   * covered.
   */
  private static async _getPackages(): Promise<string[]> {
    const pageSize = 250;
    const names = new Set<string>();

    try {
      let from = 0;
      for (;;) {
        const response = await fetch(
          `https://registry.npmjs.org/-/v1/search?text=@quenty/&size=${pageSize}&from=${from}`
        );
        const data = await response.json();
        const objects: any[] = data.objects ?? [];

        for (const entry of objects) {
          const name: string = entry.package?.name ?? '';
          if (name.startsWith('@quenty/')) {
            names.add(name.slice('@quenty/'.length));
          }
        }

        from += objects.length;
        if (objects.length < pageSize || from >= (data.total ?? 0)) {
          break;
        }
      }
    } catch {
      return [];
    }

    return [...names].sort();
  }

  /**
   * Asks the registry about one package directly. Returns undefined when the
   * registry can't be reached, so an offline run doesn't look like a typo.
   */
  private static async _packageExistsAsync(
    scopedName: string
  ): Promise<boolean | undefined> {
    try {
      const response = await fetch(
        `https://registry.npmjs.org/${scopedName.replace('/', '%2f')}`,
        { method: 'HEAD' }
      );

      if (response.status === 404) {
        return false;
      }

      return response.ok ? true : undefined;
    } catch {
      return undefined;
    }
  }

  public builder(args: Argv<T>) {
    args.positional('packages', {
      type: 'string',
      array: true,
      describe: 'Name of the package(s) to install',
      completion: async (current: string) => {
        const packages = await InstallPackageCommand._getPackages();
        return packages.filter((name) => !current || name.startsWith(current));
      },
    });
    args.option('package-manager', {
      describe:
        'Package manager to install with. Detected from the project by default.',
      type: 'string',
      choices: PACKAGE_MANAGERS as unknown as string[],
    });
    return args as Argv<InstallPackageArgs>;
  }

  private static async _resolvePackageManagerAsync(
    args: InstallPackageArgs,
    srcRoot: string
  ): Promise<PackageManager> {
    const requested = args.packageManager;
    if (requested) {
      if (!isPackageManager(requested)) {
        throw new Error(
          `Unsupported package manager '${requested}'. Expected one of: ${PACKAGE_MANAGERS.join(
            ', '
          )}`
        );
      }
      return requested;
    }

    return detectPackageManagerAsync(srcRoot);
  }

  public async handler(args: InstallPackageArgs) {
    const srcRoot = process.cwd();

    if (!args.packages?.length) {
      throw new Error('No packages specified!');
    }

    args.packages.forEach((packageName) =>
      InstallPackageCommand._validatePackageName(packageName)
    );

    const prefixedPackages = args.packages.map(
      (packageName) => `@quenty/${packageName}`
    );

    const existence = await Promise.all(
      prefixedPackages.map((scopedName) =>
        InstallPackageCommand._packageExistsAsync(scopedName)
      )
    );
    const invalidPackages = args.packages.filter(
      (_, index) => existence[index] === false
    );

    if (invalidPackages.length > 0) {
      throw new Error(`Invalid packages: ${invalidPackages.join(', ')}`);
    }

    const packageManager =
      await InstallPackageCommand._resolvePackageManagerAsync(args, srcRoot);

    OutputHelper.info(
      `Installing packages with ${packageManager}: ${args.packages.join(', ')}`
    );

    const { command, args: commandArgs } = buildAddPackagesCommand(
      packageManager,
      prefixedPackages
    );

    await runCommandAsync(args, command, commandArgs, {
      cwd: srcRoot,
    });
  }
}
