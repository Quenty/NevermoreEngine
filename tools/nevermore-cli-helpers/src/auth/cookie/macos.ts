import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { OutputHelper } from '@quenty/cli-output-helpers';

/**
 * Read from ~/Library/HTTPStorages/com.Roblox.RobloxStudio.binarycookies.
 * This is a binary format — we shell out to Python to parse it since Node
 * doesn't have a native binarycookies parser.
 */
function readFromHTTPStorages(): string | undefined {
  const cookiePath = path.join(
    os.homedir(),
    'Library/HTTPStorages/com.Roblox.RobloxStudio.binarycookies'
  );

  if (!fs.existsSync(cookiePath)) {
    return undefined;
  }

  const pyScript = `
import struct, sys
with open(sys.argv[1], 'rb') as f:
    data = f.read()
idx = data.find(b'_|WARNING')
if idx >= 0:
    end = data.find(b'\\x00', idx)
    if end < 0: end = len(data)
    print(data[idx:end].decode('utf-8', errors='ignore'))
`.trim();

  try {
    const result = execSync(
      `python3 -c ${JSON.stringify(pyScript)} ${JSON.stringify(cookiePath)}`,
      { encoding: 'utf-8', timeout: 5000, stdio: ['pipe', 'pipe', 'pipe'] }
    ).trim();

    if (result && result.startsWith('_|')) {
      OutputHelper.verbose('Loaded cookie from macOS HTTPStorages.');
      return result;
    }
  } catch {
    // Python parse failed
  }

  return undefined;
}

function readFromPlist(): string | undefined {
  const plistPath = path.join(
    os.homedir(),
    'Library/Preferences/com.roblox.RobloxStudioBrowser.plist'
  );

  if (!fs.existsSync(plistPath)) {
    return undefined;
  }

  try {
    const result = execSync(
      `defaults read com.roblox.RobloxStudioBrowser 2>/dev/null | grep ROBLOSECURITY`,
      { encoding: 'utf-8', timeout: 5000, stdio: ['pipe', 'pipe', 'pipe'] }
    ).trim();

    if (result) {
      const cookieMatch = result.match(/COOK::<(.+?)>/);
      if (cookieMatch) {
        OutputHelper.verbose('Loaded cookie from macOS plist.');
        return cookieMatch[1];
      }

      const valueMatch = result.match(/"([^"]*_\|[^"]*)"/);
      if (valueMatch) {
        OutputHelper.verbose('Loaded cookie from macOS plist.');
        return valueMatch[1];
      }
    }
  } catch {
    // plist read failed
  }

  return undefined;
}

export function readCookie(): string | undefined {
  return readFromHTTPStorages() ?? readFromPlist();
}
