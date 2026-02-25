/**
 * `console logs` — retrieve buffered log history from a connected
 * Studio session's ring buffer.
 */

import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import type { BridgeSession } from '../../../bridge/index.js';
import type { LogEntry, LogsResult as BridgeLogsResult } from '../../../bridge/index.js';
import type { OutputLevel } from '../../../server/web-socket-protocol.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface LogsResult {
  entries: LogEntry[];
  total: number;
  bufferCapacity: number;
  summary: string;
}

export interface LogsOptions {
  count?: number;
  direction?: 'head' | 'tail';
  levels?: OutputLevel[];
  includeInternal?: boolean;
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

export async function queryLogsHandlerAsync(
  session: BridgeSession,
  options: LogsOptions = {},
): Promise<LogsResult> {
  const result: BridgeLogsResult = await session.queryLogsAsync({
    count: options.count ?? 50,
    direction: options.direction ?? 'tail',
    levels: options.levels,
    includeInternal: options.includeInternal,
  });

  return {
    entries: result.entries ?? [],
    total: result.total ?? 0,
    bufferCapacity: result.bufferCapacity ?? 0,
    summary: `${(result.entries ?? []).length} entries (${result.total ?? 0} total in buffer)`,
  };
}

// ---------------------------------------------------------------------------
// Command definition
// ---------------------------------------------------------------------------

export const logsCommand = defineCommand<LogsOptions, LogsResult>({
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
      description: 'Filter by output level (Print, Warning, Error)',
      array: true,
    }),
    includeInternal: arg.flag({
      description: 'Include internal/system log messages',
    }),
  },
  handler: async (session, args) => {
    return queryLogsHandlerAsync(session, {
      count: args.count as number | undefined,
      direction: args.direction as 'head' | 'tail' | undefined,
      levels: args.levels as OutputLevel[] | undefined,
      includeInternal: args.includeInternal as boolean | undefined,
    });
  },
  mcp: {
    mapInput: (input) => ({
      count: input.count as number | undefined,
      direction: input.direction as 'head' | 'tail' | undefined,
      levels: input.levels as OutputLevel[] | undefined,
      includeInternal: input.includeInternal as boolean | undefined,
    }),
    mapResult: (result) => [
      {
        type: 'text' as const,
        text: JSON.stringify({
          entries: result.entries,
          total: result.total,
          bufferCapacity: result.bufferCapacity,
        }),
      },
    ],
  },
});
