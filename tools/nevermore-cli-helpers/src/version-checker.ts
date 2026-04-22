/**
 * Checks for updates to a given npm package and notifies the user if an update is available.
 */

import * as os from 'os';
import * as path from 'path';
import * as semver from 'semver';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { readFile, writeFile } from 'fs/promises';
import { Memoize } from 'typescript-memoize';

const CHECK_INTERVAL_MS = 60 * 60 * 1000; // 1 hour

interface VersionCache {
  lastCheck: number;
  latestVersion: string;
  currentVersion: string;
  isLocalDev: boolean;
}

interface UpdateCheckResult {
  updateAvailable: boolean;
  currentVersion: string;
  latestVersion: string;
  isLocalDev: boolean;
}

interface VersionCheckerOptions {
  packageName: string;
  humanReadableName?: string;
  registryUrl: string;
  packageJsonPath?: string;
  updateCommand?: string;
  verbose?: boolean;
}

interface OurVersionData {
  isLocalDev: boolean;
  version: string;
}

export class VersionChecker {
  public static async checkForUpdatesAsync(
    options: VersionCheckerOptions
  ): Promise<UpdateCheckResult | undefined> {
    try {
      return await VersionChecker._checkForUpdatesInternalAsync(options);
    } catch (error) {
      const name = VersionChecker._getDisplayName(options);
      OutputHelper.box(
        `Failed to check for updates for ${name} due to ${error}`
      );
    }

    return undefined;
  }

  private static async _checkForUpdatesInternalAsync(
    options: VersionCheckerOptions
  ): Promise<UpdateCheckResult | undefined> {
    const {
      packageName,
      registryUrl,
      packageJsonPath,
      updateCommand = `npm install -g ${packageName}@latest`,
    } = options;

    const versionData = await VersionChecker._queryOurVersionAsync(
      packageJsonPath
    );
    if (!versionData) {
      if (options.verbose) {
        const name = VersionChecker._getDisplayName(options);
        OutputHelper.error(
          `Could not determine current version for ${name}, skipping update check.`
        );
      }
      return undefined;
    }

    const result = await VersionChecker._queryUpdateStateAsync(
      packageName,
      versionData,
      registryUrl
    );

    if (options.verbose) {
      const currentyVersionDisplayName =
        VersionChecker._getLocalVersionDisplayName(versionData);

      OutputHelper.info(
        `Checked for updates for ${packageName}. Current version: ${currentyVersionDisplayName}, Latest version: ${result.latestVersion}, and update available: ${result.updateAvailable}`
      );
    }

    if (result.isLocalDev) {
      const name = VersionChecker._getDisplayName(options);
      const text = [
        `${name} is running in local development mode`,
        '',
        OutputHelper.formatHint(
          `Run '${updateCommand}' to switch to production copy`
        ),
        '',
        'This will result in less errors.',
      ].join('\n');

      OutputHelper.box(text, { centered: true });
    } else if (result.updateAvailable) {
      const name = VersionChecker._getDisplayName(options);
      const currentyVersionDisplayName =
        VersionChecker._getLocalVersionDisplayName(versionData);
      const text = [
        `${name} update available: ${currentyVersionDisplayName} → ${result.latestVersion}`,
        '',
        OutputHelper.formatHint(`Run '${updateCommand}' to update`),
      ].join('\n');

      OutputHelper.box(text, { centered: true });
    }

    return result;
  }

  private static _getDisplayName(options: VersionCheckerOptions): string {
    return options.humanReadableName || options.packageName;
  }

  /**
   * Helper method to get version display name from UpdateCheckResult
   */
  public static getVersionDisplayName(versionData: UpdateCheckResult): string {
    return VersionChecker._getLocalVersionDisplayName({
      isLocalDev: versionData.isLocalDev,
      version: versionData.currentVersion,
    });
  }

  private static _getLocalVersionDisplayName(
    versionData: OurVersionData
  ): string {
    return versionData.isLocalDev
      ? `${versionData.version}-local-copy`
      : versionData.version;
  }

  @Memoize()
  private static async _queryOurVersionAsync(
    packageJsonPath: string | undefined
  ): Promise<OurVersionData | null> {
    if (!packageJsonPath) {
      throw new Error(
        'Either currentVersion or packageJsonPath must be provided to determine the current version.'
      );
    }

    const pkg = JSON.parse(await readFile(packageJsonPath, 'utf8'));

    // Check dependencies and see if they're workspace* or link:* or file:* instead of a version
    function isLinkedDependencies(
      deps: Record<string, string> | undefined
    ): boolean {
      if (!deps) {
        return false;
      }

      return Object.values(deps).some(
        (dep) =>
          dep.startsWith('workspace:') ||
          dep.startsWith('link:') ||
          dep.startsWith('file:')
      );
    }

    const isLocalDev =
      isLinkedDependencies(pkg.dependencies) ||
      isLinkedDependencies(pkg.devDependencies) ||
      isLinkedDependencies(pkg.peerDependencies);

    return {
      isLocalDev: isLocalDev,
      version: pkg.version || null,
    };
  }

  private static async _queryUpdateStateAsync(
    packageName: string,
    versionData: OurVersionData,
    registryUrl: string
  ): Promise<UpdateCheckResult> {
    // Use a simple cache file in the user's home directory
    const cacheKey = `${packageName
      .replace('/', '-')
      .replace('@', '')}-version`;
    const cacheFile = path.join(os.homedir(), '.nevermore-version-cache');

    // Try to read cached data
    let cachedData: VersionCache | undefined;
    let loadedCacheData;
    try {
      const cacheContent = await readFile(cacheFile, 'utf-8');
      loadedCacheData = JSON.parse(cacheContent);
      cachedData = loadedCacheData[cacheKey] as VersionCache | undefined;
    } catch (error) {
      // Cache file doesn't exist or is invalid, will check for updates
    }

    // If we checked recently, skip
    const now = Date.now();
    if (
      cachedData &&
      (now - cachedData.lastCheck < CHECK_INTERVAL_MS ||
        cachedData.currentVersion !== versionData.version ||
        cachedData.isLocalDev !== versionData.isLocalDev)
    ) {
      return {
        updateAvailable: semver.gt(
          cachedData.latestVersion,
          versionData.version
        ),
        currentVersion: versionData.version,
        latestVersion: cachedData.latestVersion,
        isLocalDev: versionData.isLocalDev,
      };
    }

    const { default: latestVersion } = await import('latest-version');

    // Check for new version
    const latestVersionString = await latestVersion(packageName, {
      registryUrl: registryUrl,
    });

    // Save to cache
    const newCache: VersionCache = {
      lastCheck: now,
      latestVersion: latestVersionString,
      currentVersion: versionData.version,
      isLocalDev: versionData.isLocalDev,
    };
    const newResults = loadedCacheData || {};
    newResults[cacheKey] = newCache;

    try {
      await writeFile(cacheFile, JSON.stringify(newResults, null, 2), 'utf-8');
    } catch (error) {
      // Ignore cache write errors, update check still worked
      OutputHelper.warn(`Failed to write cache file: ${error}`);
    }

    // Return whether update is available
    return {
      updateAvailable: semver.gt(latestVersionString, versionData.version),
      currentVersion: versionData.version,
      latestVersion: latestVersionString,
      isLocalDev: versionData.isLocalDev,
    };
  }
}
