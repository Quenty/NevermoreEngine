/**
 * Locates a Roblox Studio installation and manages the Studio process
 * lifecycle. Supports Windows, macOS, and Linux (via Wine).
 */

import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { spawn, type ChildProcess } from 'child_process';
import { execa } from 'execa';
import { OutputHelper } from '@quenty/cli-output-helpers';

/**
 * Find the path to the RobloxStudioBeta executable.
 * Throws if Studio cannot be located.
 */
export async function findStudioPathAsync(): Promise<string> {
  if (process.platform === 'win32') {
    return findStudioPathWindowsAsync();
  } else if (process.platform === 'darwin') {
    return findStudioPathMacAsync();
  } else if (process.platform === 'linux') {
    return findStudioPathLinuxAsync();
  }
  throw new Error(`Unsupported platform: ${process.platform}`);
}

async function findStudioPathWindowsAsync(): Promise<string> {
  const localAppData = process.env.LOCALAPPDATA;
  if (!localAppData) {
    throw new Error('LOCALAPPDATA environment variable is not set');
  }

  const versionsDir = path.join(localAppData, 'Roblox', 'Versions');

  let entries: string[];
  try {
    entries = await fs.readdir(versionsDir);
  } catch {
    throw new Error(`Could not read Roblox versions directory: ${versionsDir}`);
  }

  // Each version folder may contain RobloxStudioBeta.exe
  for (const entry of entries) {
    const candidate = path.join(versionsDir, entry, 'RobloxStudioBeta.exe');
    try {
      await fs.access(candidate);
      return candidate;
    } catch {
      // not in this folder
    }
  }

  throw new Error(
    `Could not find RobloxStudioBeta.exe in any version folder under ${versionsDir}`
  );
}

async function findStudioPathMacAsync(): Promise<string> {
  const candidate =
    '/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudioBeta';
  try {
    await fs.access(candidate);
    return candidate;
  } catch {
    throw new Error(`Could not find Roblox Studio at ${candidate}`);
  }
}

async function findStudioPathLinuxAsync(): Promise<string> {
  const { resolveLinuxConfig } = await import('../linux/linux-config.js');
  const config = resolveLinuxConfig();

  try {
    await fs.access(config.studioExe);
    return config.studioExe;
  } catch {
    throw new Error(
      `Could not find Roblox Studio at ${config.studioExe}. Run "studio-bridge linux setup" first.`
    );
  }
}

/**
 * Resolve the Studio plugins folder for the current platform.
 */
export function findPluginsFolder(): string {
  if (process.platform === 'win32') {
    const localAppData = process.env.LOCALAPPDATA;
    if (!localAppData) {
      throw new Error('LOCALAPPDATA environment variable is not set');
    }
    return path.join(localAppData, 'Roblox', 'Plugins');
  } else if (process.platform === 'darwin') {
    const home = process.env.HOME;
    if (!home) {
      throw new Error('HOME environment variable is not set');
    }
    return path.join(home, 'Documents', 'Roblox', 'Plugins');
  } else if (process.platform === 'linux') {
    // Studio runs under Wine and resolves plugins via %LOCALAPPDATA%
    const winePrefix =
      process.env.WINEPREFIX || path.join(os.homedir(), '.wine');
    const wineUser = process.env.USER || os.userInfo().username;
    return path.join(
      winePrefix,
      'drive_c',
      'users',
      wineUser,
      'AppData',
      'Local',
      'Roblox',
      'Plugins'
    );
  }
  throw new Error(`Unsupported platform: ${process.platform}`);
}

export interface StudioProcess {
  /** The underlying child process handle */
  process: ChildProcess;
  /** Kill the Studio process (idempotent, best-effort) */
  killAsync: () => Promise<void>;
}

/**
 * Launch Roblox Studio with the given place file.
 *
 * Uses Node's built-in `spawn` with `detached: true` + `unref()` so that
 * Studio survives after the CLI process exits. execa's internal Job Object
 * on Windows kills children on parent exit, so we avoid it here.
 */
export async function launchStudioAsync(
  placePath: string
): Promise<StudioProcess> {
  if (process.platform === 'linux') {
    return launchStudioLinuxAsync(placePath);
  }

  const studioExe = await findStudioPathAsync();
  OutputHelper.verbose(`[StudioBridge] ${studioExe} "${placePath}"`);

  const proc = spawn(studioExe, placePath ? [placePath] : [], {
    detached: true,
    stdio: 'ignore',
  });

  // Allow our Node process to exit without waiting for Studio
  proc.unref();

  let killed = false;
  const killAsync = async () => {
    if (killed) return;
    killed = true;
    try {
      // On Windows, use taskkill to reliably kill the process tree
      if (process.platform === 'win32') {
        if (proc.pid) {
          await execa('taskkill', ['/F', '/T', '/PID', String(proc.pid)], {
            reject: false,
          });
        }
      } else {
        proc.kill('SIGTERM');
      }
    } catch {
      // Best effort
    }
  };

  return { process: proc, killAsync };
}

async function launchStudioLinuxAsync(
  placePath: string
): Promise<StudioProcess> {
  const { launchStudioLinuxAsync: launch } = await import(
    '../linux/linux-studio-launcher.js'
  );
  const studioExe = await findStudioPathAsync();
  return launch(studioExe, placePath);
}
