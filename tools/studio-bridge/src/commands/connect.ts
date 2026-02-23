/**
 * Handler for the `connect` command. Resolves a session by ID and
 * returns metadata about it so the caller can set it as the active session.
 */

import type { BridgeConnection } from '../bridge/index.js';

export interface ConnectOptions {
  sessionId: string;
}

export interface ConnectResult {
  sessionId: string;
  context: string;
  placeName: string;
  summary: string;
}

/**
 * Resolve a session by ID and return its metadata.
 */
export async function connectHandlerAsync(
  connection: BridgeConnection,
  options: ConnectOptions,
): Promise<ConnectResult> {
  const session = await connection.resolveSession(options.sessionId);
  const info = session.info;

  return {
    sessionId: info.sessionId,
    context: info.context,
    placeName: info.placeName,
    summary: `Connected to session ${info.sessionId} (${info.placeName}, ${info.context})`,
  };
}
