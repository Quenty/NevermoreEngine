/**
 * Cookie auth and place creation for Roblox legacy APIs.
 * Based on Mantle: https://github.com/blake-mealey/mantle
 */

import inquirer from 'inquirer';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { COOKIE_NAME } from './cookie-parser.js';
import { readCookie as readWindowsCookie } from './windows.js';
import { readCookie as readMacOSCookie } from './macos.js';

/**
 * Resolve the .ROBLOSECURITY cookie for legacy Roblox API calls.
 *
 * Resolution order (matching Mantle's rbx_cookie crate):
 * 1. ROBLOSECURITY environment variable
 * 2. Platform credential store (Windows Credential Manager / macOS HTTPStorages)
 * 3. Platform legacy store (Windows Registry / macOS plist)
 * 4. Interactive prompt
 */
export async function getRobloxCookieAsync(): Promise<string> {
  const envCookie = process.env.ROBLOSECURITY;
  if (envCookie) {
    return envCookie;
  }

  const platformCookie = readPlatformCookie();
  if (platformCookie) {
    return platformCookie;
  }

  // No interactive prompt in non-TTY environments (CI)
  if (!process.stdin.isTTY) {
    throw new Error(
      'No .ROBLOSECURITY cookie available (set ROBLOSECURITY env var for CI)'
    );
  }

  const { cookie } = await inquirer.prompt([
    {
      type: 'password',
      name: 'cookie',
      message: 'Enter your .ROBLOSECURITY cookie (from browser or Studio):',
      mask: '*',
      validate: (input: string) => input.length > 0 || 'Cookie cannot be empty',
    },
  ]);

  return cookie;
}

function readPlatformCookie(): string | undefined {
  switch (process.platform) {
    case 'win32':
      return readWindowsCookie();
    case 'darwin':
      return readMacOSCookie();
    default:
      return undefined;
  }
}

/**
 * Make a cookie-authenticated request to Roblox, handling CSRF token exchange.
 */
async function fetchWithCsrfAsync(
  url: string,
  cookie: string,
  options: RequestInit = {}
): Promise<Response> {
  const headers: Record<string, string> = {
    Cookie: `${COOKIE_NAME}=${cookie}`,
    'User-Agent': 'Roblox/WinInet',
    ...(options.headers as Record<string, string> | undefined),
  };

  let response = await fetch(url, {
    ...options,
    headers,
  });

  if (response.status === 403) {
    const csrfToken = response.headers.get('x-csrf-token');
    if (csrfToken) {
      headers['X-CSRF-TOKEN'] = csrfToken;
      response = await fetch(url, {
        ...options,
        headers,
      });
    }
  }

  return response;
}

/**
 * Create a new place in a universe using the legacy cookie-authenticated API.
 * Returns the new place ID.
 */
export async function createPlaceInUniverseAsync(
  cookie: string,
  universeId: number,
  placeName: string
): Promise<number> {
  OutputHelper.verbose(
    `Creating place "${placeName}" in universe ${universeId}...`
  );

  const createResponse = await fetchWithCsrfAsync(
    `https://apis.roblox.com/universes/v1/user/universes/${universeId}/places`,
    cookie,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ templatePlaceId: 95206881 }),
    }
  );

  if (!createResponse.ok) {
    const text = await createResponse.text();
    throw new Error(
      `Failed to create place: ${createResponse.status} ${createResponse.statusText}: ${text}`
    );
  }

  const createData = (await createResponse.json()) as { placeId: number };
  const placeId = createData.placeId;

  const renameResponse = await fetchWithCsrfAsync(
    `https://develop.roblox.com/v2/places/${placeId}`,
    cookie,
    {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ name: placeName }),
    }
  );

  if (!renameResponse.ok) {
    OutputHelper.warn(
      `Place created (${placeId}) but rename failed — you can rename it manually.`
    );
  }

  OutputHelper.verbose(`Created place "${placeName}" — ID: ${placeId}`);
  return placeId;
}

export interface RenamePlaceResult {
  success: boolean;
  reason?: 'no_cookie' | 'api_error';
  status?: number;
}

/**
 * Try to rename an existing place via the develop.roblox.com API.
 */
export async function tryRenamePlaceAsync(
  placeId: number,
  placeName: string
): Promise<RenamePlaceResult> {
  let cookie: string;
  try {
    cookie = await getRobloxCookieAsync();
  } catch {
    return { success: false, reason: 'no_cookie' };
  }

  const response = await fetchWithCsrfAsync(
    `https://develop.roblox.com/v2/places/${placeId}`,
    cookie,
    {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ name: placeName }),
    }
  );

  if (response.ok) {
    OutputHelper.verbose(`Renamed place ${placeId} to "${placeName}"`);
    return { success: true };
  }

  return { success: false, reason: 'api_error', status: response.status };
}
