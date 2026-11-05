import type { SessionContext, SessionInfo } from '../bridge/types.js';
import { listStudioProcessesAsync } from '../process/studio-process-closer.js';
import {
  McpStdioClient,
  McpTimeoutError,
  type SpawnMcpProcess,
} from './mcp/mcp-stdio-client.js';
import {
  findStudioMcpLaunchAsync,
  StudioMcpUnsupportedError,
} from './studio-mcp-locator.js';
import {
  DATAMODEL_TYPES,
  listMcpStudiosAsync,
  matchStudiosAsync,
  resolveStudio,
  StudioNotFoundError,
  type MatchedStudio,
  type McpStudio,
  type StudioWindow,
} from './studio/studio-session.js';

export type StudioMcpTarget = MatchedStudio;

export type StudioMcpFailure =
  | 'unsupported'
  | 'unavailable'
  | 'no-studio'
  | 'failed'
  | 'timeout';

export type StudioMcpResult<T> =
  | { success: true; value: T; studio?: StudioMcpTarget; settled?: boolean }
  | {
      success: false;
      reason: StudioMcpFailure;
      message: string;
      studio?: StudioMcpTarget;
    };

export interface StudioMcpOptions {
  target?: string;
  sessions?: SessionInfo[];
  timeoutMs?: number;
  executablePath?: string;
  spawnProcess?: SpawnMcpProcess;
  listWindowsAsync?: () => Promise<StudioWindow[]>;
  readPlaceIds?: boolean;
  sessionPids?: Map<string, number>;
}

export interface StudioMcpLuauOptions extends StudioMcpOptions {
  context?: SessionContext;
}

const DEFAULT_TIMEOUT_MS = 15_000;
const STEP_TIMEOUT_MS = 5_000;
const STUDIO_RECONNECT_MS = 4_000;
const RECONNECT_POLL_MS = 250;
const SETTLE_RESERVE_MS = 2_500;
const IDLE_CLOSE_MS = 15_000;

interface SharedClient {
  client: McpStdioClient;
  startedAt: number;
  key: string;
  spawnProcess?: SpawnMcpProcess;
  idleTimer?: NodeJS.Timeout;
}

let _shared: SharedClient | undefined;

export async function tryListStudiosAsync(
  options: StudioMcpOptions = {}
): Promise<StudioMcpResult<StudioMcpTarget[]>> {
  return _withMcpAsync(options, async (shared, remainingMs) => {
    const { studios, settled } = await _listSettledAsync(
      shared,
      remainingMs,
      options.sessions
    );
    return { value: await _matchAsync(shared, options, studios), settled };
  });
}

export async function tryExecuteLuauAsync(
  code: string,
  options: StudioMcpLuauOptions = {}
): Promise<StudioMcpResult<string>> {
  return tryCallStudioToolAsync('execute_luau', { code }, options);
}

export async function tryCallStudioToolAsync(
  tool: string,
  args: Record<string, unknown> = {},
  options: StudioMcpLuauOptions = {}
): Promise<StudioMcpResult<string>> {
  return _withMcpAsync(options, async (shared, remainingMs) => {
    const { studios } = await _listSettledAsync(
      shared,
      remainingMs,
      options.sessions
    );
    const studio = resolveStudio(
      await _matchAsync(shared, options, studios),
      options.target
    );
    const reply = await shared.client.callToolAsync(
      tool,
      {
        ...args,
        studio_id: studio.studioId,
        ...(options.context
          ? { datamodel_type: DATAMODEL_TYPES[options.context] }
          : tool === 'execute_luau'
          ? { datamodel_type: DATAMODEL_TYPES.edit }
          : {}),
      },
      remainingMs()
    );
    if (reply.isError) {
      throw new StudioMcpError(
        'failed',
        reply.text || `${tool} failed`,
        studio
      );
    }
    return { value: reply.text, studio };
  });
}

export async function closeStudioMcpAsync(): Promise<void> {
  const shared = _shared;
  _shared = undefined;
  if (shared) {
    clearTimeout(shared.idleTimer);
    await shared.client.closeAsync();
  }
}

class StudioMcpError extends Error {
  constructor(
    public readonly reason: StudioMcpFailure,
    message: string,
    public readonly studio?: StudioMcpTarget
  ) {
    super(message);
  }
}

