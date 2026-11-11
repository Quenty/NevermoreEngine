/**
 * `process list` — list connected Studio sessions and the Studio processes
 * behind them.
 */

import {
  defineCommand,
  type SessionTargeting,
} from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { formatDurationMs } from '@quenty/cli-output-helpers/cli-utils';
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
import {
  listStudioProcessesAsync,
  type RunningStudioProcess,
} from '../../../process/studio-process-closer.js';
import { resolveSessionPidsAsync } from '../../../process/studio-process-identity.js';
import {
  findStudioLaunch,
  readStudioLaunchesAsync,
  type StudioLaunchRecord,
} from '../../../process/studio-launch-registry.js';
import { colorizeState } from '../format-state.js';

export interface McpStudioState {
  status: StudioMcpSnapshot['status'];
  message?: string;
  latencyMs: number;
  checkedAt: string;
  lastOkAt?: string;
  settled?: boolean;
}

export interface StudioProcessRow {
  pid?: number;
  startedAt?: string;
  windowTitle: string;
  instanceId?: string;
  mcpStudioId?: string;
  launch?: { cwd: string; opened: string; launchedAt: string };
}

export interface ListedSession extends SessionInfo {
  pid?: number;
}

export interface SessionsResult {
  sessions: ListedSession[];
  studios?: StudioProcessRow[];
  mcp?: McpStudioState;
  summary: string;
}

export interface ListSessionsOptions {
  listProcessesAsync?: () => Promise<RunningStudioProcess[]>;
  resolveSessionPidsAsync?: (
    processes: RunningStudioProcess[]
  ) => Promise<Map<string, number>>;
  readLaunchesAsync?: () => Promise<StudioLaunchRecord[]>;
  mcpSnapshotAsync?: (
    sessions: SessionInfo[],
    sessionPids: Map<string, number>,
    processes: RunningStudioProcess[] | undefined
  ) => Promise<StudioMcpSnapshot | undefined>;
  elapsedSec?: () => number;
}

/**
 * List the connected Studio sessions, and when the process list is available,
 * every Studio process with its session, MCP id and where it was launched.
 */
export async function listSessionsHandlerAsync(
  connection: BridgeConnection,
  targeting: SessionTargeting = {},
  options: ListSessionsOptions = {}
): Promise<SessionsResult> {
  const allSessions = connection.listSessions();
  const processes = await options.listProcessesAsync?.().catch(() => undefined);
  const sessionPids =
    processes && options.resolveSessionPidsAsync
      ? await options.resolveSessionPidsAsync(processes).catch(() => new Map())
      : new Map<string, number>();
  const [launches, snapshot] = await Promise.all([
    options.readLaunchesAsync?.().catch(() => []) ?? Promise.resolve([]),
    options.mcpSnapshotAsync?.(allSessions, sessionPids, processes),
  ]);

  const sessions: ListedSession[] = connection
    .findSessions(targeting.target, targeting.context)
    .map((s) => {
      const pid = sessionPids.get(s.instanceId);
      return pid !== undefined ? { ...s, pid } : s;
    });
  const studios = processes
    ? buildStudioRows(processes, sessionPids, launches, snapshot)
    : undefined;
  const mcp = snapshot ? toMcpStudioState(snapshot) : undefined;

  return {
    sessions,
    ...(studios ? { studios } : {}),
    ...(mcp ? { mcp } : {}),
    summary: describeSummary(
      sessions.length,
      allSessions.length,
      processes,
      options.elapsedSec?.()
    ),
  };
}

function buildStudioRows(
  processes: RunningStudioProcess[],
  sessionPids: Map<string, number>,
  launches: StudioLaunchRecord[],
  snapshot: StudioMcpSnapshot | undefined
): StudioProcessRow[] {
  const instanceByPid = new Map([...sessionPids].map(([id, pid]) => [pid, id]));
  const mcpStudios = snapshot?.status === 'ok' ? snapshot.studios : [];
  const shown = new Set<string>();

  const rows: StudioProcessRow[] = processes.map((proc) => {
    const instanceId = instanceByPid.get(proc.pid);
    const mcpStudio = mcpStudios.find(
      (s) =>
        s.pid === proc.pid ||
        (instanceId !== undefined && s.instanceId === instanceId)
    );
    if (mcpStudio) shown.add(mcpStudio.studioId);
    const launch = findStudioLaunch(launches, proc);
    return {
      pid: proc.pid,
      ...(proc.startedAt !== undefined
        ? { startedAt: new Date(proc.startedAt).toISOString() }
        : {}),
      windowTitle: proc.windowTitle.replace(/ - Roblox Studio$/, ''),
      ...(instanceId ? { instanceId } : {}),
      ...(mcpStudio ? { mcpStudioId: mcpStudio.studioId } : {}),
      ...(launch
        ? {
            launch: {
              cwd: launch.cwd,
              opened: launch.opened,
              launchedAt: new Date(launch.launchedAt).toISOString(),
            },
          }
        : {}),
    };
  });

  for (const studio of mcpStudios) {
    if (shown.has(studio.studioId)) continue;
    rows.push({
      windowTitle: studio.placeName || '(loading)',
      ...(studio.instanceId ? { instanceId: studio.instanceId } : {}),
      mcpStudioId: studio.studioId,
    });
  }
  return rows;
}

