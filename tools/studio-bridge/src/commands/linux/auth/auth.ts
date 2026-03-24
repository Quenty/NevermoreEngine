/**
 * `linux auth` — inject .ROBLOSECURITY cookie into Wine's Credential Manager
 * so Studio can authenticate.
 */

import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { getRobloxCookieAsync } from '@quenty/nevermore-cli-helpers';
import { checkLinuxEnvironmentAsync } from '../../../linux/linux-env-guard.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface AuthArgs {
  cookie?: string;
}

interface AuthResult {
  success: boolean;
  summary: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function readStdinAsync(): Promise<string> {
  return new Promise((resolve, reject) => {
    let data = '';
    process.stdin.setEncoding('utf-8');
    process.stdin.on('data', (chunk) => {
      data += chunk;
    });
    process.stdin.on('end', () => resolve(data));
    process.stdin.on('error', reject);
  });
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

export async function authHandlerAsync(args: AuthArgs): Promise<AuthResult> {
  try {
    const envError = await checkLinuxEnvironmentAsync();
    if (envError) {
      OutputHelper.error(envError);
      process.exit(1);
    }

    const linux = await import('../../../linux/index.js');
    const config = linux.resolveLinuxConfig();

    // Resolve cookie from explicit arg, stdin, or shared auth
    let cookie: string;
    if (args.cookie === '-') {
      // Read from stdin
      cookie = await readStdinAsync();
      if (!cookie.trim()) {
        throw new Error('No cookie provided on stdin');
      }
      cookie = cookie.trim();
    } else if (args.cookie) {
      cookie = args.cookie;
    } else {
      cookie = await getRobloxCookieAsync();
    }

    // Validate cookie before attempting Wine injection
    const { validateCookieAsync } = await import('@quenty/nevermore-cli-helpers');
    const validation = await validateCookieAsync(cookie);
    if (!validation.valid) {
      if (validation.reason === 'network_error') {
        OutputHelper.warn('Could not validate ROBLOSECURITY cookie (network error). Continuing anyway.');
      } else {
        throw new Error(
          `ROBLOSECURITY cookie is invalid or expired (HTTP ${validation.status}). Update the cookie and try again.`,
        );
      }
    }

    // Ensure display is running (Wine needs it for credential write)
    await linux.ensureDisplayAsync(config);

    // Inject credentials
    await linux.injectCredentialsAsync({ cookie, config });

    OutputHelper.info('Authentication complete.');
    OutputHelper.hint(
      'Next: run "studio-bridge process launch" to start Studio'
    );

    return { success: true, summary: 'Credentials injected into Wine Credential Manager' };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    OutputHelper.error(message);
    return { success: false, summary: message };
  }
}

// ---------------------------------------------------------------------------
// Command definition
// ---------------------------------------------------------------------------

export const linuxAuthCommand = defineCommand<AuthArgs, AuthResult>({
  group: 'linux',
  name: 'auth',
  description: 'Inject .ROBLOSECURITY cookie into Wine Credential Manager (within Docker image or Linux with Wine)',
  category: 'infrastructure',
  safety: 'none',
  scope: 'standalone',
  args: {
    cookie: arg.option({
      description:
        'Cookie value (or "-" to read from stdin). Falls back to $ROBLOSECURITY env var or interactive prompt.',
    }),
  },
  handler: async (args) => authHandlerAsync(args),
});
