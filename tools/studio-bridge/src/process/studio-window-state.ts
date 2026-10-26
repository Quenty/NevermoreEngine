/**
 * Reads whether a Studio window is focused or minimized. The plugin API
 * cannot see either, so this asks the OS about the process the session's
 * place is showing in.
 */

import { execa } from 'execa';

export interface StudioWindowState {
  focused: boolean;
  minimized: boolean;
}

const WINDOW_STATE_SCRIPT = `
Add-Type -Namespace StudioBridge -Name User32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
'@
$process = Get-Process -Id $args[0] -ErrorAction Stop
$foregroundPid = [uint32]0
[void][StudioBridge.User32]::GetWindowThreadProcessId([StudioBridge.User32]::GetForegroundWindow(), [ref]$foregroundPid)
@{
  minimized = [StudioBridge.User32]::IsIconic($process.MainWindowHandle)
  focused = ($foregroundPid -eq $process.Id)
} | ConvertTo-Json -Compress
`;

/** Undefined where the OS gives no answer, including outside Windows. */
export async function tryGetStudioWindowStateAsync(
  pid: number
): Promise<StudioWindowState | undefined> {
  if (process.platform !== 'win32') return undefined;

  const { stdout, failed } = await execa(
    'powershell.exe',
    [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      `& { ${WINDOW_STATE_SCRIPT} } ${pid}`,
    ],
    { reject: false }
  );
  if (failed) return undefined;

  return parseWindowState(stdout);
}

export function parseWindowState(
  stdout: string
): StudioWindowState | undefined {
  try {
    const parsed = JSON.parse(stdout.trim()) as Partial<StudioWindowState>;
    if (
      typeof parsed.focused !== 'boolean' ||
      typeof parsed.minimized !== 'boolean'
    ) {
      return undefined;
    }
    return { focused: parsed.focused, minimized: parsed.minimized };
  } catch {
    return undefined;
  }
}
