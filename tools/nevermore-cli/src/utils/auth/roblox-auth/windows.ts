import { execSync } from 'child_process';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { COOKIE_NAME, parseStudioCookieValue } from './cookie-parser.js';

/**
 * Read a generic credential from Windows Credential Manager via CredRead.
 * The blob is decoded as UTF-8 (matching Mantle's wincred.rs).
 */
function winCredRead(target: string): string | undefined {
  const escapedTarget = target.replace(/'/g, "''");
  const script = [
    `Add-Type -TypeDefinition '`,
    `using System; using System.Runtime.InteropServices; using System.Text;`,
    `public class NevCred {`,
    `  [DllImport("advapi32.dll",SetLastError=true,CharSet=CharSet.Unicode)]`,
    `  public static extern bool CredRead(string t,int ty,int f,out IntPtr c);`,
    `  [DllImport("advapi32.dll",SetLastError=true)]`,
    `  public static extern bool CredFree(IntPtr c);`,
    `  [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)]`,
    `  public struct CRED { public int F; public int T; public string TN; public string Co;`,
    `    public System.Runtime.InteropServices.ComTypes.FILETIME LW;`,
    `    public int CBS; public IntPtr CB; public int P; public int AC; public IntPtr At;`,
    `    public string TA; public string UN; }`,
    `  public static string Read(string t) {`,
    `    IntPtr p; if(!CredRead(t,1,0,out p)) return null;`,
    `    try { CRED c=(CRED)Marshal.PtrToStructure(p,typeof(CRED));`,
    `      if(c.CBS<=0) return "";`,
    `      byte[] b=new byte[c.CBS]; Marshal.Copy(c.CB,b,0,c.CBS);`,
    `      return Encoding.UTF8.GetString(b);`,
    `    } finally { CredFree(p); } } }`,
    `'; [NevCred]::Read('${escapedTarget}')`,
  ].join(' ');

  try {
    const result = execSync(
      `powershell -NoProfile -ExecutionPolicy Bypass -Command "${script.replace(/"/g, '\\"')}"`,
      { encoding: 'utf-8', timeout: 10000, stdio: ['pipe', 'pipe', 'pipe'] }
    ).trim();
    return result.length > 0 ? result : undefined;
  } catch {
    return undefined;
  }
}

function readFromRegistry(): string | undefined {
  try {
    const script =
      `(Get-ItemProperty -Path 'HKCU:\\Software\\Roblox\\RobloxStudioBrowser\\roblox.com' -Name '${COOKIE_NAME}' -ErrorAction SilentlyContinue).'${COOKIE_NAME}'`;
    const result = execSync(
      `powershell -NoProfile -ExecutionPolicy Bypass -Command "${script}"`,
      { encoding: 'utf-8', timeout: 5000, stdio: ['pipe', 'pipe', 'pipe'] }
    ).trim();

    if (result && result.length > 10) {
      const parsed = parseStudioCookieValue(result);
      if (parsed) {
        OutputHelper.info('Loaded cookie from Windows Registry.');
        return parsed;
      }
    }
  } catch {
    // Registry read failed
  }

  return undefined;
}

export function readCookie(): string | undefined {
  // Modern Studio: user-specific credential
  const userId = winCredRead('https://www.roblox.com:RobloxStudioAuthuserid');
  if (userId) {
    const cookie = winCredRead(
      `https://www.roblox.com:RobloxStudioAuth${COOKIE_NAME}${userId}`
    );
    if (cookie) {
      OutputHelper.info(`Loaded cookie from Windows Credentials (user ${userId}).`);
      return cookie;
    }
  }

  // Legacy credential (no user ID suffix)
  const legacyCookie = winCredRead(
    `https://www.roblox.com:RobloxStudioAuth${COOKIE_NAME}`
  );
  if (legacyCookie) {
    OutputHelper.info('Loaded cookie from Windows Credentials (legacy).');
    return legacyCookie;
  }

  // Oldest fallback: Windows Registry
  return readFromRegistry();
}
