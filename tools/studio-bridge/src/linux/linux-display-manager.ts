/**
 * Manage the Xvfb virtual framebuffer and openbox window manager
 * required for Studio to render under Wine.
 */

import { execSync } from 'child_process';
import { execa } from 'execa';
import type { LinuxStudioConfig } from './linux-config.js';

/**
 * Ensure Xvfb is running on the configured DISPLAY.
 * If already running, this is a no-op.
 */
export async function ensureDisplayAsync(
  config: LinuxStudioConfig
): Promise<void> {
  const display = config.display;
  const displayNum = display.replace(':', '');

  if (isXvfbRunning(displayNum)) {
    return;
  }

  // Start Xvfb detached with 1024x768 24-bit color
  const xvfb = execa('Xvfb', [display, '-screen', '0', '1024x768x24'], {
    detached: true,
    stdio: 'ignore',
    reject: false,
    env: { ...process.env },
  });
  xvfb.unref?.();

  // Give it a moment to start
  await sleepAsync(500);

  if (!isXvfbRunning(displayNum)) {
    throw new Error(`Failed to start Xvfb on display ${display}`);
  }
}

/**
 * Ensure openbox window manager is running on the display.
 * Required for Studio's modal dialogs to function.
 */
export async function ensureWindowManagerAsync(
  config: LinuxStudioConfig
): Promise<void> {
  if (isOpenboxRunning()) {
    return;
  }

  const openbox = execa('openbox', [], {
    detached: true,
    stdio: 'ignore',
    reject: false,
    env: {
      ...process.env,
      DISPLAY: config.display,
    },
  });
  openbox.unref?.();

  await sleepAsync(500);
}

/**
 * Check if Xvfb is running on a given display.
 */
export function isXvfbRunning(displayNum?: string): boolean {
  try {
    if (displayNum) {
      const output = execSync(`pgrep -a Xvfb`, {
        encoding: 'utf-8',
        timeout: 3000,
        stdio: ['pipe', 'pipe', 'pipe'],
      });
      return output.includes(`:${displayNum}`);
    }
    execSync('pgrep -x Xvfb', {
      timeout: 3000,
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    return true;
  } catch {
    return false;
  }
}

/**
 * Check if openbox is running.
 */
export function isOpenboxRunning(): boolean {
  try {
    execSync('pgrep -x openbox', {
      timeout: 3000,
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    return true;
  } catch {
    return false;
  }
}

function sleepAsync(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
