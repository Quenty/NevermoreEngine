import type { SessionContext, SessionInfo } from '../../bridge/types.js';
import type { McpStdioClient } from '../mcp/mcp-stdio-client.js';

export const DATAMODEL_TYPES: Record<SessionContext, string> = {
  edit: 'Edit',
  client: 'Client',
  server: 'Server',
};

export class StudioNotFoundError extends Error {}

export interface McpStudio {
  studioId: string;
  placeName: string;
}

export interface StudioWindow {
  pid: number;
  windowTitle: string;
}

export interface MatchedStudio {
  studioId: string;
  placeName: string;
  placeId?: number;
  gameId?: number;
  sessionId?: string;
  instanceId?: string;
  pid?: number;
}

export interface LuauRunResult {
  success: boolean;
  result?: string;
  error?: string;
}

export async function listMcpStudiosAsync(
  client: McpStdioClient
): Promise<McpStudio[]> {
  const reply = await client.callToolAsync('list_roblox_studios');
  if (reply.isError) {
    throw new Error(`Could not list Studios over MCP: ${reply.text}`);
  }
  let parsed: { studios?: Array<{ id?: unknown; name?: unknown }> };
  try {
    parsed = JSON.parse(reply.text);
  } catch {
    throw new Error(`Unexpected Studio list from MCP: ${reply.text}`);
  }
  return (parsed.studios ?? [])
    .filter((s) => typeof s.id === 'string')
    .map((s) => ({
      studioId: s.id as string,
      placeName: typeof s.name === 'string' ? s.name : '',
    }));
}

export async function runLuauAsync(
  client: McpStdioClient,
  studioId: string,
  code: string,
  context: SessionContext = 'edit',
  timeoutMs?: number
): Promise<LuauRunResult> {
  const reply = await client.callToolAsync(
    'execute_luau',
    { studio_id: studioId, datamodel_type: DATAMODEL_TYPES[context], code },
    timeoutMs
  );
  return reply.isError
    ? { success: false, error: reply.text }
    : { success: true, result: reply.text };
}

export async function matchStudiosAsync(
  client: McpStdioClient,
  sessions: SessionInfo[] = [],
  windows: StudioWindow[] = []
): Promise<MatchedStudio[]> {
  const studios = await listMcpStudiosAsync(client);
  const editSessions = sessions.filter((s) => s.context === 'edit');
  const nameCount = (name: string) =>
    studios.filter((s) => s.placeName === name).length;

  return Promise.all(
    studios.map(async (studio) => {
      const matched: MatchedStudio = { ...studio };
      const named = editSessions.filter(
        (s) => s.placeName === studio.placeName
      );

      let session: SessionInfo | undefined;
      if (named.length === 1 && nameCount(studio.placeName) === 1) {
        session = named[0];
        matched.placeId = session.placeId;
        matched.gameId = session.gameId;
      } else {
        const ids = await _readPlaceIdsAsync(client, studio.studioId);
        Object.assign(matched, ids);
        if (ids.placeId !== undefined) {
          const byId = (named.length > 0 ? named : editSessions).filter(
            (s) =>
              s.placeId === ids.placeId &&
              (ids.placeId !== 0 || s.placeName === studio.placeName)
          );
          if (byId.length === 1) {
            session = byId[0];
          }
        }
      }
      if (session) {
        matched.sessionId = session.sessionId;
        matched.instanceId = session.instanceId;
      }

      const window = windows.filter((w) =>
        _windowShowsPlace(w.windowTitle, studio.placeName)
      );
      if (window.length === 1 && nameCount(studio.placeName) === 1) {
        matched.pid = window[0].pid;
      }
      return matched;
    })
  );
}

export function resolveStudio(
  studios: MatchedStudio[],
  target?: string
): MatchedStudio {
  if (target === undefined) {
    if (studios.length === 1) {
      return studios[0];
    }
    throw new StudioNotFoundError(
      studios.length === 0
        ? 'No Studio is connected to its MCP server'
        : `${studios.length} Studios are open (${_describe(
            studios
          )}). Pick one with --target.`
    );
  }

  const exact = studios.filter(
    (s) =>
      s.studioId === target ||
      s.sessionId === target ||
      s.instanceId === target ||
      String(s.pid) === target
  );
  if (exact.length === 1) {
    return exact[0];
  }

  const lowered = target.toLowerCase();
  const loose = studios.filter(
    (s) =>
      s.studioId.startsWith(target) ||
      s.sessionId?.startsWith(target) ||
      s.instanceId?.startsWith(target) ||
      s.placeName.toLowerCase() === lowered
  );
  if (loose.length === 1) {
    return loose[0];
  }

  throw new StudioNotFoundError(
    loose.length > 1
      ? `'${target}' matches ${loose.length} Studios (${_describe(
          loose
        )}). Use a longer id.`
      : `No Studio matches '${target}'. Open: ${_describe(studios) || 'none'}`
  );
}

async function _readPlaceIdsAsync(
  client: McpStdioClient,
  studioId: string
): Promise<{ placeId?: number; gameId?: number }> {
  const run = await runLuauAsync(
    client,
    studioId,
    'return tostring(game.PlaceId) .. "," .. tostring(game.GameId)'
  );
  const match = run.success ? /^(\d+),(\d+)$/.exec(run.result ?? '') : null;
  return match ? { placeId: Number(match[1]), gameId: Number(match[2]) } : {};
}

function _windowShowsPlace(title: string, placeName: string): boolean {
  if (!placeName) {
    return false;
  }
  const shown = title.replace(/ - Roblox Studio$/, '');
  return (
    shown === placeName ||
    shown.endsWith(`\\${placeName}`) ||
    shown.endsWith(`/${placeName}`) ||
    shown.replace(/\.rbxlx?$/, '').endsWith(placeName)
  );
}

function _describe(studios: MatchedStudio[]): string {
  return studios
    .map((s) => `${s.sessionId ?? s.studioId} '${s.placeName}'`)
    .join(', ');
}
