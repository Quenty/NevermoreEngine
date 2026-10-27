/**
 * `console logs` — retrieve buffered log history from a connected
 * Studio session's ring buffer.
 */

import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { BridgeConnection, BridgeSession } from '../../../bridge/index.js';
import type {
  LogEntry,
  LogsResult as BridgeLogsResult,
} from '../../../bridge/index.js';
import type { OutputLevel } from '../../../server/web-socket-protocol.js';

/** A log entry, or a run of identical consecutive entries collapsed into one. */
export interface LogsEntry extends LogEntry {
  /** How many times the entry repeated in a row. Absent when it did not. */
  repeats?: number;
}

export interface LogsResult {
  entries: LogsEntry[];
  total: number;
  bufferCapacity: number;
  /** The cutoff `--since` or `--since-restart` applied, in epoch seconds. */
  since?: number;
  summary: string;
}

export interface LogsOptions {
  count?: number;
  direction?: 'head' | 'tail';
  levels?: OutputLevel[];
  includeInternal?: boolean;
  /** Only entries logged at or after this time, in epoch seconds. */
  since?: number;
  /** Collapse identical consecutive entries. Defaults to true. */
  groupRepeats?: boolean;
}

interface ConsoleLogsArgs {
  count?: number;
  direction?: 'head' | 'tail';
  levels?: OutputLevel[];
  includeInternal?: boolean;
  since?: string;
  sinceRestart?: boolean;
  groupRepeats?: boolean;
}

const DURATION_UNITS_SEC: Record<string, number> = {
  s: 1,
  m: 60,
  h: 3600,
  d: 86400,
};

/**
 * The time `--since` names, in epoch seconds: a duration back from `nowMs`
 * (`30s`, `5m`, `2h`, `1d`) or a date (`2026-10-27T18:00:00`).
 */
export function parseSince(value: string, nowMs: number = Date.now()): number {
  const duration = /^(\d+(?:\.\d+)?)([smhd])$/.exec(value.trim());
  if (duration) {
    return nowMs / 1000 - Number(duration[1]) * DURATION_UNITS_SEC[duration[2]];
  }

  const dateMs = Date.parse(value);
  if (Number.isNaN(dateMs)) {
    throw new Error(
      `Can't read --since '${value}'. Use a duration like 30s, 5m, 2h or 1d, or a date.`
    );
  }
  return dateMs / 1000;
}

const PLAYTEST_START_SCRIPT =
  'return DateTime.now().UnixTimestampMillis / 1000 - time()';

/**
 * When the playtest running in `session`'s Studio started, in epoch seconds,
 * read from its server session.
 */
export async function getPlaytestStartAsync(
  connection: BridgeConnection,
  session: BridgeSession
): Promise<number> {
  const server = connection
    .listSessions()
    .find(
      (info) =>
        info.instanceId === session.info.instanceId && info.context === 'server'
    );
  const serverSession = server && connection.getSession(server.sessionId);
  if (!serverSession) {
    throw new Error(
      `--since-restart needs a running playtest, and '${session.info.instanceId}' has none`
    );
  }

  const result = await serverSession.execAsync(PLAYTEST_START_SCRIPT, 10_000);
  const startedAt = result.returnValues?.[0];
  if (!result.success || typeof startedAt !== 'number') {
    throw new Error(
      `Could not read when the playtest started: ${
        result.error ?? 'no time returned'
      }`
    );
  }
  return startedAt;
}

/** Collapse runs of entries with the same level and body into one. */
export function groupRepeats(entries: LogEntry[]): LogsEntry[] {
  const grouped: LogsEntry[] = [];
  for (const entry of entries) {
    const last = grouped[grouped.length - 1];
    if (last && last.level === entry.level && last.body === entry.body) {
      last.repeats = (last.repeats ?? 1) + 1;
    } else {
      grouped.push({ ...entry });
    }
  }
  return grouped;
}

export async function queryLogsHandlerAsync(
  session: BridgeSession,
  options: LogsOptions = {}
): Promise<LogsResult> {
  const result: BridgeLogsResult = await session.queryLogsAsync({
    count: options.count ?? 50,
    direction: options.direction ?? 'tail',
    levels: options.levels,
    includeInternal: options.includeInternal,
    since: options.since,
  });

  const rawEntries = result.entries ?? [];
  const entries =
    options.groupRepeats === false ? rawEntries : groupRepeats(rawEntries);

  return {
    entries,
    total: result.total ?? 0,
    bufferCapacity: result.bufferCapacity ?? 0,
    since: options.since,
    summary: `${rawEntries.length} entries (${result.total ?? 0} in buffer)`,
  };
}

function colorizeLevel(level: OutputLevel): string {
  switch (level) {
    case 'Error':
      return OutputHelper.formatError(level);
    case 'Warning':
      return OutputHelper.formatWarning(level);
    default:
      return level;
  }
}

export function formatLogsText(result: LogsResult): string {
  if (result.entries.length === 0) return result.summary;
  const lines = result.entries.map((e) => {
    const ts = OutputHelper.formatDim(
      new Date(e.timestamp * 1000).toLocaleTimeString()
    );
    const level = colorizeLevel(e.level);
    const repeats = e.repeats ? OutputHelper.formatDim(` (x${e.repeats})`) : '';
    return `[${ts}] [${level}] ${e.body}${repeats}`;
  });
  const shown = result.entries.reduce((sum, e) => sum + (e.repeats ?? 1), 0);
  lines.push(
    OutputHelper.formatDim(`(${shown} shown, ${result.total} in buffer)`)
  );
  return lines.join('\n');
}

export const logsCommand = defineCommand<ConsoleLogsArgs, LogsResult>({
  group: 'console',
  name: 'logs',
  description: 'Retrieve buffered log history from Studio',
  category: 'execution',
  safety: 'read',
  scope: 'session',
  args: {
    count: arg.option({
      description: 'Number of log entries to return',
      type: 'number',
      alias: 'n',
    }),
    direction: arg.option({
      description: 'Read from head (oldest) or tail (newest)',
      choices: ['head', 'tail'] as const,
    }),
    levels: arg.option({
      description: 'Filter by output level',
      array: true,
      choices: ['Print', 'Info', 'Warning', 'Error'] as const,
    }),
    includeInternal: arg.flag({
      description: 'Include internal/system log messages',
    }),
    since: arg.option({
      description:
        'Only entries logged since a duration ago (30s, 5m, 2h, 1d) or a date',
    }),
    sinceRestart: arg.flag({
      description: 'Only entries logged since the running playtest started',
    }),
    groupRepeats: arg.flag({
      description:
        'Collapse identical consecutive entries into one with a repeat count (--no-group-repeats to keep them)',
      default: true,
    }),
  },
  cli: {
    format: formatLogsText,
  },
  handler: async (session, args, connection) => {
    if (args.since && args.sinceRestart) {
      throw new Error('Use either --since or --since-restart, not both');
    }

    const since = args.sinceRestart
      ? await getPlaytestStartAsync(connection, session)
      : args.since
      ? parseSince(args.since)
      : undefined;

    return queryLogsHandlerAsync(session, {
      count: args.count,
      direction: args.direction,
      levels: args.levels,
      includeInternal: args.includeInternal,
      since,
      groupRepeats: args.groupRepeats,
    });
  },
});
