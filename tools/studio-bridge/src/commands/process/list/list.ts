/**
 * `process list` — list connected Studio sessions.
 */

import {
  defineCommand,
  type SessionTargeting,
} from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  formatTable,
  type TableColumn,
} from '@quenty/cli-output-helpers/reporting';
import type { BridgeConnection } from '../../../bridge/index.js';
import type { SessionInfo } from '../../../bridge/index.js';
import type { StudioState } from '../../../server/web-socket-protocol.js';
import {
  getStudioMcpSnapshotAsync,
  type StudioMcpSnapshot,
} from '../../../roblox-mcp/index.js';
import { colorizeState } from '../format-state.js';

export interface McpStudioState {
  status: StudioMcpSnapshot['status'];
  message?: string;
  latencyMs: number;
  checkedAt: string;
  lastOkAt?: string;
  settled?: boolean;
  studios: Array<{
    studioId: string;
    placeName: string;
    sessionId?: string;
    pid?: number;
  }>;
}

export interface SessionsResult {
  sessions: SessionInfo[];
  mcp?: McpStudioState;
  studiosWithoutPlugin?: McpStudioState['studios'];
  summary: string;
}

export interface ListSessionsOptions {
  mcpSnapshotAsync?: (
    sessions: SessionInfo[]
  ) => Promise<StudioMcpSnapshot | undefined>;
}

/**
 * List all connected Studio sessions with a summary message.
 */
export async function listSessionsHandlerAsync(
  connection: BridgeConnection,
  targeting: SessionTargeting = {},
  options: ListSessionsOptions = {}
): Promise<SessionsResult> {
  const sessions = connection.findSessions(targeting.target, targeting.context);
  const snapshot = await options.mcpSnapshotAsync?.(connection.listSessions());
  const mcp = snapshot ? toMcpStudioState(snapshot) : undefined;
  const filtered =
    targeting.target !== undefined || targeting.context !== undefined;
  const withoutPlugin = filtered
    ? []
    : (mcp?.studios ?? []).filter((s) => s.sessionId === undefined);

  if (sessions.length === 0) {
    let summary =
      connection.listSessions().length > 0
        ? 'No sessions match --target/--context.'
        : 'No active sessions. Is Studio running with the studio-bridge plugin?';
    if (withoutPlugin.length > 0) {
      summary = `No plugin sessions. Studio's MCP server sees ${
        withoutPlugin.length
      } Studio(s) without the studio-bridge plugin: ${withoutPlugin
        .map((s) => s.placeName)
        .join(', ')}`;
    }
    return {
      sessions: [],
      ...(mcp ? { mcp, studiosWithoutPlugin: withoutPlugin } : {}),
      summary,
    };
  }

  return {
    sessions,
    ...(mcp ? { mcp, studiosWithoutPlugin: withoutPlugin } : {}),
    summary: `${sessions.length} session(s) connected.`,
  };
}

export function toMcpStudioState(snapshot: StudioMcpSnapshot): McpStudioState {
  return {
    status: snapshot.status,
    ...(snapshot.message ? { message: snapshot.message } : {}),
    latencyMs: snapshot.latencyMs,
    checkedAt: new Date(snapshot.checkedAt).toISOString(),
    ...(snapshot.settled === false ? { settled: false } : {}),
    ...(snapshot.lastOkAt
      ? { lastOkAt: new Date(snapshot.lastOkAt).toISOString() }
      : {}),
    studios: snapshot.studios.map((s) => ({
      studioId: s.studioId,
      placeName: s.placeName,
      ...(s.sessionId ? { sessionId: s.sessionId } : {}),
      ...(s.pid !== undefined ? { pid: s.pid } : {}),
    })),
  };
}

interface ListRow {
  sessionId: string;
  context: string;
  placeName: string;
  state: string;
  mcp: string;
}

function buildColumns(withMcp: boolean): TableColumn<ListRow>[] {
  const columns: TableColumn<ListRow>[] = [
    {
      header: 'Session',
      value: (s) => s.sessionId,
      format: (v) => OutputHelper.formatHint(v),
    },
    { header: 'Context', value: (s) => s.context },
    { header: 'Place', value: (s) => s.placeName },
    {
      header: 'State',
      value: (s) => s.state,
      format: (v) => (v ? colorizeState(v as StudioState) : ''),
    },
  ];
  if (withMcp) {
    columns.push({ header: 'MCP', value: (s) => s.mcp });
  }
  return columns;
}

export function formatMcpLine(mcp: McpStudioState, now = Date.now()): string {
  const age = formatAgo(Date.parse(mcp.checkedAt), now);
  if (mcp.status === 'ok') {
    const pending =
      mcp.settled === false
        ? ' so far (Studios take a few seconds to reach a new MCP server)'
        : '';
    return `MCP: ok, ${mcp.studios.length} Studio(s)${pending}, answered in ${mcp.latencyMs}ms, checked ${age}`;
  }
  const lastOk = mcp.lastOkAt
    ? `, last ok ${formatAgo(Date.parse(mcp.lastOkAt), now)}`
    : '';
  return OutputHelper.formatWarning(
    `MCP: ${mcp.status}${
      mcp.message ? ` (${mcp.message})` : ''
    }, checked ${age}${lastOk}`
  );
}

export function formatSessionsTable(result: SessionsResult): string {
  const mcp =
    result.mcp && result.mcp.status !== 'unsupported' ? result.mcp : undefined;
  const matched = new Set(
    (mcp?.studios ?? []).map((s) => s.sessionId).filter(Boolean)
  );
  const rows: ListRow[] = result.sessions.map((s) => ({
    sessionId: s.sessionId,
    context: s.context,
    placeName: s.placeName,
    state: s.state,
    mcp:
      mcp?.status !== 'ok'
        ? '?'
        : matched.has(s.sessionId) ||
          (s.context !== 'edit' && matched.has(`${s.instanceId}-edit`))
        ? 'yes'
        : 'no',
  }));
  if (mcp) {
    for (const studio of result.studiosWithoutPlugin ?? []) {
      rows.push({
        sessionId: '(no plugin)',
        context: 'edit',
        placeName: studio.placeName || '(loading)',
        state: '',
        mcp: 'yes',
      });
    }
  }

  const lines: string[] = [];
  if (result.sessions.length === 0) {
    lines.push(result.summary);
  }
  if (rows.length > 0) {
    lines.push(formatTable(rows, buildColumns(mcp !== undefined)));
  }
  if (mcp) {
    lines.push(formatMcpLine(mcp));
  }
  return lines.join('\n');
}

function formatAgo(at: number, now: number): string {
  const seconds = Math.max(0, Math.round((now - at) / 1000));
  return seconds < 60 ? `${seconds}s ago` : `${Math.floor(seconds / 60)}m ago`;
}

interface ListArgs {
  mcp?: boolean;
}

export const listCommand = defineCommand<ListArgs, SessionsResult>({
  group: 'process',
  name: 'list',
  description:
    "List connected Studio sessions, and Studios that only Studio's MCP server sees",
  category: 'infrastructure',
  safety: 'read',
  scope: 'connection',
  coversAllSessions: true,
  args: {
    mcp: arg.flag({
      description:
        "Ask Studio's MCP server too, which also finds Studios without the plugin (--no-mcp to skip)",
      default: true,
    }),
  },
  cli: {
    format: formatSessionsTable,
  },
  handler: async (connection, args, targeting) =>
    listSessionsHandlerAsync(connection, targeting, {
      mcpSnapshotAsync: args.mcp
        ? (sessions) => getStudioMcpSnapshotAsync({ sessions })
        : undefined,
    }),
});
