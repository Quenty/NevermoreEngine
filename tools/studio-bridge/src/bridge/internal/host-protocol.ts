/**
 * Envelope protocol for client-to-host communication. When a bridge client
 * needs to send an action to a plugin session, it wraps the action in a
 * HostEnvelope and sends it to the host. The host unwraps the envelope,
 * forwards the action to the plugin, wraps the response in a HostResponse,
 * and sends it back to the client.
 */

import type { ServerMessage, PluginMessage } from '../../server/web-socket-protocol.js';
import type { SessionInfo, SessionContext, InstanceInfo } from '../types.js';

// ---------------------------------------------------------------------------
// Client -> Host messages
// ---------------------------------------------------------------------------

export interface HostEnvelope {
  type: 'host-envelope';
  requestId: string;
  targetSessionId: string;
  action: ServerMessage;
}

export interface ListSessionsRequest {
  type: 'list-sessions';
  requestId: string;
}

export interface ListInstancesRequest {
  type: 'list-instances';
  requestId: string;
}

// ---------------------------------------------------------------------------
// Host -> Client messages
// ---------------------------------------------------------------------------

export interface HostResponse {
  type: 'host-response';
  requestId: string;
  result: PluginMessage;
}

export interface ListSessionsResponse {
  type: 'list-sessions-response';
  requestId: string;
  sessions: SessionInfo[];
}

export interface ListInstancesResponse {
  type: 'list-instances-response';
  requestId: string;
  instances: InstanceInfo[];
}

export interface SessionEvent {
  type: 'session-event';
  event: 'connected' | 'disconnected' | 'state-changed';
  session?: SessionInfo;
  sessionId: string;
  context: SessionContext;
  instanceId: string;
}

// ---------------------------------------------------------------------------
// Union type
// ---------------------------------------------------------------------------

export type HostProtocolMessage =
  | HostEnvelope
  | ListSessionsRequest
  | ListInstancesRequest
  | HostResponse
  | ListSessionsResponse
  | ListInstancesResponse
  | SessionEvent;

// ---------------------------------------------------------------------------
// Encoding / Decoding
// ---------------------------------------------------------------------------

/**
 * Encode a host protocol message to a JSON string.
 */
export function encodeHostMessage(msg: HostProtocolMessage): string {
  return JSON.stringify(msg);
}

/**
 * Decode a host protocol message from a JSON string.
 * Returns null if the message is malformed or has an unknown type.
 */
export function decodeHostMessage(raw: string): HostProtocolMessage | null {
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
  const type = obj.type;

  if (typeof type !== 'string') {
    return null;
  }

  switch (type) {
    case 'host-envelope': {
      if (
        typeof obj.requestId !== 'string' ||
        typeof obj.targetSessionId !== 'string' ||
        typeof obj.action !== 'object' ||
        obj.action === null
      ) {
        return null;
      }
      return {
        type: 'host-envelope',
        requestId: obj.requestId,
        targetSessionId: obj.targetSessionId,
        action: obj.action as ServerMessage,
      };
    }

    case 'list-sessions': {
      if (typeof obj.requestId !== 'string') {
        return null;
      }
      return {
        type: 'list-sessions',
        requestId: obj.requestId,
      };
    }

    case 'list-instances': {
      if (typeof obj.requestId !== 'string') {
        return null;
      }
      return {
        type: 'list-instances',
        requestId: obj.requestId,
      };
    }

    case 'host-response': {
      if (
        typeof obj.requestId !== 'string' ||
        typeof obj.result !== 'object' ||
        obj.result === null
      ) {
        return null;
      }
      return {
        type: 'host-response',
        requestId: obj.requestId,
        result: obj.result as PluginMessage,
      };
    }

    case 'list-sessions-response': {
      if (typeof obj.requestId !== 'string' || !Array.isArray(obj.sessions)) {
        return null;
      }
      return {
        type: 'list-sessions-response',
        requestId: obj.requestId,
        sessions: obj.sessions as SessionInfo[],
      };
    }

    case 'list-instances-response': {
      if (typeof obj.requestId !== 'string' || !Array.isArray(obj.instances)) {
        return null;
      }
      return {
        type: 'list-instances-response',
        requestId: obj.requestId,
        instances: obj.instances as InstanceInfo[],
      };
    }

    case 'session-event': {
      if (
        typeof obj.event !== 'string' ||
        typeof obj.sessionId !== 'string' ||
        typeof obj.context !== 'string' ||
        typeof obj.instanceId !== 'string'
      ) {
        return null;
      }
      const event = obj.event as 'connected' | 'disconnected' | 'state-changed';
      if (!['connected', 'disconnected', 'state-changed'].includes(event)) {
        return null;
      }
      return {
        type: 'session-event',
        event,
        session: (typeof obj.session === 'object' && obj.session !== null)
          ? obj.session as SessionInfo
          : undefined,
        sessionId: obj.sessionId,
        context: obj.context as SessionContext,
        instanceId: obj.instanceId,
      };
    }

    default:
      return null;
  }
}
