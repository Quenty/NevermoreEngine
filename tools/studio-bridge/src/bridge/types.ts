/**
 * Public types for the bridge network layer. Defines session metadata,
 * instance grouping, action result types, and typed error classes.
 *
 * This module has no imports from internal/ -- it is a pure type definition
 * file that forms the public API surface of the bridge network.
 */

import type {
  StudioState,
  Capability,
  SubscribableEvent,
  DataModelInstance,
  OutputLevel,
} from '../server/web-socket-protocol.js';

// Re-export protocol types used in the public API
export type { StudioState, Capability, SubscribableEvent, DataModelInstance, OutputLevel };

// ---------------------------------------------------------------------------
// Session and instance metadata
// ---------------------------------------------------------------------------

export type SessionContext = 'edit' | 'client' | 'server';
export type SessionOrigin = 'user' | 'managed';

export interface SessionInfo {
  sessionId: string;
  placeName: string;
  placeFile?: string;
  state: StudioState;
  pluginVersion: string;
  capabilities: Capability[];
  connectedAt: Date;
  origin: SessionOrigin;
  context: SessionContext;
  instanceId: string;
  placeId: number;
  gameId: number;
}

export interface InstanceInfo {
  instanceId: string;
  placeName: string;
  placeId: number;
  gameId: number;
  contexts: SessionContext[];
  origin: SessionOrigin;
}

// ---------------------------------------------------------------------------
// Action result types
// ---------------------------------------------------------------------------

export interface ExecResult {
  success: boolean;
  output: Array<{ level: OutputLevel; body: string }>;
  error?: string;
}

export interface StateResult {
  state: StudioState;
  placeId: number;
  placeName: string;
  gameId: number;
}

export interface ScreenshotResult {
  data: string;
  format: 'png' | 'rgba';
  width: number;
  height: number;
}

export interface LogEntry {
  level: OutputLevel;
  body: string;
  timestamp: number;
}

export interface LogsResult {
  entries: LogEntry[];
  total: number;
  bufferCapacity: number;
}

export interface DataModelResult {
  instance: DataModelInstance;
}

// ---------------------------------------------------------------------------
// Action option types
// ---------------------------------------------------------------------------

export interface LogOptions {
  count?: number;
  direction?: 'head' | 'tail';
  levels?: OutputLevel[];
  includeInternal?: boolean;
}

export interface QueryDataModelOptions {
  path: string;
  depth?: number;
  properties?: string[];
  includeAttributes?: boolean;
  find?: { name: string; recursive?: boolean };
  listServices?: boolean;
}

export interface LogFollowOptions {
  levels?: OutputLevel[];
}

// ---------------------------------------------------------------------------
// Error types
// ---------------------------------------------------------------------------

export class SessionNotFoundError extends Error {
  constructor(
    message: string,
    public readonly sessionId?: string,
  ) {
    super(message);
    this.name = 'SessionNotFoundError';
  }
}

export class ActionTimeoutError extends Error {
  constructor(
    public readonly action: string,
    public readonly timeoutMs: number,
    public readonly sessionId: string,
  ) {
    super(`Action '${action}' timed out after ${timeoutMs}ms on session '${sessionId}'`);
    this.name = 'ActionTimeoutError';
  }
}

export class SessionDisconnectedError extends Error {
  constructor(public readonly sessionId: string) {
    super(`Session '${sessionId}' disconnected`);
    this.name = 'SessionDisconnectedError';
  }
}

export class CapabilityNotSupportedError extends Error {
  constructor(
    public readonly capability: string,
    public readonly sessionId: string,
  ) {
    super(`Plugin does not support capability '${capability}' on session '${sessionId}'`);
    this.name = 'CapabilityNotSupportedError';
  }
}

export class ContextNotFoundError extends Error {
  constructor(
    public readonly context: SessionContext,
    public readonly instanceId: string,
    public readonly availableContexts: SessionContext[],
  ) {
    super(
      `Context '${context}' not connected on instance '${instanceId}'. Available: ${availableContexts.join(', ')}`,
    );
    this.name = 'ContextNotFoundError';
  }
}

export class HostUnreachableError extends Error {
  constructor(
    public readonly host: string,
    public readonly port: number,
  ) {
    super(`Bridge host unreachable at ${host}:${port}`);
    this.name = 'HostUnreachableError';
  }
}
