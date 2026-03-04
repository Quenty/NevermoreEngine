/**
 * Inject Roblox authentication credentials into Wine's Credential Manager.
 *
 * Studio expects three entries in Windows Credential Manager:
 * 1. userid: RobloxStudioAuthuserid → numeric user ID
 * 2. cookie name: RobloxStudioAuthCookies → ".ROBLOSECURITY"
 * 3. cookie value: RobloxStudioAuth.ROBLOSECURITY{userId} → the actual cookie
 *
 * Additionally, Studio 0.710+ uses OAuth2 for startup authentication.
 * Without a valid refresh token, Studio blocks on a WebView2 login dialog
 * that doesn't work under Wine. This module obtains a refresh token by
 * calling Roblox's first-party OAuth authorization endpoint with the
 * .ROBLOSECURITY cookie, then injects it into the Credential Manager.
 *
 * This module:
 * - Compiles write-cred.c with MinGW (if not already compiled)
 * - Resolves the user ID from the cookie via Roblox API
 * - Obtains an OAuth2 refresh token via Roblox's authorization endpoint
 * - Runs `wine write-cred.exe` to inject all credential entries
 */

import * as crypto from 'crypto';
import * as fs from 'fs/promises';
import * as path from 'path';
import { execSync } from 'child_process';
import { execa } from 'execa';
import { fileURLToPath } from 'url';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { ROBLOX_USERS_API, type LinuxStudioConfig } from './linux-config.js';
import { buildWineEnv } from './linux-wine-env.js';
import { COOKIE_NAME } from '@quenty/nevermore-cli-helpers';

/** Studio's first-party OAuth client ID (extracted from the Studio binary) */
const STUDIO_OAUTH_CLIENT_ID = '7968549422692352298';

/** Roblox OAuth API base */
const ROBLOX_OAUTH_API = 'https://apis.roblox.com/oauth/v1';

/** Roblox Auth API base (for CSRF tokens) */
const ROBLOX_AUTH_API = 'https://auth.roblox.com';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/**
 * Locate write-cred.c source file. Searches several candidate paths
 * relative to __dirname, which at runtime is dist/src/linux/.
 */
async function findWriteCredSourceAsync(): Promise<string> {
  const candidates = [
    // Alongside compiled JS (if .c was copied to dist)
    path.join(__dirname, 'write-cred.c'),
    // Source tree (from dist/src/linux/ → src/linux/)
    path.resolve(__dirname, '../../../src/linux/write-cred.c'),
    // Sibling to package root
    path.resolve(__dirname, '../../linux/write-cred.c'),
  ];

  for (const candidate of candidates) {
    try {
      await fs.access(candidate);
      return candidate;
    } catch {
      // Try next
    }
  }

  throw new Error(
    'write-cred.c source not found. Ensure the linux module is properly installed.'
  );
}

/**
 * Compile write-cred.exe from bundled C source using MinGW.
 */
export async function compileWriteCredAsync(
  config: LinuxStudioConfig
): Promise<void> {
  const { writeCredExe } = config;
  const sourcePath = await findWriteCredSourceAsync();

  OutputHelper.verbose(`Compiling ${sourcePath} → ${writeCredExe}`);

  await fs.mkdir(path.dirname(writeCredExe), { recursive: true });

  try {
    execSync(
      `x86_64-w64-mingw32-gcc -o ${JSON.stringify(writeCredExe)} ${JSON.stringify(sourcePath)} -lcredui -ladvapi32`,
      {
        stdio: ['pipe', 'pipe', 'pipe'],
        timeout: 30000,
      }
    );
  } catch (error) {
    throw new Error(
      `Failed to compile write-cred.exe: ${error instanceof Error ? error.message : error}`
    );
  }

  OutputHelper.verbose('write-cred.exe compiled successfully.');
}

interface InjectCredentialsOptions {
  cookie: string;
  config: LinuxStudioConfig;
}

/**
 * Inject all three required credentials into Wine's Credential Manager.
 */
