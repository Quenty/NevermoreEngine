/**
 * WebSocket message protocol shared between the Node.js server and the Roblox
 * Studio plugin. All messages are JSON-encoded: `{ type: string, sessionId: string, payload: object }`.
 */

// ---------------------------------------------------------------------------
// Output levels (matches Roblox Enum.MessageType names)
// ---------------------------------------------------------------------------

export type OutputLevel = 'Print' | 'Info' | 'Warning' | 'Error';

// ---------------------------------------------------------------------------
// Plugin → Server messages
// ---------------------------------------------------------------------------

export interface HelloMessage {
  type: 'hello';
  sessionId: string;
  payload: {
    sessionId: string;
  };
}

export interface OutputMessage {
  type: 'output';
  sessionId: string;
  payload: {
    messages: Array<{
      level: OutputLevel;
      body: string;
    }>;
  };
}

export interface ScriptCompleteMessage {
  type: 'scriptComplete';
  sessionId: string;
  payload: {
    success: boolean;
    error?: string;
  };
}

export type PluginMessage = HelloMessage | OutputMessage | ScriptCompleteMessage;

// ---------------------------------------------------------------------------
// Server → Plugin messages
// ---------------------------------------------------------------------------

export interface WelcomeMessage {
  type: 'welcome';
  sessionId: string;
  payload: {
    sessionId: string;
  };
}

export interface ExecuteMessage {
  type: 'execute';
  sessionId: string;
  payload: {
    script: string;
  };
}

export interface ShutdownMessage {
  type: 'shutdown';
  sessionId: string;
  payload: Record<string, never>;
}

export type ServerMessage = WelcomeMessage | ExecuteMessage | ShutdownMessage;

// ---------------------------------------------------------------------------
// Encoding / decoding helpers
// ---------------------------------------------------------------------------

export function encodeMessage(msg: ServerMessage): string {
  return JSON.stringify(msg);
}

export function decodePluginMessage(raw: string): PluginMessage | null {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return null;
  }

  if (typeof parsed !== 'object' || parsed === null) {
    return null;
  }

  const obj = parsed as Record<string, unknown>;
  if (typeof obj.type !== 'string' || typeof obj.payload !== 'object' || obj.payload === null) {
    return null;
  }

  if (typeof obj.sessionId !== 'string') {
    return null;
  }

  const { type, sessionId, payload } = obj as { type: string; sessionId: string; payload: Record<string, unknown> };

  switch (type) {
    case 'hello':
      if (typeof payload.sessionId === 'string') {
        return { type: 'hello', sessionId, payload: { sessionId: payload.sessionId } };
      }
      return null;

    case 'output':
      if (Array.isArray(payload.messages)) {
        const messages = payload.messages
          .filter(
            (m: unknown): m is { level: OutputLevel; body: string } =>
              typeof m === 'object' &&
              m !== null &&
              typeof (m as Record<string, unknown>).level === 'string' &&
              typeof (m as Record<string, unknown>).body === 'string'
          )
          .map((m) => ({ level: m.level, body: m.body }));
        return { type: 'output', sessionId, payload: { messages } };
      }
      return null;

    case 'scriptComplete':
      if (typeof payload.success === 'boolean') {
        return {
          type: 'scriptComplete',
          sessionId,
          payload: {
            success: payload.success,
            error: typeof payload.error === 'string' ? payload.error : undefined,
          },
        };
      }
      return null;

    default:
      return null;
  }
}
