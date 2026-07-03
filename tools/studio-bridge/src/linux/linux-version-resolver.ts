/**
 * Resolve the latest Roblox Studio version hash from the CDN.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';

const CLIENT_SETTINGS_URL =
  'https://clientsettingscdn.roblox.com/v2/client-version/WindowsStudio64';

interface ClientVersionResponse {
  version: string;
  clientVersionUpload: string;
  bootstrapperVersion: string;
}

/**
 * Fetch the current Studio version string from the Roblox client settings API.
 * Returns a version hash like "version-e095049f34844c41".
 */
export async function resolveStudioVersionAsync(
  explicitVersion?: string
): Promise<string> {
  if (explicitVersion) {
    return explicitVersion;
  }

  OutputHelper.verbose(
    'Fetching latest Studio version from client settings...'
  );

  const response = await fetch(CLIENT_SETTINGS_URL);
  if (!response.ok) {
    throw new Error(
      `Failed to fetch Studio version: ${response.status} ${response.statusText}`
    );
  }

  const data = (await response.json()) as ClientVersionResponse;
  const version = data.clientVersionUpload;
  if (!version.startsWith('version-')) {
    throw new Error(`Unexpected version format: ${version}`);
  }

  OutputHelper.verbose(`Latest Studio version: ${version} (${data.version})`);
  return version;
}

/**
 * Read the installed version from a .studio-version marker file.
 * Returns undefined if no version is installed.
 */
export async function readInstalledVersionAsync(
  studioDir: string
): Promise<string | undefined> {
  const versionFile = path.join(studioDir, '.studio-version');
  try {
    return (await fs.readFile(versionFile, 'utf-8')).trim();
  } catch {
    return undefined;
  }
}

/**
 * Write the installed version to a .studio-version marker file.
 */
export async function writeInstalledVersionAsync(
  studioDir: string,
  version: string
): Promise<void> {
  const versionFile = path.join(studioDir, '.studio-version');
  await fs.writeFile(versionFile, version + '\n', 'utf-8');
}
