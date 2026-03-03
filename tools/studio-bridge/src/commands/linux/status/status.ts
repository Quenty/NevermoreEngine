/**
 * `linux status` — check the health of the Linux/Wine environment for
 * running Studio.
 */

import * as fs from 'fs/promises';
import { defineCommand } from '../../framework/define-command.js';
import { OutputHelper } from '@quenty/cli-output-helpers';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

// eslint-disable-next-line @typescript-eslint/no-empty-interface
interface StatusArgs {}

interface PrerequisiteStatus {
  name: string;
  available: boolean;
  version?: string;
  hint?: string;
}

interface StatusResult {
  healthy: boolean;
  prerequisites: PrerequisiteStatus[];
  display: { xvfb: boolean; openbox: boolean };
  studio: { installed: boolean; version?: string; fflags: boolean; shaders: boolean };
  auth: { writeCredExe: boolean; credentialsInjected: boolean };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function fileExistsAsync(filePath: string): Promise<boolean> {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

export async function statusHandlerAsync(_args: StatusArgs): Promise<StatusResult> {
  try {
    const linux = await import('../../../linux/index.js');
    const config = linux.resolveLinuxConfig();
    let allOk = true;

    // 1. Prerequisites
    OutputHelper.info('System prerequisites:');
    const prereqs = linux.checkPrerequisites();
    for (const p of prereqs) {
      const status = p.available
        ? `  OK  ${p.name}${p.version ? ` (${p.version})` : ''}`
        : `  MISSING  ${p.name} — ${p.hint}`;
      if (p.available) {
        OutputHelper.info(status);
      } else {
        OutputHelper.error(status);
        allOk = false;
      }
    }

    // 2. Display
    const displayNum = config.display.replace(':', '');
    const xvfbOk = linux.isXvfbRunning(displayNum);
    const openboxOk = linux.isOpenboxRunning();
    OutputHelper.info('');
    OutputHelper.info('Display:');
    OutputHelper.info(
      `  Xvfb (${config.display}): ${xvfbOk ? 'running' : 'not running'}`
    );
    OutputHelper.info(
      `  openbox: ${openboxOk ? 'running' : 'not running'}`
    );
    if (!xvfbOk || !openboxOk) allOk = false;

    // 3. Studio installation
    OutputHelper.info('');
    OutputHelper.info('Studio installation:');
    const studioExists = await fileExistsAsync(config.studioExe);
    OutputHelper.info(
      `  ${config.studioDir}: ${studioExists ? 'installed' : 'not found'}`
    );
    if (!studioExists) allOk = false;

    const { readInstalledVersionAsync } = await import(
      '../../../linux/linux-version-resolver.js'
    );
    const version = await readInstalledVersionAsync(config.studioDir);
    if (version) {
      OutputHelper.info(`  Version: ${version}`);
    }

    // 4. FFlags
    const fflagsExist = await fileExistsAsync(config.clientSettingsPath);
    OutputHelper.info(
      `  FFlags: ${fflagsExist ? 'configured' : 'not found'}`
    );

    // 5. Shaders
    const shadersExist = await fileExistsAsync(
      `${config.shadersDir}/shaders_glsl3.pack`
    );
    OutputHelper.info(
      `  Shaders: ${shadersExist ? 'present' : 'not found'}`
    );

    // 6. Credentials
    OutputHelper.info('');
    OutputHelper.info('Authentication:');
    const writeCredExists = await fileExistsAsync(config.writeCredExe);
    OutputHelper.info(
      `  write-cred.exe: ${writeCredExists ? 'compiled' : 'not found'}`
    );

    // Check Wine registry for credential entries
    let credentialsInjected = false;
    const wineRegPath = `${config.winePrefix}/user.reg`;
    const wineRegExists = await fileExistsAsync(wineRegPath);
    if (wineRegExists) {
      const regContent = await fs.readFile(wineRegPath, 'utf-8');
      credentialsInjected = regContent.includes('RobloxStudioAuth');
      OutputHelper.info(
        `  Wine credentials: ${credentialsInjected ? 'present' : 'not injected'}`
      );
      if (!credentialsInjected) allOk = false;
    } else {
      OutputHelper.info('  Wine prefix: not initialized');
      allOk = false;
    }

    // Summary
    OutputHelper.info('');
    if (allOk) {
      OutputHelper.info('Environment is ready for Studio.');
    } else {
      OutputHelper.warn('Environment has issues. See above for details.');
    }

    return {
      healthy: allOk,
      prerequisites: prereqs,
      display: { xvfb: xvfbOk, openbox: openboxOk },
      studio: {
        installed: studioExists,
        version: version ?? undefined,
        fflags: fflagsExist,
        shaders: shadersExist,
      },
      auth: { writeCredExe: writeCredExists, credentialsInjected },
    };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    OutputHelper.error(message);
    return {
      healthy: false,
      prerequisites: [],
      display: { xvfb: false, openbox: false },
      studio: { installed: false, fflags: false, shaders: false },
      auth: { writeCredExe: false, credentialsInjected: false },
    };
  }
}

// ---------------------------------------------------------------------------
// Command definition
// ---------------------------------------------------------------------------

export const linuxStatusCommand = defineCommand<StatusArgs, StatusResult>({
  group: 'linux',
  name: 'status',
  description: 'Check Linux/Wine environment health for Studio',
  category: 'infrastructure',
  safety: 'none',
  scope: 'standalone',
  args: {},
  handler: async (args) => statusHandlerAsync(args),
});