async function _withMcpAsync<T>(
  options: StudioMcpOptions,
  runAsync: (
    shared: SharedClient,
    remainingMs: () => number
  ) => Promise<{ value: T; studio?: StudioMcpTarget; settled?: boolean }>
): Promise<StudioMcpResult<T>> {
  const totalMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const endsAt = Date.now() + totalMs;
  const remainingMs = () => Math.max(1, endsAt - Date.now());
  let shared: SharedClient | undefined;
  let timer: NodeJS.Timeout | undefined;

  const work = (async (): Promise<StudioMcpResult<T>> => {
    shared = await _acquireAsync(options, remainingMs);
    return { success: true, ...(await runAsync(shared, remainingMs)) };
  })();
  work.catch(() => {});

  const deadline = new Promise<never>((_, reject) => {
    timer = setTimeout(
      () =>
        reject(
          new McpTimeoutError(
            `Studio's MCP server did not finish within ${totalMs}ms`
          )
        ),
      totalMs
    );
  });

  try {
    const result = await Promise.race([work, deadline]);
    _scheduleIdleClose(shared);
    return result;
  } catch (err) {
    const failure = _toFailure(err);
    if (failure.reason === 'timeout' || failure.reason === 'unavailable') {
      await _discardAsync(shared);
    } else {
      _scheduleIdleClose(shared);
    }
    return failure;
  } finally {
    clearTimeout(timer);
  }
}

async function _acquireAsync(
  options: StudioMcpOptions,
  remainingMs: () => number
): Promise<SharedClient> {
  const key = options.executablePath ?? 'auto';
  if (
    _shared &&
    _shared.client.isRunning &&
    _shared.key === key &&
    _shared.spawnProcess === options.spawnProcess
  ) {
    clearTimeout(_shared.idleTimer);
    return _shared;
  }
  await closeStudioMcpAsync();

  try {
    const launch = options.executablePath
      ? { command: options.executablePath, args: [] }
      : await findStudioMcpLaunchAsync();
    const client = await McpStdioClient.startAsync(launch.command, {
      args: launch.args,
      env: 'env' in launch ? launch.env : undefined,
      spawnProcess: options.spawnProcess,
      requestTimeoutMs: Math.min(STEP_TIMEOUT_MS, remainingMs()),
    });
    _shared = {
      client,
      startedAt: Date.now(),
      key,
      spawnProcess: options.spawnProcess,
    };
    return _shared;
  } catch (err) {
    if (err instanceof StudioMcpUnsupportedError) {
      throw new StudioMcpError('unsupported', err.message);
    }
    throw new StudioMcpError(
      'unavailable',
      `Studio's MCP server is unavailable: ${_message(err)}`
    );
  }
}

async function _listSettledAsync(
  shared: SharedClient,
  remainingMs: () => number,
  sessions: SessionInfo[] = []
): Promise<{ studios: McpStudio[]; settled: boolean }> {
  const editSessions = sessions.filter((s) => s.context === 'edit').length;
  const isEnough = (found: McpStudio[]) =>
    found.length > 0 && found.length >= editSessions;
  const settlesAt = shared.startedAt + STUDIO_RECONNECT_MS;
  let studios = await listMcpStudiosAsync(shared.client);
  while (
    !isEnough(studios) &&
    Date.now() < settlesAt &&
    remainingMs() > SETTLE_RESERVE_MS
  ) {
    await new Promise((resolve) => setTimeout(resolve, RECONNECT_POLL_MS));
    studios = await listMcpStudiosAsync(shared.client);
  }
  return { studios, settled: isEnough(studios) || Date.now() >= settlesAt };
}

async function _matchAsync(
  shared: SharedClient,
  options: StudioMcpOptions,
  studios: McpStudio[]
): Promise<MatchedStudio[]> {
  const windows = await (options.listWindowsAsync ?? _listWindowsAsync)().catch(
    () => []
  );
  return matchStudiosAsync(shared.client, options.sessions ?? [], windows, {
    readPlaceIds: options.readPlaceIds,
    studios,
    sessionPids: options.sessionPids,
  });
}

function _scheduleIdleClose(shared: SharedClient | undefined) {
  if (!shared || shared !== _shared) {
    return;
  }
  clearTimeout(shared.idleTimer);
  shared.idleTimer = setTimeout(() => {
    if (_shared === shared) {
      void closeStudioMcpAsync();
    }
  }, IDLE_CLOSE_MS);
  shared.idleTimer.unref();
}

async function _discardAsync(shared: SharedClient | undefined) {
  if (shared && shared === _shared) {
    await closeStudioMcpAsync();
  } else {
    await shared?.client.closeAsync();
  }
}

function _toFailure(
  err: unknown
): Extract<StudioMcpResult<never>, { success: false }> {
  if (err instanceof StudioMcpError) {
    return {
      success: false,
      reason: err.reason,
      message: err.message,
      ...(err.studio ? { studio: err.studio } : {}),
    };
  }
  const message = _message(err);
  if (err instanceof McpTimeoutError) {
    return { success: false, reason: 'timeout', message };
  }
  if (err instanceof StudioNotFoundError) {
    return { success: false, reason: 'no-studio', message };
  }
  return { success: false, reason: 'unavailable', message };
}

async function _listWindowsAsync(): Promise<StudioWindow[]> {
  return (await listStudioProcessesAsync()).map(
    ({ pid, windowTitle, startedAt }) => ({ pid, windowTitle, startedAt })
  );
}

function _message(err: unknown): string {
  return err instanceof Error ? err.message : String(err);
}