export async function injectCredentialsAsync(
  options: InjectCredentialsOptions
): Promise<void> {
  const { cookie, config } = options;

  // Ensure write-cred.exe exists
  try {
    await fs.access(config.writeCredExe);
  } catch {
    await compileWriteCredAsync(config);
  }

  // Resolve user ID from cookie
  const userId = await resolveUserIdAsync(cookie);
  OutputHelper.verbose(`Resolved user ID: ${userId}`);

  const env = buildWineEnv(config);
  const writeCredExe = config.writeCredExe;

  // Initialize or update the Wine prefix. wineboot must run before any wine
  // command to create the prefix on first use, and must also run in containers
  // where the prefix was pre-built at image time — the update pass refreshes
  // stale registry entries and user profile paths for the current environment.
  const prefixExists = await fs.access(path.join(config.winePrefix, 'system.reg')).then(() => true, () => false);
  const winebootFlag = prefixExists ? '-u' : '-i';
  OutputHelper.verbose(
    prefixExists
      ? 'Updating Wine prefix for current environment...'
      : 'Initializing Wine prefix...'
  );
  const bootResult = await execa('wineboot', [winebootFlag], {
    env,
    reject: false,
    timeout: 120000,
  });
  if (bootResult.exitCode !== 0) {
    OutputHelper.warn(
      `wineboot exited with code ${bootResult.exitCode} (non-fatal)`
    );
  }

  // Write all three credential entries in a single Wine invocation
  const entries: Array<[string, string]> = [
    ['https://www.roblox.com:RobloxStudioAuthuserid', String(userId)],
    ['https://www.roblox.com:RobloxStudioAuthCookies', COOKIE_NAME],
    [
      `https://www.roblox.com:RobloxStudioAuth${COOKIE_NAME}${userId}`,
      cookie,
    ],
  ];

  OutputHelper.verbose(`Writing ${entries.length} credential entries...`);
  const credArgs = entries.flatMap(([target, value]) => [target, value]);
  const result = await execa('wine', [writeCredExe, ...credArgs], {
    env,
    reject: false,
    timeout: 30000,
  });

  if (result.exitCode !== 0) {
    const stderr = result.stderr || result.stdout || 'unknown error';
    throw new Error(`Failed to write credentials: ${stderr}`);
  }

  // Also write to the Windows Registry path that Studio checks on startup.
  await writeRegistryAuthAsync(cookie, userId, env);

  // Obtain and inject an OAuth2 refresh token. Studio 0.710+ requires this
  // for startup authentication — without it, Studio blocks on a WebView2
  // login dialog that doesn't work under Wine.
  await injectOAuth2RefreshTokenAsync(cookie, userId, writeCredExe, env);

  OutputHelper.info('Credentials injected into Wine Credential Manager.');
}

/**
 * Write auth data to Wine registry entries that Studio checks on startup.
 * This bypasses Studio's WebView2 login dialog (which doesn't work on Wine).
 */
async function writeRegistryAuthAsync(
  cookie: string,
  userId: number,
  env: Record<string, string>
): Promise<void> {
  const regPath = 'HKCU\\Software\\Roblox\\RobloxStudioBrowser\\roblox.com';

  const regEntries: Array<[string, string, string]> = [
    [regPath, COOKIE_NAME, cookie],
  ];

  for (const [keyPath, name, value] of regEntries) {
    OutputHelper.verbose(`Writing registry: ${keyPath}\\${name}`);
    const result = await execa(
      'wine',
      ['reg', 'add', keyPath, '/v', name, '/t', 'REG_SZ', '/d', value, '/f'],
      { env, reject: false, timeout: 15000 }
    );
    if (result.exitCode !== 0) {
      OutputHelper.warn(
        `Failed to write registry entry ${name} (non-fatal): ${result.stderr || result.stdout}`
      );
    }
  }

  // Also set the user ID so Studio recognizes a configured user
  const userRegPath = 'HKCU\\Software\\Roblox\\RobloxStudioBrowser';
  const userIdResult = await execa(
    'wine',
    ['reg', 'add', userRegPath, '/v', 'UserId', '/t', 'REG_SZ', '/d', String(userId), '/f'],
    { env, reject: false, timeout: 15000 }
  );
  if (userIdResult.exitCode !== 0) {
    OutputHelper.warn(
      `Failed to write UserId registry entry (non-fatal): ${userIdResult.stderr || userIdResult.stdout}`
    );
  }
}

/**
 * Obtain an OAuth2 refresh token from the .ROBLOSECURITY cookie and inject
 * it into Wine's Credential Manager. This completes Studio's first-party
 * OAuth PKCE flow programmatically, bypassing the WebView2 login dialog.
 */
