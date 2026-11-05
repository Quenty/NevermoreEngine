import type { SessionContext, SessionInfo } from '../../bridge/types.js';
import type { McpStdioClient } from '../mcp/mcp-stdio-client.js';
import { matchProcessByUptime } from '../../process/studio-process-identity.js';

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
  startedAt?: number;
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

export interface MatchStudiosOptions {
  readPlaceIds?: boolean;
  studios?: McpStudio[];
  sessionPids?: Map<string, number>;
}

export async function matchStudiosAsync(
  client: McpStdioClient,
  sessions: SessionInfo[] = [],
  windows: StudioWindow[] = [],
  options: MatchStudiosOptions = {}
): Promise<MatchedStudio[]> {
  const studios = options.studios ?? (await listMcpStudiosAsync(client));
  const editSessions = sessions.filter((s) => s.context === 'edit');
  const nameCount = (name: string) =>
    studios.filter((s) => s.placeName === name).length;
  const canTime = windows.some((w) => w.startedAt !== undefined);

  const matched = await Promise.all(
    studios.map(async (studio): Promise<MatchedStudio> => {
      const named = editSessions.filter(
        (s) => s.placeName === studio.placeName
      );
      const uniqueByName =
        named.length === 1 && nameCount(studio.placeName) === 1;
      const wantProbe =
        canTime ||
        (!uniqueByName && (named.length > 0 || options.readPlaceIds !== false));
      return wantProbe
        ? {
            ...studio,
            ...(await _probeAsync(client, studio.studioId, windows)),
          }
        : { ...studio };
    })
  );

  const claimed = new Set<string>();
  const assign = (studio: MatchedStudio, session: SessionInfo) => {
    claimed.add(session.sessionId);
    studio.sessionId = session.sessionId;
    studio.instanceId = session.instanceId;
    studio.placeId ??= session.placeId;
    studio.gameId ??= session.gameId;
  };
  const unclaimed = () => editSessions.filter((s) => !claimed.has(s.sessionId));

  if (options.sessionPids) {
    for (const studio of matched) {
      if (studio.pid === undefined) continue;
      const byPid = unclaimed().filter(
        (s) => options.sessionPids!.get(s.instanceId) === studio.pid
      );
      if (byPid.length === 1) {
        assign(studio, byPid[0]);
      }
    }
  }

  for (const studio of matched) {
    if (studio.sessionId) continue;
    const named = unclaimed().filter((s) => s.placeName === studio.placeName);
    const unmatchedSameName = matched.filter(
      (m) => !m.sessionId && m.placeName === studio.placeName
    ).length;
    if (named.length === 1 && unmatchedSameName === 1) {
      assign(studio, named[0]);
    }
  }

  for (const studio of matched) {
    if (studio.sessionId || !studio.placeId) continue;
    const byId = unclaimed().filter((s) => s.placeId === studio.placeId);
    if (byId.length === 1) {
      assign(studio, byId[0]);
    }
  }

  for (const studio of matched) {
    if (studio.pid !== undefined || nameCount(studio.placeName) !== 1) continue;
    const window = windows.filter((w) =>
      _windowShowsPlace(w.windowTitle, studio.placeName)
    );
    if (window.length === 1) {
      studio.pid = window[0].pid;
    }
  }

  return matched;
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

const PROBE_LUAU =
  'return tostring(os.clock()) .. "," .. tostring(game.PlaceId) .. "," .. tostring(game.GameId)';

async function _probeAsync(
  client: McpStdioClient,
  studioId: string,
  windows: StudioWindow[]
): Promise<Partial<MatchedStudio>> {
  for (const context of ['edit', 'server', 'client'] as const) {
    const sentAt = Date.now();
    const run = await runLuauAsync(client, studioId, PROBE_LUAU, context);
    const match = run.success
      ? /^([\d.]+),(\d+),(\d+)$/.exec(run.result ?? '')
      : null;
    if (!match) {
      if (run.success || !/not available/i.test(run.error ?? '')) {
        return {};
      }
      continue;
    }
    const reading = {
      uptimeSec: Number(match[1]),
      observedAt: (sentAt + Date.now()) / 2,
    };
    const window = matchProcessByUptime(windows, reading);
    return {
      placeId: Number(match[2]),
      gameId: Number(match[3]),
      ...(window ? { pid: window.pid } : {}),
    };
  }
  return {};
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