function describeSummary(
  matching: number,
  connected: number,
  processes: RunningStudioProcess[] | undefined,
  elapsedSec: number | undefined
): string {
  if (matching > 0) {
    return `${matching} session(s) connected.`;
  }
  if (connected > 0) {
    return 'No sessions match --target/--context.';
  }
  const waited = elapsedSec !== undefined ? ` (${elapsedSec.toFixed(1)}s)` : '';
  if (!processes) {
    return `No active sessions${waited}. Is Studio running with the studio-bridge plugin?`;
  }
  if (processes.length === 0) {
    return `No Roblox Studio processes are open${waited}.`;
  }
  return `${processes.length} Studio process(es) open, but none has the studio-bridge plugin connected${waited}. Run 'studio-bridge plugin install', and check the plugin is enabled in Studio.`;
}

export function toMcpStudioState(snapshot: StudioMcpSnapshot): McpStudioState {
  return {
    status: snapshot.status,
    ...(snapshot.message ? { message: snapshot.message } : {}),
    latencyMs: snapshot.latencyMs,
    checkedAt: new Date(snapshot.checkedAt).toISOString(),
    ...(snapshot.lastOkAt
      ? { lastOkAt: new Date(snapshot.lastOkAt).toISOString() }
      : {}),
    ...(snapshot.settled === false ? { settled: false } : {}),
  };
}

const sessionColumns: TableColumn<ListedSession>[] = [
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
    format: (v) => colorizeState(v as StudioState),
  },
  { header: 'PID', value: (s) => (s.pid !== undefined ? String(s.pid) : '') },
];

function studioColumns(
  withMcp: boolean,
  now: number
): TableColumn<StudioProcessRow>[] {
  const columns: TableColumn<StudioProcessRow>[] = [
    {
      header: 'PID',
      value: (s) => (s.pid !== undefined ? String(s.pid) : '?'),
    },
    {
      header: 'Up',
      value: (s) =>
        s.startedAt
          ? formatDurationMs(Math.max(0, now - Date.parse(s.startedAt)))
          : '',
    },
    { header: 'Window', value: (s) => s.windowTitle },
    { header: 'Plugin', value: (s) => s.instanceId ?? 'none' },
  ];
  if (withMcp) {
    columns.push({
      header: 'MCP',
      value: (s) => (s.mcpStudioId ? s.mcpStudioId.slice(0, 8) : 'none'),
    });
  }
  columns.push({
    header: 'Launched',
    value: (s) =>
      s.launch
        ? `${s.launch.opened} from ${s.launch.cwd}`
        : 'not by studio-bridge',
  });
  return columns;
}

export function formatMcpLine(mcp: McpStudioState, now = Date.now()): string {
  const age = formatAgo(Date.parse(mcp.checkedAt), now);
  if (mcp.status === 'ok') {
    const pending =
      mcp.settled === false
        ? ', may be incomplete (Studios take a few seconds to reach a new MCP server)'
        : '';
    return `MCP: ok, answered in ${mcp.latencyMs}ms, checked ${age}${pending}`;
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

export function formatSessionsTable(
  result: SessionsResult,
  now = Date.now()
): string {
  const mcp =
    result.mcp && result.mcp.status !== 'unsupported' ? result.mcp : undefined;
  const lines: string[] = [];
  if (result.sessions.length > 0) {
    lines.push(formatTable(result.sessions, sessionColumns));
  } else {
    lines.push(result.summary);
  }
  if (result.studios && result.studios.length > 0) {
    lines.push('');
    lines.push(
      formatTable(result.studios, studioColumns(mcp?.status === 'ok', now))
    );
  }
  if (mcp) {
    lines.push(formatMcpLine(mcp, now));
  }
  return lines.join('\n');
}

function formatAgo(at: number, now: number): string {
  return `${formatDurationMs(Math.max(0, now - at))} ago`;
}

interface ListArgs {
  mcp?: boolean;
}

export const listCommand = defineCommand<ListArgs, SessionsResult>({
  group: 'process',
  name: 'list',
  description:
    'List connected Studio sessions and every Studio process, with where each was launched',
  category: 'infrastructure',
  safety: 'read',
  scope: 'connection',
  coversAllSessions: true,
  args: {
    mcp: arg.flag({
      description:
        "Ask Studio's MCP server too, which also reaches Studios without the plugin (--no-mcp to skip)",
      default: true,
    }),
  },
  cli: {
    format: formatSessionsTable,
  },
  handler: async (connection, args, targeting) =>
    listSessionsHandlerAsync(
      connection,
      targeting,
      connection.isRemote
        ? { elapsedSec: () => process.uptime() }
        : {
            listProcessesAsync: listStudioProcessesAsync,
            resolveSessionPidsAsync: (processes) =>
              resolveSessionPidsAsync(connection, processes),
            readLaunchesAsync: () => readStudioLaunchesAsync(),
            mcpSnapshotAsync: args.mcp
              ? (sessions, sessionPids, processes) =>
                  getStudioMcpSnapshotAsync({
                    sessions,
                    sessionPids,
                    windows: processes,
                  })
              : undefined,
            elapsedSec: () => process.uptime(),
          }
    ),
});
