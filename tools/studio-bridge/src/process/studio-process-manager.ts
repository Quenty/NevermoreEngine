/**
 * Locates a Roblox Studio installation and manages the Studio process
 * lifecycle. Supports Windows and macOS.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import { spawn, type ChildProcess } from 'child_process';
import { execa } from 'execa';
import { OutputHelper } from '@quenty/cli-output-helpers';

// ---------------------------------------------------------------------------
// Path resolution
// ---------------------------------------------------------------------------

/**
 * Find the path to the RobloxStudioBeta executable.
 * Throws if Studio cannot be located.
 */
export async function findStudioPathAsync(): Promise<string> {
  if (process.platform === 'win32') {
    return findStudioPathWindowsAsync();
  } else if (process.platform === 'darwin') {
    return findStudioPathMacAsync();
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
  }
  throw new Error(`Unsupported platform: ${process.platform}`);
}

// ---------------------------------------------------------------------------
// Process management
// ---------------------------------------------------------------------------

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
