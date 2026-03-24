import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { COOKIE_NAME } from './cookie-parser.js';

/**
 * Read .ROBLOSECURITY from Wine's Credential Manager stored in the Wine
 * registry file ($WINEPREFIX/user.reg).
 *
 * Wine stores Windows Credential Manager entries as registry keys under
 * [Software\\Wine\\Credential Manager]. Each credential target becomes a
 * subkey with hex-encoded blob values.
 *
 * Resolution order (mirrors windows.ts):
 * 1. Modern: user-specific credential (RobloxStudioAuth.ROBLOSECURITY{userId})
 * 2. Legacy: RobloxStudioAuth.ROBLOSECURITY (no user suffix)
 */
export function readCookie(): string | undefined {
  const userReg = getWineUserRegPath();
  if (!userReg || !fs.existsSync(userReg)) {
    return undefined;
  }

  let regContent: string;
  try {
    regContent = fs.readFileSync(userReg, 'utf-8');
  } catch {
    return undefined;
  }

  const credentials = parseWineCredentials(regContent);

  // Modern: user-specific credential
  const userId = credentials.get(
    'https://www.roblox.com:RobloxStudioAuthuserid'
  );
  if (userId) {
    const cookie = credentials.get(
      `https://www.roblox.com:RobloxStudioAuth${COOKIE_NAME}${userId}`
    );
    if (cookie) {
      OutputHelper.verbose(
        `Loaded cookie from Wine Credential Manager (user ${userId}).`
      );
      return cookie;
    }
  }

  // Legacy: no user suffix
  const legacyCookie = credentials.get(
    `https://www.roblox.com:RobloxStudioAuth${COOKIE_NAME}`
  );
  if (legacyCookie) {
    OutputHelper.verbose(
      'Loaded cookie from Wine Credential Manager (legacy).'
    );
    return legacyCookie;
  }

  return undefined;
}

function getWineUserRegPath(): string | undefined {
  const wineprefix = process.env.WINEPREFIX || path.join(os.homedir(), '.wine');
  return path.join(wineprefix, 'user.reg');
}

/**
 * Parse Wine's user.reg file for Credential Manager entries.
 *
 * Wine stores credentials under registry keys like:
 *   [Software\\Wine\\Credential Manager]
 *
 * Each credential is a named value where the name is the target and the
 * value is a hex-encoded binary blob. The credential blob (the actual
 * secret) is stored as UTF-8 bytes within the binary structure.
 *
 * Returns a Map of target name -> credential value (decoded string).
 */
function parseWineCredentials(regContent: string): Map<string, string> {
  const credentials = new Map<string, string>();

  // Wine Credential Manager stores creds as individual hex blobs under
  // [Software\\Wine\\Credential Manager]. The key format is:
  //   "Target Name"=hex:xx,xx,xx,...
  // The hex blob is a serialized CREDENTIAL struct.
  const credSectionMatch = regContent.match(
    /\[Software\\\\Wine\\\\Credential Manager\]([\s\S]*?)(?=\n\[|$)/i
  );
  if (!credSectionMatch) {
    return credentials;
  }

  const section = credSectionMatch[1];

  // Match each credential entry: "TargetName"=hex:bytes
  const entryRegex = /^"(.+?)"=hex:(.+)$/gm;
  let match;
  while ((match = entryRegex.exec(section)) !== null) {
    const targetName = unescapeRegString(match[1]);
    const hexStr = match[2].replace(/\\\n\s*/g, '').replace(/,/g, '');

    try {
      const blob = Buffer.from(hexStr, 'hex');
      const value = extractCredentialBlob(blob);
      if (value) {
        credentials.set(targetName, value);
      }
    } catch {
      // Malformed hex data
    }
  }

  return credentials;
}

/**
 * Extract the credential value from a Wine serialized CREDENTIAL blob.
 *
 * The blob layout follows the Windows CREDENTIAL struct. The credential
 * value (CredentialBlob) is stored as UTF-8 bytes. We look for the
 * actual cookie/value content by searching for known patterns.
 */
function extractCredentialBlob(blob: Buffer): string | undefined {
  // Wine's serialized credential format stores the blob data inline.
  // The simplest approach: the credential value for Roblox entries is
  // plain UTF-8 text. Try to find it by looking for cookie-like content
  // or numeric user IDs.

  // Try interpreting the entire blob as UTF-8 and looking for the value
  const text = blob.toString('utf-8');

  // For simple values (user IDs, cookie names), the blob may just be
  // the raw UTF-8 string
  if (text && isPrintableAscii(text)) {
    return text;
  }

  // For structured blobs, search for the credential data section.
  // Wine writes a serialized struct — scan for the longest printable
  // ASCII substring that looks like a credential value.
  let best = '';
  let current = '';
  for (let i = 0; i < blob.length; i++) {
    const byte = blob[i];
    if (byte >= 0x20 && byte < 0x7f) {
      current += String.fromCharCode(byte);
    } else {
      if (current.length > best.length) {
        best = current;
      }
      current = '';
    }
  }
  if (current.length > best.length) {
    best = current;
  }

  return best.length > 0 ? best : undefined;
}

function isPrintableAscii(str: string): boolean {
  for (let i = 0; i < str.length; i++) {
    const code = str.charCodeAt(i);
    if (code < 0x20 || code > 0x7e) {
      return false;
    }
  }
  return str.length > 0;
}

function unescapeRegString(str: string): string {
  return str.replace(/\\\\/g, '\\');
}
