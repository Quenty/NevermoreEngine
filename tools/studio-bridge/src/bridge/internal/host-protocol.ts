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

/**
 * Raised when the host-client protocol changes, so a client can tell it is
 * relaying through an older host. Hosts before this field have none.
 */
export const HOST_PROTOCOL_VERSION = 3;

export interface HostEnvelope {
  type: 'host-envelope';
  requestId: string;
  targetSessionId: string;
  action: ServerMessage;
  timeoutMs?: number;
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
  /** Absent from hosts older than HOST_PROTOCOL_VERSION 2. */
  protocolVersion?: number;
  host?: HostInfo;
}

/** What a host says about itself, so a client can tell it is stale. */
export interface HostInfo {
  version: string;
  build?: string;
  packagePath?: string;
  cwd?: string;
  pid: number;
  argv: string[];
  clients: number;
  pendingRelays: number;
  uptimeMs?: number;
  autoStarted?: boolean;
  idleTimeoutMs?: number;
  logPath?: string;
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
// Payloads keep fields they don't list, so a newer client's options reach
// the plugin through an older host instead of being silently dropped.
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
  'SCRIPT_TIMEOUT',
  'RESULT_TOO_LARGE',
  'BUSY',
  'SESSION_MISMATCH',
  'INTERNAL_ERROR',
]);

const OutputLevelSchema = z.enum(['Print', 'Info', 'Warning', 'Error']);

const InstanceQueryShape = {
  root: z.string().optional(),
  query: z.string().optional(),
  selector: z.string().optional(),
  grep: z.string().optional(),
  luaPattern: z.boolean().optional(),
  caseSensitive: z.boolean().optional(),
};

const RecordingOptionsShape = {
  trigger: z.string().optional(),
  duration: z.number(),
  fps: z.number().optional(),
  maxFrames: z.number().optional(),
};

const ViewportReadOptionsShape = {
  region: z.tuple([z.number(), z.number(), z.number(), z.number()]).optional(),
  scale: z.number().optional(),
};

const ServerMessageSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('execute'),
    sessionId: z.string(),
    requestId: z.string().optional(),
    payload: z
      .object({
        script: z.string(),
        timeoutMs: z.number().optional(),
        args: z.array(z.string()).optional(),
      })
      .loose(),
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
    payload: z
      .object({
        format: z.literal('png').optional(),
        ...ViewportReadOptionsShape,
      })
      .loose(),
  }),
  z.object({
    type: z.literal('inspectInstance'),
    sessionId: z.string(),
    requestId: z.string(),
    payload: z
      .object({
        ...InstanceQueryShape,
        selection: z.boolean().optional(),
        depth: z.number().optional(),
        properties: z.boolean().optional(),
        attributes: z.boolean().optional(),
      })
      .loose(),
  }),
  z.object({
    type: z.literal('findInstances'),
    sessionId: z.string(),
    requestId: z.string(),
    payload: z
      .object({
        ...InstanceQueryShape,
        limit: z.number().optional(),
      })
      .loose(),
  }),
  z.object({
    type: z.literal('sampleInstances'),
    sessionId: z.string(),
    requestId: z.string(),
    payload: z
      .object({
        ...InstanceQueryShape,
        ...RecordingOptionsShape,
        duration: z.number().optional(),
        properties: z.array(z.string()).optional(),
        attributes: z.array(z.string()).optional(),
        watch: z
          .object({
            id: z.string(),
            wait: z.number().optional(),
            stop: z.boolean().optional(),
          })
          .optional(),
      })
      .loose(),
  }),
  z.object({
    type: z.literal('recordViewport'),
    sessionId: z.string(),
    requestId: z.string(),
    payload: z
      .object({
        ...RecordingOptionsShape,
        ...ViewportReadOptionsShape,
      })
      .loose(),
  }),
  z.object({
    type: z.literal('grepScripts'),
    sessionId: z.string(),
    requestId: z.string(),
    payload: z
      .object({
        ...InstanceQueryShape,
        pattern: z.string(),
        limit: z.number().optional(),
      })
      .loose(),
  }),
  z.object({
    type: z.literal('exportInstances'),
    sessionId: z.string(),
    requestId: z.string(),
    payload: z.object({ paths: z.array(z.string()) }).loose(),
  }),
  z.object({
    type: z.literal('importInstances'),
    sessionId: z.string(),
    requestId: z.string(),
    payload: z.object({ data: z.string(), parentPath: z.string() }).loose(),
  }),
  z.object({
    type: z.literal('queryLogs'),
    sessionId: z.string(),
    requestId: z.string(),
    payload: z
      .object({
        count: z.number().optional(),
        direction: z.enum(['head', 'tail']).optional(),
        levels: z.array(OutputLevelSchema).optional(),
        includeInternal: z.boolean().optional(),
        since: z.number().optional(),
        groupRepeats: z.boolean().optional(),
      })
      .loose(),
  }),
  z.object({
    type: z.literal('registerAction'),
    sessionId: z.string(),
    requestId: z.string(),
    payload: z
      .object({
        name: z.string(),
        source: z.string(),
        hash: z.string().optional(),
        responseType: z.string().optional(),
      })
      .loose(),
  }),
  z.object({
    type: z.literal('syncActions'),
    sessionId: z.string(),
    requestId: z.string(),
    payload: z
      .object({
        actions: z.record(z.string(), z.string()),
        verbose: z.boolean().optional(),
      })
      .loose(),
  }),
  z.object({
    type: z.literal('startPlaytest'),
    sessionId: z.string(),
    requestId: z.string(),
    payload: z
      .object({
        mode: z.enum(['play', 'run']),
        playtestId: z.string(),
        bridgePort: z.number(),
        instanceId: z.string(),
        players: z.number().int().min(1).optional(),
        bridge: z
          .object({
            precompiled: z.array(z.string()),
            client: z.boolean().optional(),
          })
          .optional(),
      })
      .loose(),
  }),
  z.object({
    type: z.literal('endPlaytest'),
    sessionId: z.string(),
    requestId: z.string(),
    payload: z.object({}).loose(),
  }),
  z.object({
    type: z.literal('playtestPlayers'),
    sessionId: z.string(),
    requestId: z.string(),
    payload: z.discriminatedUnion('op', [
      z.object({ op: z.literal('list') }),
      z.object({
        op: z.literal('add'),
        count: z.number().int().min(1),
        timeoutSec: z.number(),
      }),
      z.object({
        op: z.literal('remove'),
        kick: z.array(z.string()),
        names: z.array(z.string()),
        timeoutSec: z.number(),
      }),
      z.object({ op: z.literal('leave') }),
    ]),
  }),
  z.object({
    type: z.literal('error'),
    sessionId: z.string(),
    requestId: z.string().optional(),
    payload: z
      .object({
        code: ErrorCodeSchema,
        message: z.string(),
        details: z.unknown().optional(),
      })
      .loose(),
  }),
]);

const LooseObjectSchema = z.record(z.string(), z.unknown());

const HostProtocolMessageSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('host-envelope'),
    requestId: z.string(),
    targetSessionId: z.string(),
    action: ServerMessageSchema,
    timeoutMs: z.number().optional(),
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
    protocolVersion: z.number().optional(),
    host: z
      .object({
        version: z.string(),
        build: z.string().optional(),
        packagePath: z.string().optional(),
        cwd: z.string().optional(),
        pid: z.number(),
        argv: z.array(z.string()),
        clients: z.number(),
        pendingRelays: z.number(),
      })
      .loose()
      .optional(),
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
