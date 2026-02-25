/**
 * `process list` — list connected Studio sessions.
 */

import { defineCommand } from '../../framework/define-command.js';
import type { BridgeConnection } from '../../../bridge/index.js';
import type { SessionInfo } from '../../../bridge/index.js';

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
