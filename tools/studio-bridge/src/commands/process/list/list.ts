/**
 * `process list` — list connected Studio sessions.
 */

import { defineCommand } from '../../framework/define-command.js';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { formatAsTable, type TableColumn } from '../../../cli/format-output.js';
import type { BridgeConnection } from '../../../bridge/index.js';
import type { SessionInfo } from '../../../bridge/index.js';
import type { StudioState } from '../../../server/web-socket-protocol.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface SessionsResult {
  sessions: SessionInfo[];
  summary: string;
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

/**
 * List all connected Studio sessions with a summary message.
 */
export async function listSessionsHandlerAsync(
  connection: BridgeConnection,
): Promise<SessionsResult> {
  const sessions = connection.listSessions();

  if (sessions.length === 0) {
    return {
      sessions: [],
      summary: 'No active sessions. Is Studio running with the studio-bridge plugin?',
    };
  }

  return {
    sessions,
    summary: `${sessions.length} session(s) connected.`,
  };
}

// ---------------------------------------------------------------------------
// Formatters
// ---------------------------------------------------------------------------

function colorizeState(state: StudioState): string {
  switch (state) {
    case 'Edit': return OutputHelper.formatInfo(state);
    case 'Play':
    case 'Run': return OutputHelper.formatSuccess(state);
    case 'Paused': return OutputHelper.formatWarning(state);
    default: return state;
  }
}

const sessionColumns: TableColumn<SessionInfo>[] = [
  { header: 'Session', value: (s) => s.sessionId.slice(0, 8), format: (v) => OutputHelper.formatHint(v) },
  { header: 'Context', value: (s) => s.context },
  { header: 'Place', value: (s) => s.placeName },
  { header: 'State', value: (s) => s.state, format: (v) => colorizeState(v as StudioState) },
];

export function formatSessionsTable(result: SessionsResult): string {
  if (result.sessions.length === 0) return result.summary;
  return formatAsTable(result.sessions, sessionColumns);
}

// ---------------------------------------------------------------------------
// Command definition
// ---------------------------------------------------------------------------

export const listCommand = defineCommand({
  group: 'process',
  name: 'list',
  description: 'List connected Studio sessions',
  category: 'infrastructure',
  safety: 'read',
  scope: 'connection',
  args: {},
  cli: {
    formatResult: {
      text: formatSessionsTable,
      table: formatSessionsTable,
    },
  },
  handler: async (connection) => listSessionsHandlerAsync(connection),
  mcp: {
    mapResult: (result) => [
      {
        type: 'text' as const,
        text: JSON.stringify({
          sessions: result.sessions.map((s) => ({
            sessionId: s.sessionId,
            placeName: s.placeName,
            state: s.state,
            context: s.context,
            instanceId: s.instanceId,
            placeId: s.placeId,
            gameId: s.gameId,
          })),
        }),
      },
    ],
  },
});
