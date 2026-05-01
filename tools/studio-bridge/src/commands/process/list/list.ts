/**
 * `process list` — list connected Studio sessions.
 */

import { defineCommand } from '../../framework/define-command.js';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  formatTable,
  type TableColumn,
} from '@quenty/cli-output-helpers/reporting';
import type { BridgeConnection } from '../../../bridge/index.js';
import type { SessionInfo } from '../../../bridge/index.js';
import type { StudioState } from '../../../server/web-socket-protocol.js';
import { colorizeState } from '../format-state.js';

export interface SessionsResult {
  sessions: SessionInfo[];
  summary: string;
}

/**
 * List all connected Studio sessions with a summary message.
 */
export async function listSessionsHandlerAsync(
  connection: BridgeConnection
): Promise<SessionsResult> {
  const sessions = connection.listSessions();

  if (sessions.length === 0) {
    return {
      sessions: [],
      summary:
        'No active sessions. Is Studio running with the studio-bridge plugin?',
    };
  }

  return {
    sessions,
    summary: `${sessions.length} session(s) connected.`,
  };
}

const sessionColumns: TableColumn<SessionInfo>[] = [
  {
    header: 'Session',
    value: (s) => s.sessionId.slice(0, 8),
    format: (v) => OutputHelper.formatHint(v),
  },
  { header: 'Context', value: (s) => s.context },
  { header: 'Place', value: (s) => s.placeName },
  {
    header: 'State',
    value: (s) => s.state,
    format: (v) => colorizeState(v as StudioState),
  },
];

export function formatSessionsTable(result: SessionsResult): string {
  if (result.sessions.length === 0) return result.summary;
  return formatTable(result.sessions, sessionColumns);
}

export const listCommand = defineCommand({
  group: 'process',
  name: 'list',
  description: 'List connected Studio sessions',
  category: 'infrastructure',
  safety: 'read',
  scope: 'connection',
  args: {},
  cli: {
    format: formatSessionsTable,
  },
  handler: async (connection) => listSessionsHandlerAsync(connection),
});
