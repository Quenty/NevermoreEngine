/**
 * Envelope protocol for client-to-host communication. When a bridge client
 * needs to send an action to a plugin session, it wraps the action in a
 * HostEnvelope and sends it to the host. The host unwraps the envelope,
 * forwards the action to the plugin, wraps the response in a HostResponse,
 * and sends it back to the client.
 */

import { z } from 'zod';
import type {
  ServerMessage,
  PluginMessage,
} from '../../server/web-socket-protocol.js';
import type { SessionInfo, SessionContext, InstanceInfo } from '../types.js';

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

export interface HostTransferNotice {
  type: 'host-transfer';
}

export type HostProtocolMessage =
  | HostEnvelope
  | ListSessionsRequest
  | ListInstancesRequest
  | HostResponse
  | ListSessionsResponse
  | ListInstancesResponse
  | SessionEvent
  | HostTransferNotice;

// --- Runtime validation schemas ---
//
// `ServerMessageSchema` is the load-bearing one: it validates the `action`
// payload that /client connections forward to plugins. Without it, a buggy
// or hostile CLI client could ship malformed actions and crash the plugin.
// Container fields like `result`, `sessions`, `instances`, and `session` are
// validated only as objects/arrays — their interior shapes flow through to
// callers that already know how to handle the typed contracts.

const ErrorCodeSchema = z.enum([
  'UNKNOWN_REQUEST',
  'INVALID_PAYLOAD',
  'TIMEOUT',
  'CAPABILITY_NOT_SUPPORTED',
  'INSTANCE_NOT_FOUND',
  'PROPERTY_NOT_FOUND',
  'SCREENSHOT_FAILED',
  'SCRIPT_LOAD_ERROR',
  'SCRIPT_RUNTIME_ERROR',
  'BUSY',
  'SESSION_MISMATCH',
  'INTERNAL_ERROR',
]);

const OutputLevelSchema = z.enum(['Print', 'Info', 'Warning', 'Error']);

const ServerMessageSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('execute'),
    sessionId: z.string(),
    requestId: z.string().optional(),
    payload: z.object({ script: z.string() }),
  }),
  z.object({
    type: z.literal('shutdown'),
    sessionId: z.string(),
    payload: z.object({}).loose(),
  }),
  z.object({
    type: z.literal('queryState'),
    sessionId: z.string(),
    requestId: z.string(),
    payload: z.object({}).loose(),
  }),
  z.object({
    type: z.literal('captureScreenshot'),
    sessionId: z.string(),
    requestId: z.string(),
    payload: z.object({
      format: z.literal('png').optional(),
    }),
  }),
  z.object({
    type: z.literal('queryDataModel'),
    sessionId: z.string(),
    requestId: z.string(),
    payload: z.object({
      path: z.string(),
      depth: z.number().optional(),
      properties: z.array(z.string()).optional(),
      includeAttributes: z.boolean().optional(),
      find: z
        .object({
          name: z.string(),
          recursive: z.boolean().optional(),
        })
        .optional(),
      listServices: z.boolean().optional(),
    }),
  }),
  z.object({
    type: z.literal('queryLogs'),
    sessionId: z.string(),
    requestId: z.string(),
    payload: z.object({
      count: z.number().optional(),
      direction: z.enum(['head', 'tail']).optional(),
      levels: z.array(OutputLevelSchema).optional(),
      includeInternal: z.boolean().optional(),
    }),
  }),
  z.object({
    type: z.literal('registerAction'),
    sessionId: z.string(),
    requestId: z.string(),
    payload: z.object({
      name: z.string(),
      source: z.string(),
      hash: z.string().optional(),
      responseType: z.string().optional(),
    }),
  }),
  z.object({
    type: z.literal('syncActions'),
    sessionId: z.string(),
    requestId: z.string(),
    payload: z.object({
      actions: z.record(z.string(), z.string()),
    }),
  }),
  z.object({
    type: z.literal('error'),
    sessionId: z.string(),
    requestId: z.string().optional(),
    payload: z.object({
      code: ErrorCodeSchema,
      message: z.string(),
      details: z.unknown().optional(),
    }),
  }),
]);

const LooseObjectSchema = z.record(z.string(), z.unknown());

const HostProtocolMessageSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('host-envelope'),
    requestId: z.string(),
    targetSessionId: z.string(),
    action: ServerMessageSchema,
  }),
  z.object({
    type: z.literal('list-sessions'),
    requestId: z.string(),
  }),
  z.object({
    type: z.literal('list-instances'),
    requestId: z.string(),
  }),
  z.object({
    type: z.literal('host-response'),
    requestId: z.string(),
    result: LooseObjectSchema,
  }),
  z.object({
    type: z.literal('list-sessions-response'),
    requestId: z.string(),
    sessions: z.array(LooseObjectSchema),
  }),
  z.object({
    type: z.literal('list-instances-response'),
    requestId: z.string(),
    instances: z.array(LooseObjectSchema),
  }),
  z.object({
    type: z.literal('session-event'),
    event: z.enum(['connected', 'disconnected', 'state-changed']),
    session: LooseObjectSchema.optional(),
    sessionId: z.string(),
    context: z.enum(['edit', 'client', 'server']),
    instanceId: z.string(),
  }),
  z.object({
    type: z.literal('host-transfer'),
  }),
]);

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

  const result = HostProtocolMessageSchema.safeParse(parsed);
  if (!result.success) {
    return null;
  }
  return result.data as HostProtocolMessage;
}
