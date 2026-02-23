/**
 * Handler for the `logs` command. Retrieves buffered log history
 * from a connected Studio session's ring buffer.
 */

import type { BridgeSession } from '../bridge/index.js';
import type { LogEntry, LogsResult as BridgeLogsResult } from '../bridge/index.js';
import type { OutputLevel } from '../bridge/index.js';

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

/**
 * Query buffered log history from a connected Studio session.
 */
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
