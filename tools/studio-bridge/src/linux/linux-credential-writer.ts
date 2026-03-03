/**
 * Inject Roblox authentication credentials into Wine's Credential Manager.
 *
 * Studio expects three entries in Windows Credential Manager:
 * 1. userid: RobloxStudioAuthuserid → numeric user ID
 * 2. cookie name: RobloxStudioAuthCookies → ".ROBLOSECURITY"
 * 3. cookie value: RobloxStudioAuth.ROBLOSECURITY{userId} → the actual cookie
 *
 * This module:
 * - Compiles write-cred.c with MinGW (if not already compiled)
 * - Resolves the user ID from the cookie via Roblox API
 * - Runs `wine write-cred.exe` three times to inject all entries
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import { execSync } from 'child_process';
import { execa } from 'execa';
import { fileURLToPath } from 'url';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { ROBLOX_USERS_API, type LinuxStudioConfig } from './linux-config.js';
import { buildWineEnv } from './linux-wine-env.js';
import { COOKIE_NAME } from '@quenty/nevermore-cli-helpers';

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

  // Initialize Wine prefix if it doesn't exist yet (wineboot creates it).
  // This must happen before any wine command; otherwise the first run
  // blocks on Mono/Gecko install dialogs even with WINEDLLOVERRIDES.
  OutputHelper.verbose('Initializing Wine prefix...');
  const bootResult = await execa('wineboot', ['-i'], {
    env,
    reject: false,
    timeout: 120000,
  });
  if (bootResult.exitCode !== 0) {
    OutputHelper.warn(
      `wineboot exited with code ${bootResult.exitCode} (non-fatal)`
    );
  }

  // Write all three credential entries
  const entries: Array<[string, string]> = [
    ['https://www.roblox.com:RobloxStudioAuthuserid', String(userId)],
    ['https://www.roblox.com:RobloxStudioAuthCookies', COOKIE_NAME],
    [
      `https://www.roblox.com:RobloxStudioAuth${COOKIE_NAME}${userId}`,
      cookie,
    ],
  ];

  for (const [target, value] of entries) {
    OutputHelper.verbose(`Writing credential: ${target}`);
    const result = await execa('wine', [writeCredExe, target, value], {
      env,
      reject: false,
      timeout: 15000,
    });

    if (result.exitCode !== 0) {
      const stderr = result.stderr || result.stdout || 'unknown error';
      throw new Error(
        `Failed to write credential "${target}": ${stderr}`
      );
    }
  }

  // Also write to the Windows Registry path that Studio checks on startup.
  // Studio reads HKCU\Software\Roblox\RobloxStudioBrowser\roblox.com for
  // cached auth before showing the login dialog. Without this, Studio shows
  // "Is Studio Configured User Id Present: false" and blocks on login.
  await writeRegistryAuthAsync(cookie, userId, env);

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
