/**
 * `console logs` — retrieve buffered log history from a connected
 * Studio session's ring buffer.
 */

import {
  defineCommand,
  type ResultTable,
} from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { formatCount } from '@quenty/cli-output-helpers/reporting';
import type { BridgeConnection, BridgeSession } from '../../../bridge/index.js';
import type {
  LogEntry,
  LogsResult as BridgeLogsResult,
} from '../../../bridge/index.js';
import type { OutputLevel } from '../../../server/web-socket-protocol.js';
import { tryParseDurationSeconds } from '../../shared/duration.js';
import {
  invalidInput,
  StudioBridgeError,
} from '../../../messages/studio-bridge-error.js';

export interface LogsResult {
  /** With repeats grouped, a run of identical entries is one with `repeats` and `lastTimestamp`. */
  entries: LogEntry[];
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

/**
 * The time `--since` names, in epoch seconds: a duration back from `nowMs`
 * (`30s`, `5m`, `2h`, `1d`) or a date (`2026-10-27T18:00:00`).
 */
export function parseSince(value: string, nowMs: number = Date.now()): number {
  const durationSec = tryParseDurationSeconds(value);
  if (durationSec !== undefined) {
    return nowMs / 1000 - durationSec;
  }

  const dateMs = Date.parse(value);
  if (Number.isNaN(dateMs)) {
    throw invalidInput(
      `Can't read --since '${value}'.`,
      'Give a duration like 30s, 5m, 2h or 1d, or a date.'
    );
  }
  return dateMs / 1000;
}

const PLAYTEST_START_SCRIPT =
  'return DateTime.now().UnixTimestampMillis / 1000 - time()';
/** The server's DataModel starts running a moment after Edit starts the playtest. */
const PLAYTEST_START_SLACK_SEC = 2;

/**
 * The `--since-restart` cutoff for `session`, in epoch seconds: none for a
 * playtest's own session, whose log began with the playtest, and otherwise a
 * little before the running playtest's server started.
 */
export async function getSinceRestartCutoffAsync(
  connection: BridgeConnection,
  session: BridgeSession
): Promise<number | undefined> {
  if (session.info.context !== 'edit') {
    return undefined;
  }

  const server = connection
    .listSessions()
    .find(
      (info) =>
        info.instanceId === session.info.instanceId && info.context === 'server'
    );
  const serverSession = server && connection.getSession(server.sessionId);
  if (!serverSession) {
    throw new StudioBridgeError({
      code: 'NO_PLAYTEST',
      message: `--since-restart needs a running playtest, and '${session.info.placeName}' has none.`,
      fix: 'Use --since to read back to a time instead.',
    });
  }

  const result = await serverSession.execAsync(PLAYTEST_START_SCRIPT, 10_000);
  const startedAt = result.returnValues?.[0];
  if (!result.success || typeof startedAt !== 'number') {
    throw new StudioBridgeError({
      code: 'PLAYTEST_START_UNKNOWN',
      message:
        "Couldn't read when the playtest started, so --since-restart has no cutoff.",
      fix: 'Use --since to read back to a time instead.',
      cause: result.error ?? 'no time returned',
    });
  }
  return startedAt - PLAYTEST_START_SLACK_SEC;
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
    groupRepeats: options.groupRepeats !== false,
  });

  const entries = result.entries ?? [];
  const shown = entries.reduce((sum, e) => sum + (e.repeats ?? 1), 0);

  return {
    entries,
    total: result.total ?? 0,
    bufferCapacity: result.bufferCapacity ?? 0,
    since: options.since,
    summary: `${formatCount(shown, 'entry', 'entries')} (${(
      result.total ?? 0
    ).toLocaleString('en-US')} in buffer)`,
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
  return result.entries
    .map((e) => {
      const ts = OutputHelper.formatDim(
        new Date(e.timestamp * 1000).toLocaleTimeString()
      );
      const level = colorizeLevel(e.level);
      const repeats = e.repeats
        ? OutputHelper.formatDim(` (x${e.repeats})`)
        : '';
      return `[${ts}] [${level}] ${e.body}${repeats}`;
    })
    .join('\n');
}

export function toLogsTable(result: LogsResult): ResultTable {
  return {
    columns: ['timestamp', 'level', 'body', 'repeats'],
    rows: result.entries.map((entry) => [
      entry.timestamp,
      entry.level,
      entry.body,
      entry.repeats ?? 1,
    ]),
  };
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
    body: formatLogsText,
    rows: toLogsTable,
    output: 'data',
  },
  handler: async (session, args, connection) => {
    if (args.since && args.sinceRestart) {
      throw invalidInput(
        'Both --since and --since-restart were given.',
        'Use one of them.'
      );
    }

    const since = args.sinceRestart
      ? await getSinceRestartCutoffAsync(connection, session)
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
