/**
 * `linux inject-credentials` — inject .ROBLOSECURITY cookie into Wine's
 * Credential Manager so Studio can authenticate.
 */

import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { getRobloxCookieAsync } from '@quenty/nevermore-cli-helpers/cookie';
import { checkLinuxEnvironmentAsync } from '../../../linux/linux-env-guard.js';
import { StudioBridgeError } from '../../../messages/studio-bridge-error.js';
import { warnUser } from '../../../messages/warn-user.js';

interface AuthArgs {
  cookie?: string;
}

interface AuthResult {
  success: boolean;
  summary: string;
}

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

export async function injectCredentialsHandlerAsync(
  args: AuthArgs
): Promise<AuthResult> {
  const envError = await checkLinuxEnvironmentAsync();
  if (envError) {
    throw envError;
  }

  const linux = await import('../../../linux/index.js');
  const config = linux.resolveLinuxConfig();

  // Resolve cookie from explicit arg, stdin, or shared auth
  let cookie: string;
  if (args.cookie === '-') {
    // Read from stdin
    cookie = await readStdinAsync();
    if (!cookie.trim()) {
      throw new StudioBridgeError({
        code: 'MISSING_COOKIE',
        message: '--cookie - reads the cookie from stdin, but stdin was empty.',
        fix: 'Pipe the .ROBLOSECURITY cookie in, or pass it as --cookie <value>.',
      });
    }
    cookie = cookie.trim();
  } else if (args.cookie) {
    cookie = args.cookie;
  } else {
    cookie = await getRobloxCookieAsync();
  }

  // Validate cookie before attempting Wine injection
  const { validateCookieAsync } = await import(
    '@quenty/nevermore-cli-helpers/cookie'
  );
  const validation = await validateCookieAsync(cookie);
  if (!validation.valid) {
    if (validation.reason === 'network_error') {
      warnUser({
        code: 'COOKIE_UNCHECKED',
        message:
          "Couldn't reach Roblox to check the .ROBLOSECURITY cookie, so Studio may fail to log in.",
        fix: 'Check your network connection if it does.',
      });
    } else {
      throw new StudioBridgeError({
        code: 'INVALID_COOKIE',
        message:
          'Roblox rejected the .ROBLOSECURITY cookie: it is invalid or expired.',
        fix: 'Run this command again with a fresh .ROBLOSECURITY cookie.',
        cause: `HTTP ${validation.status}`,
      });
    }
  }

  // Ensure display is running (Wine needs it for credential write)
  await linux.ensureDisplayAsync(config);

  // Inject credentials
  await linux.injectCredentialsAsync({ cookie, config });

  OutputHelper.info('Credentials injected.');
  OutputHelper.hint('Next: run "studio-bridge process launch" to start Studio');

  return {
    success: true,
    summary: 'Credentials injected into Wine Credential Manager',
  };
}

export const linuxInjectCredentialsCommand = defineCommand<
  AuthArgs,
  AuthResult
>({
  group: 'linux',
  name: 'inject-credentials',
  description:
    'Inject .ROBLOSECURITY cookie into Wine Credential Manager (within Docker image or Linux with Wine)',
  category: 'infrastructure',
  safety: 'none',
  scope: 'standalone',
  args: {
    cookie: arg.option({
      description:
        'Cookie value (or "-" to read from stdin). Falls back to $ROBLOSECURITY env var or interactive prompt.',
    }),
  },
  handler: async (args) => injectCredentialsHandlerAsync(args),
});
