import type { SessionContext, SessionInfo } from '../bridge/types.js';
import { listStudioProcessesAsync } from '../process/studio-process-closer.js';
import {
  McpStdioClient,
  McpTimeoutError,
  type SpawnMcpProcess,
} from './mcp/mcp-stdio-client.js';
import { findStudioMcpPathAsync } from './studio-mcp-locator.js';
import {
  DATAMODEL_TYPES,
  matchStudiosAsync,
  resolveStudio,
  StudioNotFoundError,
  type MatchedStudio,
  type StudioWindow,
} from './studio/studio-session.js';

export type StudioMcpTarget = MatchedStudio;

export type StudioMcpFailure =
  | 'unavailable'
  | 'no-studio'
  | 'failed'
  | 'timeout';

export type StudioMcpResult<T> =
  | { success: true; value: T; studio?: StudioMcpTarget }
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
}

export interface StudioMcpLuauOptions extends StudioMcpOptions {
  context?: SessionContext;
}

const DEFAULT_TIMEOUT_MS = 15_000;
const STEP_TIMEOUT_MS = 5_000;

export async function tryListStudiosAsync(
  options: StudioMcpOptions = {}
): Promise<StudioMcpResult<StudioMcpTarget[]>> {
  return _withMcpAsync(options, async (client) => ({
    value: await _matchAsync(client, options),
  }));
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
  return _withMcpAsync(options, async (client, remainingMs) => {
    const studio = resolveStudio(
      await _matchAsync(client, options),
      options.target
    );
    const reply = await client.callToolAsync(
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
    client: McpStdioClient,
    remainingMs: () => number
  ) => Promise<{ value: T; studio?: StudioMcpTarget }>
): Promise<StudioMcpResult<T>> {
  const totalMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const endsAt = Date.now() + totalMs;
  const remainingMs = () => Math.max(1, endsAt - Date.now());
  let client: McpStdioClient | undefined;
  let timer: NodeJS.Timeout | undefined;

  const work = (async (): Promise<StudioMcpResult<T>> => {
    try {
      const executablePath =
        options.executablePath ?? (await findStudioMcpPathAsync());
      client = await McpStdioClient.startAsync(executablePath, {
        spawnProcess: options.spawnProcess,
        requestTimeoutMs: Math.min(STEP_TIMEOUT_MS, remainingMs()),
      });
    } catch (err) {
      throw new StudioMcpError(
        'unavailable',
        `Studio's MCP server is unavailable: ${_message(err)}`
      );
    }
    return { success: true, ...(await runAsync(client, remainingMs)) };
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
    return await Promise.race([work, deadline]);
  } catch (err) {
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
  } finally {
    clearTimeout(timer);
    await (client as McpStdioClient | undefined)?.closeAsync();
  }
}

async function _matchAsync(
  client: McpStdioClient,
  options: StudioMcpOptions
): Promise<MatchedStudio[]> {
  const windows = await (options.listWindowsAsync ?? _listWindowsAsync)().catch(
    () => []
  );
  return matchStudiosAsync(client, options.sessions ?? [], windows);
}

async function _listWindowsAsync(): Promise<StudioWindow[]> {
  return (await listStudioProcessesAsync()).map(({ pid, windowTitle }) => ({
    pid,
    windowTitle,
  }));
}

function _message(err: unknown): string {
  return err instanceof Error ? err.message : String(err);
}
