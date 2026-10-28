/**
 * Finds running Roblox Studio processes and closes them. The plugin API has
 * no process id, so a bridge session is matched to its process by the place
 * name Studio shows in the window title, or by the place id a cloud place was
 * launched with.
 */

import { execa } from 'execa';

const WINDOW_TITLE_SUFFIX = ' - Roblox Studio';
const EXIT_POLL_INTERVAL_MS = 250;

export interface RunningStudioProcess {
  pid: number;
  windowTitle: string;
  commandLine?: string;
}

export interface CloseStudioOptions {
  force?: boolean;
  exitTimeoutMs?: number;
}

export async function listStudioProcessesAsync(): Promise<
  RunningStudioProcess[]
> {
  if (process.platform === 'win32') {
    const { stdout } = await execa(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        '@(Get-CimInstance Win32_Process -Filter "Name=\'RobloxStudioBeta.exe\'" | ForEach-Object { [pscustomobject]@{ Id = $_.ProcessId; MainWindowTitle = (Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue).MainWindowTitle; CommandLine = $_.CommandLine } }) | ConvertTo-Json -Compress',
      ],
      { reject: false }
    );
    return parseWindowsProcessList(stdout);
  }

  if (process.platform === 'darwin') {
    const { stdout } = await execa('ps', ['-axo', 'pid=,command='], {
      reject: false,
    });
    return parseMacProcessList(stdout);
  }

  throw new Error(`Closing Studio is not supported on ${process.platform}`);
}

export function parseWindowsProcessList(
  stdout: string
): RunningStudioProcess[] {
  const trimmed = stdout.trim();
  if (!trimmed) return [];

  type Entry = {
    Id: number;
    MainWindowTitle: string | null;
    CommandLine?: string | null;
  };
  const parsed = JSON.parse(trimmed) as Entry | Entry[];
  const entries = Array.isArray(parsed) ? parsed : [parsed];

  return entries.map((entry) => ({
    pid: entry.Id,
    windowTitle: entry.MainWindowTitle ?? '',
    commandLine: entry.CommandLine ?? undefined,
  }));
}

export function parseMacProcessList(stdout: string): RunningStudioProcess[] {
  const processes: RunningStudioProcess[] = [];
  for (const line of stdout.split('\n')) {
    const match =
      /^\s*(\d+)\s+(.*RobloxStudio\.app\/Contents\/MacOS\/RobloxStudio.*)$/.exec(
        line
      );
    if (match) {
      processes.push({
        pid: Number(match[1]),
        windowTitle: match[2],
        commandLine: match[2],
      });
    }
  }
  return processes;
}

/**
 * Processes whose window shows the given place. Studio titles a local file
 * by its full path and a cloud place by its name.
 */
export function matchStudioProcesses(
  processes: RunningStudioProcess[],
  placeName: string,
  placeId?: number
): RunningStudioProcess[] {
  // Studio titles a cloud place by its name on the website, which the plugin can't see
  const launchedPlaceId = placeId
    ? new RegExp(`placeId:${placeId}(\\D|$)`)
    : undefined;
  return processes.filter((proc) => {
    if (
      launchedPlaceId &&
      proc.commandLine &&
      launchedPlaceId.test(proc.commandLine)
    ) {
      return true;
    }

    const title = proc.windowTitle.endsWith(WINDOW_TITLE_SUFFIX)
      ? proc.windowTitle.slice(0, -WINDOW_TITLE_SUFFIX.length)
      : proc.windowTitle;

    return (
      title === placeName ||
      title.endsWith(`\\${placeName}`) ||
      title.endsWith(`/${placeName}`)
    );
  });
}

/**
 * Close a Studio process. Without `force` Studio is asked to close its
 * window, which it can refuse by prompting to save. Resolves whether the
 * process exited within the timeout.
 */
export async function closeStudioProcessAsync(
  pid: number,
  options: CloseStudioOptions = {}
): Promise<boolean> {
  const { force = false, exitTimeoutMs = 10_000 } = options;

  if (process.platform === 'win32') {
    if (force) {
      await execa('taskkill', ['/F', '/T', '/PID', String(pid)], {
        reject: false,
      });
    } else {
      await execa(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          `(Get-Process -Id ${pid} -ErrorAction SilentlyContinue).CloseMainWindow() | Out-Null`,
        ],
        { reject: false }
      );
    }
  } else {
    try {
      process.kill(pid, force ? 'SIGKILL' : 'SIGTERM');
    } catch {
      return !isProcessRunning(pid);
    }
  }

  return waitForExitAsync(pid, exitTimeoutMs);
}

export function isProcessRunning(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch (err) {
    return (err as NodeJS.ErrnoException).code === 'EPERM';
  }
}

async function waitForExitAsync(
  pid: number,
  timeoutMs: number
): Promise<boolean> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (!isProcessRunning(pid)) return true;
    await new Promise((resolve) => setTimeout(resolve, EXIT_POLL_INTERVAL_MS));
  }
  return !isProcessRunning(pid);
}
