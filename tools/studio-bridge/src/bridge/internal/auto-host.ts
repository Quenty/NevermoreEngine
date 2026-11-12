import * as fs from 'fs/promises';
import { existsSync } from 'fs';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { isCI } from '@quenty/cli-output-helpers/cli-utils';
import { getStateDir } from '../../state-dir.js';
import { checkHealthAsync } from './health-endpoint.js';
import {
  BackgroundStartError,
  startServeInBackgroundAsync,
} from './stale-host.js';
import {
  ONE_DAY_MS,
  warnUser,
  type UserWarning,
} from '../../messages/warn-user.js';

export const AUTO_HOST_IDLE_TIMEOUT = '10m';

const START_WAIT_MS = 15_000;
const START_POLL_MS = 100;

export function shouldAutoStartHost(
  flag: boolean | undefined,
  env: NodeJS.ProcessEnv = process.env
): boolean {
  if (flag === false || isCI()) return false;
  const optOut = env.STUDIO_BRIDGE_NO_AUTOHOST;
  return !optOut || optOut === '0' || optOut.toLowerCase() === 'false';
}

export function getHostLogPath(port: number): string {
  return path.join(getStateDir(), `host-${port}.log`);
}

export function getAutoHostArgv(port: number): string[] {
  return [
    'serve',
    '--port',
    String(port),
    '--idle-timeout',
    AUTO_HOST_IDLE_TIMEOUT,
    '--auto-started',
  ];
}

export interface AutoStartDeps {
  startServe: (argv: string[], cwd: string) => Promise<number | undefined>;
  isHealthyAsync: (port: number) => Promise<boolean>;
  delay: (ms: number) => Promise<void>;
}

const defaultDeps: AutoStartDeps = {
  startServe: startServeInBackgroundAsync,
  isHealthyAsync: async (port) => (await checkHealthAsync(port)) !== null,
  delay: (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
};

export async function autoStartHostAsync(
  port: number,
  overrides: Partial<AutoStartDeps> = {}
): Promise<number | undefined> {
  const deps = { ...defaultDeps, ...overrides };
  const cwd = getStateDir();
  await fs.mkdir(cwd, { recursive: true });

  const pid = await deps.startServe(getAutoHostArgv(port), cwd);
  for (let waited = 0; waited <= START_WAIT_MS; waited += START_POLL_MS) {
    if (await deps.isHealthyAsync(port)) {
      return pid;
    }
    await deps.delay(START_POLL_MS);
  }
  throw new HostNotListeningError(port);
}

export class HostNotListeningError extends Error {
  constructor(public readonly port: number) {
    super(
      `The background bridge host did not answer on port ${port} within ${
        START_WAIT_MS / 1000
      }s`
    );
    this.name = 'HostNotListeningError';
  }
}

export async function tryAutoStartHostAsync(
  port: number,
  overrides: Partial<AutoStartDeps> = {}
): Promise<boolean> {
  try {
    const startedAt = Date.now();
    const pid = await autoStartHostAsync(port, overrides);
    OutputHelper.verbose(
      `[bridge] Started a background bridge host (pid ${pid ?? '?'}) in ${
        Date.now() - startedAt
      }ms, logging to ${getHostLogPath(port)}`
    );
    return true;
  } catch (err) {
    warnUser(describeAutoHostFailure(err, getHostLogPath(port)));
    return false;
  }
}

export function describeAutoHostFailure(
  err: unknown,
  logPath: string,
  logExists: (filePath: string) => boolean = existsSync
): UserWarning {
  const why =
    err instanceof BackgroundStartError
      ? err.failure === 'powershell-failed'
        ? 'PowerShell failed to run'
        : "Windows didn't start it"
      : err instanceof HostNotListeningError
      ? 'it started but never answered'
      : 'it failed to launch';
  return {
    code: 'AUTO_HOST_FAILED',
    message: `Couldn't start a background bridge host (${why}), so each command hosts the bridge itself and takes a few seconds longer.`,
    fix:
      err instanceof HostNotListeningError
        ? "Run 'studio-bridge serve' in another terminal to see why it fails."
        : "Run 'studio-bridge serve' in another terminal instead.",
    cause:
      err instanceof HostNotListeningError && logExists(logPath)
        ? new Error(`${err.message}; its log is ${logPath}`, { cause: err })
        : err,
    oncePerMs: ONE_DAY_MS,
  };
}
