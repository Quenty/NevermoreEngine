/**
 * Linux-specific Studio launch via Wine. Called by the process manager
 * when `process.platform === 'linux'`.
 */

import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { spawn } from 'child_process';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { resolveLinuxConfig } from './linux-config.js';
import { buildWineEnv } from './linux-wine-env.js';
import { ensureDisplayAsync, ensureWindowManagerAsync } from './linux-display-manager.js';
import type { StudioProcess } from '../process/studio-process-manager.js';

/**
 * Launch Studio under Wine with proper display and environment setup.
 */
export async function launchStudioLinuxAsync(
  studioExe: string,
  placePath: string,
): Promise<StudioProcess> {
  const config = resolveLinuxConfig();

  // Ensure virtual display is running
  await ensureDisplayAsync(config);
  await ensureWindowManagerAsync(config);

  const env = buildWineEnv(config);
  OutputHelper.verbose(`[StudioBridge] wine ${studioExe} "${placePath}"`);

  // Write Wine stderr to a log file so we can diagnose launch failures.
  const logPath = path.join(os.tmpdir(), 'studio-bridge-wine.log');
  const logFd = fs.openSync(logPath, 'w');
  OutputHelper.verbose(`[StudioBridge] Wine log: ${logPath}`);

  const proc = spawn('wine', [studioExe, placePath], {
    detached: true,
    stdio: ['ignore', logFd, logFd],
    env,
  });

  // Close our copy of the fd — the child owns it now
  fs.closeSync(logFd);

  // Detect early process exit (crash or failure to start)
  proc.on('exit', (code, signal) => {
    OutputHelper.verbose(
      `[StudioBridge] Wine process exited (code=${code}, signal=${signal})`
    );
  });

  // Allow our Node process to exit without waiting for Studio
  proc.unref();

  // Tail the Wine log in verbose mode so diagnostics appear
  const tailProc = spawn('tail', ['-f', logPath], { stdio: ['ignore', 'pipe', 'ignore'] });
  tailProc.stdout?.on('data', (chunk: Buffer) => {
    const lines = chunk.toString('utf-8').trim().split('\n');
    for (const line of lines) {
      if (line) {
        OutputHelper.verbose(`[Wine] ${line}`);
      }
    }
  });
  tailProc.unref();

  let killed = false;
  const killAsync = async () => {
    if (killed) return;
    killed = true;
    try {
      tailProc.kill('SIGTERM');
    } catch {
      // Best effort
    }
    try {
      proc.kill('SIGTERM');
    } catch {
      // Best effort
    }
  };

  return { process: proc, killAsync };
}
