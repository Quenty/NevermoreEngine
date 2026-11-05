import type { SessionInfo } from '../bridge/types.js';
import type { StudioWindow } from './studio/studio-session.js';
import {
  tryListStudiosAsync,
  type StudioMcpFailure,
  type StudioMcpOptions,
  type StudioMcpResult,
  type StudioMcpTarget,
} from './roblox-studio-mcp.js';

export interface StudioMcpSnapshot {
  status: 'ok' | StudioMcpFailure;
  studios: StudioMcpTarget[];
  message?: string;
  checkedAt: number;
  latencyMs: number;
  lastOkAt?: number;
  settled?: boolean;
}

export interface StudioMcpSnapshotOptions {
  sessions?: SessionInfo[];
  sessionPids?: Map<string, number>;
  windows?: StudioWindow[];
  maxWaitMs?: number;
  maxAgeMs?: number;
  listAsync?: (
    options: StudioMcpOptions
  ) => Promise<StudioMcpResult<StudioMcpTarget[]>>;
}

const DEFAULT_MAX_WAIT_MS = 3000;
const DEFAULT_MAX_AGE_MS = 5000;

let _cached: StudioMcpSnapshot | undefined;
let _inFlight: Promise<StudioMcpSnapshot> | undefined;

export async function getStudioMcpSnapshotAsync(
  options: StudioMcpSnapshotOptions = {}
): Promise<StudioMcpSnapshot | undefined> {
  const maxWaitMs = options.maxWaitMs ?? DEFAULT_MAX_WAIT_MS;
  const maxAgeMs = options.maxAgeMs ?? DEFAULT_MAX_AGE_MS;
  if (_cached && Date.now() - _cached.checkedAt < maxAgeMs) {
    return _cached;
  }

  _inFlight ??= _refreshAsync(options, maxWaitMs).finally(() => {
    _inFlight = undefined;
  });
  if (_cached) {
    return _cached;
  }

  let timer: NodeJS.Timeout | undefined;
  const gaveUp = new Promise<undefined>((resolve) => {
    timer = setTimeout(() => resolve(undefined), maxWaitMs + 250);
  });
  try {
    return await Promise.race([_inFlight, gaveUp]);
  } finally {
    clearTimeout(timer);
  }
}

export function resetStudioMcpSnapshot(): void {
  _cached = undefined;
  _inFlight = undefined;
}

async function _refreshAsync(
  options: StudioMcpSnapshotOptions,
  timeoutMs: number
): Promise<StudioMcpSnapshot> {
  const startedAt = Date.now();
  const result = await (options.listAsync ?? tryListStudiosAsync)({
    sessions: options.sessions,
    sessionPids: options.sessionPids,
    ...(options.windows
      ? { listWindowsAsync: async () => options.windows! }
      : {}),
    timeoutMs,
    readPlaceIds: false,
  });
  const checkedAt = Date.now();
  const snapshot: StudioMcpSnapshot = result.success
    ? {
        status: 'ok',
        studios: result.value,
        settled: result.settled !== false,
        checkedAt,
        latencyMs: checkedAt - startedAt,
        lastOkAt: checkedAt,
      }
    : {
        status: result.reason,
        studios: [],
        message: result.message,
        checkedAt,
        latencyMs: checkedAt - startedAt,
        lastOkAt: _cached?.lastOkAt,
      };
  _cached = snapshot;
  return snapshot;
}
