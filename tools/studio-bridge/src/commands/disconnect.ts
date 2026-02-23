/**
 * Handler for the `disconnect` command. Signals disconnection from
 * the active session in terminal mode.
 */

export interface DisconnectResult {
  summary: string;
}

/**
 * Return a result indicating the active session should be cleared.
 */
export function disconnectHandler(): DisconnectResult {
  return { summary: 'Disconnected from session.' };
}
