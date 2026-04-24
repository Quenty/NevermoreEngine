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

const execFileAsync = promisify(execFile);

/**
 * Checks if the current environment can run linux/* commands.
 * Returns an error message if not, or undefined if OK.
 */
export async function checkLinuxEnvironmentAsync(): Promise<string | undefined> {
  if (os.platform() !== 'linux') {
    return (
      "linux commands require a Linux environment. On Windows/macOS, Studio runs natively — use 'studio-bridge process run' instead."
    );
  }

  try {
    await execFileAsync('which', ['wine']);
  } catch {
    return (
      'Wine is not installed. These commands require Wine and related tools.\n\n' +
      "To run scripts, use 'studio-bridge process run' which auto-delegates to Docker.\n" +
      'To set up a full Wine environment, run inside the Docker image:\n' +
      '  docker run --rm -it ghcr.io/quenty/nevermore-studio-linux:latest bash'
    );
  }

  return undefined;
}
