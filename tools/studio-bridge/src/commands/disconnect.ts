/**
 * Handler for the `disconnect` command. Signals disconnection from
 * the active session in terminal mode.
 */

export interface DisconnectResult {
  summary: string;
}

export function disconnectHandler(): DisconnectResult {
  return { summary: 'Disconnected from session.' };
}
