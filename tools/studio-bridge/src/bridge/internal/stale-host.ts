import { spawn } from 'child_process';
import * as path from 'path';
import { fileURLToPath } from 'url';
import { execa } from 'execa';
import semverGt from 'semver/functions/gt.js';
import semverLt from 'semver/functions/lt.js';
import semverValid from 'semver/functions/valid.js';
import type { HostInfo } from './host-protocol.js';
import type { HostBuild } from './host-build.js';
import { checkHealthAsync } from './health-endpoint.js';

export interface StaleHostReport {
  replaced: boolean;
  message: string;
  fix?: string;
  cause?: string;
}

export interface StaleHostProcess {
  pid: number;
  argv: string[];
  cwd?: string;
  inUse: boolean;
}

/** What a client should do about the host it connected to. */
export type HostVerdict =
  | { action: 'current' }
  | { action: 'replace' }
  | { action: 'warn'; reason: 'unreadable' | 'other-install' };

export function assessHost(
  host: HostInfo | undefined,
  ours: HostBuild
): HostVerdict {
  if (!host) return { action: 'replace' };
  if (host.build && host.build === ours.build) return { action: 'current' };

  const theirs = semverValid(host.version);
  const mine = semverValid(ours.version);
  if (!theirs || !mine) {
    return { action: 'warn', reason: 'unreadable' };
  }
  if (semverGt(theirs, mine)) return { action: 'current' };
  if (semverLt(theirs, mine)) return { action: 'replace' };

  if (!host.build || !ours.build) {
    return { action: 'warn', reason: 'unreadable' };
  }
  if (
    host.packagePath &&
    ours.packagePath &&
    isSamePath(host.packagePath, ours.packagePath)
  ) {
    return { action: 'replace' };
  }
  return { action: 'warn', reason: 'other-install' };
}

function isSamePath(a: string, b: string): boolean {
  const normalize = (p: string) => {
    const resolved = path.resolve(p);
    return process.platform === 'win32' ? resolved.toLowerCase() : resolved;
  };
  return normalize(a) === normalize(b);
}

export function describeHostBuild(
  host: Pick<HostInfo, 'version' | 'build'> | undefined
): string {
  if (!host) return 'an older studio-bridge';
  return `${host.version} build ${host.build?.slice(0, 6) ?? 'unknown'}`;
}

export function isServeArgv(argv: string[]): boolean {
  return argv.find((arg) => !arg.startsWith('-')) === 'serve';
}

export function argvDependsOnCwd(argv: string[]): boolean {
  const serve = argv.indexOf('serve');
  let expectsValue = false;
  for (const arg of argv.slice(serve + 1)) {
    if (arg.startsWith('-')) {
      const eq = arg.indexOf('=');
      if (eq !== -1 && looksLikePath(arg.slice(eq + 1))) return true;
      expectsValue = eq === -1;
      continue;
    }
    if (!expectsValue || looksLikePath(arg)) return true;
    expectsValue = false;
  }
  return false;
}

function looksLikePath(value: string): boolean {
  return (
    /[\\/]/.test(value) ||
    /^(\.{1,2}|~)$/.test(value) ||
    (/\.[a-z][a-z0-9]*$/i.test(value) && !/^[\d.]+$/.test(value))
  );
}

export function staleHostFromInfo(host: HostInfo): StaleHostProcess {
  return {
    pid: host.pid,
    argv: host.argv,
    cwd: host.cwd,
    inUse: host.clients > 1 || host.pendingRelays > 0,
  };
}

export async function tryFindLegacyHostAsync(
  port: number
): Promise<StaleHostProcess | undefined> {
  try {
    const found =
      process.platform === 'win32'
        ? await findListenerWindowsAsync(port)
        : await findListenerPosixAsync(port);
    if (!found) return undefined;

    const argv = parseStudioBridgeArgv(found.commandLine);
    if (!argv) return undefined;
    const others = found.clientPids.filter(
      (pid) => pid !== found.pid && pid !== process.pid
    );
    return { pid: found.pid, argv, inUse: others.length > 0 };
  } catch {
    return undefined;
  }
}

interface PortListener {
  pid: number;
  commandLine: string;
  clientPids: number[];
}

async function findListenerWindowsAsync(
  port: number
): Promise<PortListener | undefined> {
  const script = [
    `$l = Get-NetTCPConnection -LocalPort ${port} -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1`,
    'if (-not $l) { exit }',
    '$p = $l.OwningProcess',
    `$c = @(Get-NetTCPConnection -RemotePort ${port} -State Established -ErrorAction SilentlyContinue | ForEach-Object { $_.OwningProcess } | Sort-Object -Unique | Where-Object { (Get-Process -Id $_ -ErrorAction SilentlyContinue).ProcessName -notmatch 'RobloxStudio' })`,
    '[pscustomobject]@{ Pid = $p; CommandLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$p").CommandLine; Clients = $c } | ConvertTo-Json -Compress',
  ].join('; ');
  const { stdout } = await execa(
    'powershell.exe',
    ['-NoProfile', '-NonInteractive', '-Command', script],
    { reject: false, timeout: 10_000 }
  );
  if (!stdout.trim()) return undefined;
  const parsed = JSON.parse(stdout) as {
    Pid: number;
    CommandLine: string | null;
    Clients: number[] | number | null;
  };
  const clients = parsed.Clients ?? [];
  return {
    pid: parsed.Pid,
    commandLine: parsed.CommandLine ?? '',
    clientPids: Array.isArray(clients) ? clients : [clients],
  };
}

