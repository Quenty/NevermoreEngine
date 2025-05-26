/**
 * Install Nevermore packages from npm
 */

import { Argv, CommandModule } from "yargs";
import { OutputHelper } from "@quenty/cli-output-helpers";
import { NevermoreGlobalArgs } from "../args/global-args";
import {
  runCommandAsync,
} from "../utils/nevermore-cli-utils";

export interface InstallPackageArgs extends NevermoreGlobalArgs {
  packages: string[];
}

/**
 * Install a Nevermore package from npm
 */
export class InstallPackageCommand<T> implements CommandModule<T, InstallPackageArgs> {
  public command = "install [packages..]";
  public aliases = ["i"];
  public describe = "Install Nevermore packages from npm";

  private static _validatePackageName(name: string): void {
    if (!name) {
      throw new Error("Package name is required!");
    }
  }

  private static async _getPackages(): Promise<string[]> {
    try {
      const response = await fetch(
        "https://registry.npmjs.org/-/v1/search?text=@quenty/&size=1000"
      );
      const data = await response.json();
      return data.objects
        .map((obj: any) => obj.package.name)
        .filter((name: string) => name.startsWith("@quenty/"))
        .map((name: string) => name.replace("@quenty/", ""))
        .sort();
    } catch {
      return [];
    }
  }

  public builder(args: Argv<T>) {
    args.positional("packages", {
      type: "string",
      array: true,
      describe: "Name of the package(s) to install",
      completion: async (current: string) => {
        const packages = await InstallPackageCommand._getPackages();
        return packages.filter(name => !current || name.startsWith(current));
      }
    });
    return args as Argv<InstallPackageArgs>;
  }

  public async handler(args: InstallPackageArgs) {
    const srcRoot = process.cwd();

    if (!args.packages?.length) {
      throw new Error("No packages specified!");
    }

    args.packages.forEach(packageName => InstallPackageCommand._validatePackageName(packageName));

    const availablePackages = await InstallPackageCommand._getPackages();
    const invalidPackages = args.packages.filter(
      packageName => !availablePackages.includes(packageName)
    );

    if (invalidPackages.length > 0) {
      throw new Error(`Invalid packages: ${invalidPackages.join(", ")}`);
    }

    const prefixedPackages = args.packages.map(packageName => `@quenty/${packageName}`);

    OutputHelper.info(`Installing packages: ${args.packages.join(", ")}`);

    await runCommandAsync(args, "npm", ["install", ...prefixedPackages], {
      cwd: srcRoot,
    });
  }
}