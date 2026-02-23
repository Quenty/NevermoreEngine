/**
 * Handler for the `sessions` command. Returns a list of active
 * studio-bridge sessions with a human-readable summary.
 */

import type { BridgeConnection } from '../bridge/index.js';
import type { SessionInfo } from '../bridge/index.js';

export interface SessionsResult {
  sessions: SessionInfo[];
  summary: string;
}

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
