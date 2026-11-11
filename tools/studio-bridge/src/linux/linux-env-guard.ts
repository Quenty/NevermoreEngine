/**
 * Environment guard for `linux *` subcommands.
 *
 * These commands require Wine and related tools that are only available inside
 * the Docker image or a properly configured Linux box.  This guard lets them
 * fail early with a helpful message instead of crashing mid-way.
 */

import * as os from 'os';
import { execFile } from 'child_process';
import { promisify } from 'util';
import { StudioBridgeError } from '../messages/studio-bridge-error.js';

const execFileAsync = promisify(execFile);

/**
 * Checks if the current environment can run linux/* commands.
 * Returns an error message if not, or undefined if OK.
 */
export async function checkLinuxEnvironmentAsync(): Promise<
  StudioBridgeError | undefined
> {
  if (os.platform() !== 'linux') {
    return new StudioBridgeError({
      code: 'UNSUPPORTED_PLATFORM',
      message:
        "'linux' commands only run on Linux; on Windows and macOS, Studio runs natively.",
      fix: "Use 'studio-bridge process run' instead.",
    });
  }

  try {
    await execFileAsync('which', ['wine']);
  } catch (err) {
    return new StudioBridgeError({
      code: 'WINE_MISSING',
      message: "Wine isn't installed, and 'linux' commands need it.",
      fix: "Use 'studio-bridge process run', which runs Studio in Docker without Wine.",
      cause: err,
    });
  }

  return undefined;
}
