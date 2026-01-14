/**
 * Checks for updates to a given npm package and notifies the user if an update is available.
 */

import * as os from 'os';
import * as path from 'path';
import * as semver from 'semver';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { readFile, writeFile } from 'fs/promises';

const CHECK_INTERVAL_MS = 24 * 60 * 60 * 1000; // 24 hours

interface VersionCache {
  lastCheck: number;
  latestVersion: string;
  currentVersion: string;
}

interface UpdateCheckResult {
  updateAvailable: boolean;
  currentVersion: string;
  latestVersion: string;
}

interface VersionCheckerOptions {
  packageName: string;
  humanReadableName?: string;
  registryUrl: string;
  currentVersion?: string;
  packageJsonPath?: string;
  updateCommand?: string;
  verbose?: boolean;
}

export async function checkForUpdatesAsync(
  options: VersionCheckerOptions
): Promise<void> {
  try {
    await checkForUpdatesInternalAsync(options);
  } catch (error) {
    const name = options.humanReadableName || options.packageName;
    OutputHelper.box(`Failed to check for updates for ${name} due to ${error}`);
  }
}

async function checkForUpdatesInternalAsync(
  options: VersionCheckerOptions
): Promise<void> {
  const {
    packageName,
    registryUrl,
    currentVersion,
    packageJsonPath,
    updateCommand = `npm install -g ${packageName}@latest`,
  } = options;

  const version = await queryOurVersionAsync(currentVersion, packageJsonPath);
  if (!version) {
    if (options.verbose) {
      OutputHelper.error(
        `Could not determine current version for ${packageName}, skipping update check.`
      );
    }
    return;
  }

  const result = await queryUpdateStateAsync(packageName, version, registryUrl);

  if (options.verbose) {
    OutputHelper.info(
      `Checked for updates for ${packageName}. Current version: ${result.currentVersion}, Latest version: ${result.latestVersion}, and update available: ${result.updateAvailable}`
    );
  }

  if (result.updateAvailable) {
    const name = options.humanReadableName || packageName;
    const text = [
      `${name} update available: ${result.currentVersion} → ${result.latestVersion}`,
      '',
      OutputHelper.formatHint(`Run '${updateCommand}' to update`),
    ].join('\n');

    OutputHelper.box(text, { centered: true });
  }
}

async function queryOurVersionAsync(
  currentVersion: string | undefined,
  packageJsonPath: string | undefined
): Promise<string | null> {
  if (currentVersion) {
    return currentVersion;
  }

  if (!packageJsonPath) {
    throw new Error(
      'Either currentVersion or packageJsonPath must be provided to determine the current version.'
    );
  }

  const pkg = JSON.parse(await readFile(packageJsonPath, 'utf8'));
  return pkg.version || null;
}

async function queryUpdateStateAsync(
  packageName: string,
  currentVersion: string,
  registryUrl: string
): Promise<UpdateCheckResult> {
  // Use a simple cache file in the user's home directory
  const cacheKey = `${packageName.replace('/', '-').replace('@', '')}-version`;
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
      cachedData.currentVersion !== currentVersion)
  ) {
    return {
      updateAvailable: semver.gt(cachedData.latestVersion, currentVersion),
      currentVersion: currentVersion,
      latestVersion: cachedData.latestVersion,
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
    currentVersion: currentVersion,
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
    updateAvailable: semver.gt(latestVersionString, currentVersion),
    currentVersion: currentVersion,
    latestVersion: latestVersionString,
  };
}