async function injectOAuth2RefreshTokenAsync(
  cookie: string,
  userId: number,
  writeCredExe: string,
  env: Record<string, string>
): Promise<void> {
  OutputHelper.verbose('Obtaining OAuth2 refresh token...');

  // Step 1: Get CSRF token (Roblox requires this for mutating API calls)
  const csrfToken = await getCsrfTokenAsync(cookie);

  // Step 2: Generate PKCE code verifier and challenge
  const codeVerifier = crypto
    .randomBytes(32)
    .toString('base64url')
    .slice(0, 43);
  const codeChallenge = crypto
    .createHash('sha256')
    .update(codeVerifier)
    .digest('base64url');
  const state = crypto.randomBytes(16).toString('hex');

  // Step 3: Request authorization code
  const authResponse = await fetch(`${ROBLOX_OAUTH_API}/authorizations`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-TOKEN': csrfToken,
      Cookie: `${COOKIE_NAME}=${cookie}`,
    },
    body: JSON.stringify({
      clientId: STUDIO_OAUTH_CLIENT_ID,
      responseTypes: ['Code'],
      redirectUri: 'roblox-studio-auth:/',
      scopes: [
        { scopeType: 'openid', operations: ['read'] },
        { scopeType: 'credentials', operations: ['read'] },
        { scopeType: 'profile', operations: ['read'] },
        { scopeType: 'age', operations: ['read'] },
        { scopeType: 'roles', operations: ['read'] },
        { scopeType: 'premium', operations: ['read'] },
      ],
      nonce: 'id-roblox',
      codeChallengeMethod: 's256',
      codeChallenge,
      state,
    }),
  });

  if (!authResponse.ok) {
    const body = await authResponse.text();
    throw new Error(
      `OAuth authorization failed: ${authResponse.status} ${body}`
    );
  }

  const authData = (await authResponse.json()) as { location: string };
  const locationUrl = new URL(authData.location);
  const authCode = locationUrl.searchParams.get('code');
  if (!authCode) {
    throw new Error('OAuth authorization response missing code');
  }

  OutputHelper.verbose('OAuth authorization code obtained.');

  // Step 4: Exchange authorization code for tokens
  const tokenResponse = await fetch(`${ROBLOX_OAUTH_API}/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      code: authCode,
      code_verifier: codeVerifier,
      client_id: STUDIO_OAUTH_CLIENT_ID,
    }).toString(),
  });

  if (!tokenResponse.ok) {
    const body = await tokenResponse.text();
    throw new Error(`OAuth token exchange failed: ${tokenResponse.status} ${body}`);
  }

  const tokenData = (await tokenResponse.json()) as {
    refresh_token: string;
    access_token: string;
  };

  if (!tokenData.refresh_token) {
    throw new Error('OAuth token response missing refresh_token');
  }

  OutputHelper.verbose(
    `OAuth refresh token obtained (${tokenData.refresh_token.length} chars).`
  );

  // Step 5: Inject the refresh token into Wine's Credential Manager
  const target = `https://www.roblox.com:RobloxStudioAuthoauth2RefreshToken${userId}`;
  OutputHelper.verbose(`Writing OAuth2 credential: ${target}`);
  const result = await execa(
    'wine',
    [writeCredExe, target, tokenData.refresh_token],
    { env, reject: false, timeout: 15000 }
  );

  if (result.exitCode !== 0) {
    const stderr = result.stderr || result.stdout || 'unknown error';
    throw new Error(`Failed to write OAuth2 refresh token credential: ${stderr}`);
  }

  OutputHelper.verbose('OAuth2 refresh token injected into Wine Credential Manager.');
}

/**
 * Get a CSRF token from Roblox's auth API. The first request returns 403
 * with the token in the x-csrf-token header.
 */
async function getCsrfTokenAsync(cookie: string): Promise<string> {
  const response = await fetch(
    `${ROBLOX_AUTH_API}/v1/authentication-ticket/`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Cookie: `${COOKIE_NAME}=${cookie}`,
        Referer: 'https://www.roblox.com/',
      },
      body: '{}',
    }
  );

  const csrfToken = response.headers.get('x-csrf-token');
  if (!csrfToken) {
    throw new Error(
      `Failed to obtain CSRF token: ${response.status} ${response.statusText}`
    );
  }

  return csrfToken;
}

/**
 * Resolve the authenticated user's numeric ID from a .ROBLOSECURITY cookie.
 */
async function resolveUserIdAsync(cookie: string): Promise<number> {
  const response = await fetch(
    `${ROBLOX_USERS_API}/v1/users/authenticated`,
    {
      headers: {
        Cookie: `${COOKIE_NAME}=${cookie}`,
      },
    }
  );

  if (!response.ok) {
    throw new Error(
      `Failed to resolve user ID: ${response.status} ${response.statusText}. Is your cookie valid?`
    );
  }

  const data = (await response.json()) as { id: number };
  return data.id;
}
