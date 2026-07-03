/**
 * Download and install Roblox Studio from CDN zip packages.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import { execSync } from 'child_process';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  ROBLOX_CDN_BASE,
  STUDIO_PACKAGES,
  type LinuxStudioConfig,
} from './linux-config.js';
import { writeInstalledVersionAsync } from './linux-version-resolver.js';

const DOWNLOAD_DIR = '/tmp/roblox-pkgs';

/**
 * Download all Studio packages from CDN and extract them to studioDir.
 * Writes AppSettings.xml on completion.
 */
export async function installStudioAsync(
  config: LinuxStudioConfig,
  version: string
): Promise<void> {
  const { studioDir } = config;

  // Clean existing install
  await fs.rm(studioDir, { recursive: true, force: true });
  await fs.mkdir(studioDir, { recursive: true });

  // Ensure download cache exists
  await fs.mkdir(DOWNLOAD_DIR, { recursive: true });

  const packageNames = Object.keys(STUDIO_PACKAGES);
  OutputHelper.info(`Downloading ${packageNames.length} packages...`);

  // Download packages (sequential to avoid rate limiting)
  for (const pkg of packageNames) {
    await downloadPackageAsync(version, pkg);
  }

  OutputHelper.info('Extracting packages...');

  // Extract each package to its target directory
  for (const [pkg, subdir] of Object.entries(STUDIO_PACKAGES)) {
    const target = path.join(studioDir, subdir);
    await fs.mkdir(target, { recursive: true });

    const zipPath = path.join(DOWNLOAD_DIR, pkg);
    try {
      execSync(
        `unzip -qo ${JSON.stringify(zipPath)} -d ${JSON.stringify(target)}`,
        {
          stdio: ['pipe', 'pipe', 'pipe'],
          timeout: 60000,
        }
      );
    } catch {
      OutputHelper.warn(`Failed to extract ${pkg} (non-fatal)`);
    }
  }

  // Write AppSettings.xml
  const appSettings = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<Settings>',
    '        <ContentFolder>content</ContentFolder>',
    '        <BaseUrl>http://www.roblox.com</BaseUrl>',
    '</Settings>',
  ].join('\n');
  await fs.writeFile(
    path.join(studioDir, 'AppSettings.xml'),
    appSettings,
    'utf-8'
  );

  // Record installed version
  await writeInstalledVersionAsync(studioDir, version);

  OutputHelper.info('Studio installation complete.');
}

async function downloadPackageAsync(
  version: string,
  pkg: string
): Promise<void> {
  const dest = path.join(DOWNLOAD_DIR, pkg);

  // Skip if already downloaded
  try {
    const stat = await fs.stat(dest);
    if (stat.size > 0) {
      OutputHelper.verbose(`Cached: ${pkg}`);
      return;
    }
  } catch {
    // File doesn't exist, download it
  }

  const url = `${ROBLOX_CDN_BASE}/${version}-${pkg}`;
  OutputHelper.verbose(`Downloading ${pkg}...`);

  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(
      `Failed to download ${pkg}: ${response.status} ${response.statusText}`
    );
  }

  const buffer = Buffer.from(await response.arrayBuffer());
  await fs.writeFile(dest, buffer);
}