async function findListenerPosixAsync(
  port: number
): Promise<PortListener | undefined> {
  const listen = await execa(
    'lsof',
    ['-nP', `-iTCP:${port}`, '-sTCP:LISTEN', '-t'],
    { reject: false }
  );
  const pid = parseInt(listen.stdout.trim().split('\n')[0], 10);
  if (!pid) return undefined;

  const ps = await execa('ps', ['-o', 'command=', '-p', String(pid)], {
    reject: false,
  });
  const established = await execa(
    'lsof',
    ['-nP', `-iTCP:${port}`, '-sTCP:ESTABLISHED', '-Fpc'],
    { reject: false }
  );
  const clientPids: number[] = [];
  let current: number | undefined;
  for (const line of established.stdout.split('\n')) {
    if (line.startsWith('p')) current = parseInt(line.slice(1), 10);
    if (line.startsWith('c') && current && !/roblox|wine/i.test(line)) {
      clientPids.push(current);
    }
  }
  return { pid, commandLine: ps.stdout.trim(), clientPids };
}

export function parseStudioBridgeArgv(
  commandLine: string
): string[] | undefined {
  const tokens = [...commandLine.matchAll(/"([^"]*)"|(\S+)/g)].map(
    (match) => match[1] ?? match[2]
  );
  const script = tokens.findIndex((token) =>
    /studio-bridge[\\/].*cli\.js$|[\\/]studio-bridge(\.cmd)?$/i.test(token)
  );
  return script === -1 ? undefined : tokens.slice(script + 1);
}

export interface ReplaceHostDeps {
  kill: (pid: number) => void;
  startServe: (argv: string[], cwd: string) => Promise<number | undefined>;
  isHealthyAsync: (port: number) => Promise<boolean>;
  delay: (ms: number) => Promise<void>;
}

const defaultReplaceDeps: ReplaceHostDeps = {
  kill: (pid) => process.kill(pid),
  startServe: startServeInBackgroundAsync,
  isHealthyAsync: async (port) => (await checkHealthAsync(port)) !== null,
  delay: (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
};

const PORT_WAIT_MS = 10_000;
const PORT_POLL_MS = 200;

export async function replaceHostAsync(
  port: number,
  stale: StaleHostProcess,
  overrides: Partial<ReplaceHostDeps> = {}
): Promise<number | undefined> {
  const deps = { ...defaultReplaceDeps, ...overrides };
  deps.kill(stale.pid);
  if (
    !(await waitForAsync(async () => !(await deps.isHealthyAsync(port)), deps))
  ) {
    throw new Error(`The old bridge host (pid ${stale.pid}) did not stop`);
  }

  const pid = await deps.startServe(stale.argv, stale.cwd ?? process.cwd());
  if (!(await waitForAsync(() => deps.isHealthyAsync(port), deps))) {
    throw new Error(
      `The new bridge host did not start; run 'studio-bridge ${stale.argv.join(
        ' '
      )}' yourself`
    );
  }
  return pid;
}

async function waitForAsync(
  condition: () => Promise<boolean>,
  deps: ReplaceHostDeps
): Promise<boolean> {
  for (let waited = 0; waited <= PORT_WAIT_MS; waited += PORT_POLL_MS) {
    if (await condition()) return true;
    await deps.delay(PORT_POLL_MS);
  }
  return false;
}

export type BackgroundStartFailure = 'powershell-failed' | 'no-pid';

export class BackgroundStartError extends Error {
  constructor(
    public readonly failure: BackgroundStartFailure,
    message: string,
    options?: { cause?: unknown }
  ) {
    super(message, options);
    this.name = 'BackgroundStartError';
  }
}

export interface BackgroundLauncher {
  powershell: string;
}

const DEFAULT_LAUNCHER: BackgroundLauncher = { powershell: 'powershell.exe' };

export async function startServeInBackgroundAsync(
  argv: string[],
  cwd: string,
  launcher: BackgroundLauncher = DEFAULT_LAUNCHER
): Promise<number | undefined> {
  const cliPath = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    '..',
    '..',
    'cli',
    'cli.js'
  );

  if (process.platform === 'win32') {
    return startOutsideParentJobOnWindowsAsync(
      [process.execPath, cliPath, ...argv],
      cwd,
      launcher
    );
  }

  const child = spawn(process.execPath, [cliPath, ...argv], {
    cwd,
    detached: true,
    stdio: 'ignore',
  });
  child.unref();
  return child.pid;
}

async function startOutsideParentJobOnWindowsAsync(
  command: string[],
  cwd: string,
  launcher: BackgroundLauncher
): Promise<number> {
  const commandLine = command
    .map((arg) => `"${arg.replace(/"/g, '\\"')}"`)
    .join(' ');
  const result = await execa(
    launcher.powershell,
    [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      '$s = New-CimInstance -ClassName Win32_ProcessStartup -ClientOnly -Property @{ ShowWindow = [uint16]0 }; (Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $env:STUDIO_BRIDGE_SERVE_COMMAND; CurrentDirectory = $env:STUDIO_BRIDGE_SERVE_CWD; ProcessStartupInformation = $s }).ProcessId',
    ],
    {
      env: {
        STUDIO_BRIDGE_SERVE_COMMAND: commandLine,
        STUDIO_BRIDGE_SERVE_CWD: cwd,
      },
      timeout: 15_000,
      reject: false,
    }
  );
  if (result.failed) {
    throw new BackgroundStartError(
      'powershell-failed',
      `${launcher.powershell} failed: ${result.shortMessage}`,
      { cause: result.stderr || undefined }
    );
  }
  const pid = parseInt(result.stdout.trim(), 10);
  if (!pid) {
    throw new BackgroundStartError(
      'no-pid',
      `Win32_Process.Create returned no process id: ${
        result.stdout.trim() || result.stderr.trim() || '(no output)'
      }`
    );
  }
  return pid;
}
