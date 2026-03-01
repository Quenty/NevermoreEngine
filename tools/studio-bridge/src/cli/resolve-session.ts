/**
 * CLI utility for resolving which studio-bridge session to target
 * based on command-line arguments.
 */

import type { BridgeConnection } from '../bridge/index.js';
import type { SessionInfo, SessionContext } from '../bridge/index.js';

export interface ResolveSessionOptions {
  sessionId?: string;
  instanceId?: string;
  context?: SessionContext;
}

/**
 * Resolve which session to target based on CLI args.
 *
 * - If sessionId is provided, looks up that specific session.
 * - Otherwise lists all sessions and filters by instanceId/context.
 * - Auto-selects when exactly one session matches.
 * - Throws descriptive errors on zero or ambiguous matches.
 */
export async function resolveSessionAsync(
  connection: BridgeConnection,
  options: ResolveSessionOptions = {},
): Promise<SessionInfo> {
  if (options.sessionId) {
    const sessions = connection.listSessions();
    const session = sessions.find((s) => s.sessionId === options.sessionId);
    if (!session) {
      throw new Error(`Session '${options.sessionId}' not found.`);
    }
    return session;
  }

  let sessions = connection.listSessions();

  if (options.instanceId) {
    sessions = sessions.filter((s) => s.instanceId === options.instanceId);
  }

  if (options.context) {
    sessions = sessions.filter((s) => s.context === options.context);
  }

  if (sessions.length === 1) {
    return sessions[0];
  }

  if (sessions.length === 0) {
    throw new Error(
      'No matching sessions found. Is Studio running with the studio-bridge plugin?',
    );
  }

  const listing = sessions
    .map((s) => `  - ${s.sessionId} (instance=${s.instanceId}, context=${s.context})`)
    .join('\n');

  throw new Error(
    `Multiple sessions found. Use --session or --instance to select one:\n${listing}`,
  );
}
