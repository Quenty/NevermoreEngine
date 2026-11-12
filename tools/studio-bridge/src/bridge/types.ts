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
  InspectedInstance,
  InstanceRef,
  OutputLevel,
  SerializedReturnValue,
  PlaytestMode,
  RunAs,
} from '../server/web-socket-protocol.js';
import { StudioBridgeError } from '../messages/studio-bridge-error.js';

// Re-export protocol types used in the public API
export type {
  StudioState,
  Capability,
  InspectedInstance,
  InstanceRef,
  OutputLevel,
  SerializedReturnValue,
  PlaytestMode,
  RunAs,
};

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
  /** Set on sessions of a Studio that `process run` launched. */
  launchId?: string;
  /** The player of a multiplayer test client session. */
  playerName?: string;
  /** The playtest studio-bridge started this session's DataModel for. */
  playtestId?: string;
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

export interface ExecResult {
  success: boolean;
  output: Array<{ level: OutputLevel; body: string }>;
  error?: string;
  /** Where a runtime error was thrown. */
  traceback?: string;
  /**
   * Everything the script returned, in order. Absent when the plugin reported
   * no return channel at all (a run that never reached a return) — distinct from `[]`, which means it returned nothing.
   */
  returnValues?: SerializedReturnValue[];
  ranAs?: RunAs;
}

export interface StateResult {
  state: StudioState;
  placeId: number;
  placeName: string;
  gameId: number;
  /** The camera's viewport in pixels. Absent without a camera. */
  viewportSize?: [number, number];
  /** Studio's version. Absent from older plugins. */
  studioVersion?: string;
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
  /** When grouped: how many identical entries in a row this stands for. */
  repeats?: number;
  /** When grouped: when the last of the repeats was logged. */
  lastTimestamp?: number;
}

export interface LogsResult {
  entries: LogEntry[];
  total: number;
  bufferCapacity: number;
}

export interface ExportInstancesResult {
  /** The binary model (.rbxm), base64-encoded. */
  data: string;
  instances: InstanceRef[];
}

export interface ImportInstancesResult {
  instances: InstanceRef[];
}

export interface LogOptions {
  count?: number;
  direction?: 'head' | 'tail';
  levels?: OutputLevel[];
  includeInternal?: boolean;
  /** Only entries logged at or after this time, in epoch seconds. */
  since?: number;
  /** Collapse identical consecutive entries, before `count` applies. */
  groupRepeats?: boolean;
}

export interface PlaytestEndResult {
  playtestId: string;
  /** False when StudioTestService refused to start the playtest. */
  success: boolean;
  error?: string;
}

export interface EndPlaytestResult {
  /** Absent when the playtest was not started by studio-bridge. */
  playtestId?: string;
  /** The mode the playtest ran in. Absent from older plugins. */
  mode?: PlaytestMode;
  /** How many players a multiplayer test started with. */
  players?: number;
}

export interface LogFollowOptions {
  levels?: OutputLevel[];
}

export class SessionNotFoundError extends StudioBridgeError {
  public readonly sessionId: string | undefined;

  constructor(options: {
    code?: string;
    message: string;
    fix?: string;
    sessionId?: string;
  }) {
    super({
      code: options.code ?? 'SESSION_NOT_FOUND',
      message: options.message,
      fix: options.fix,
    });
    this.name = 'SessionNotFoundError';
    this.sessionId = options.sessionId;
  }
}

export class ActionTimeoutError extends StudioBridgeError {
  constructor(
    public readonly action: string,
    public readonly timeoutMs: number,
    public readonly sessionId: string
  ) {
    super({
      code: 'TIMEOUT',
      message: `Studio didn't reply within ${formatSeconds(timeoutMs)}.`,
      fix: STUDIO_BUSY_FIX,
      cause: `'${action}' on session '${sessionId}' timed out after ${timeoutMs}ms`,
    });
    this.name = 'ActionTimeoutError';
  }
}

export const STUDIO_BUSY_FIX =
  "Check Studio isn't frozen, paused in the debugger or showing a dialog, then run the command again.";

export class SessionDisconnectedError extends StudioBridgeError {
  constructor(public readonly sessionId: string) {
    super({
      code: 'SESSION_DISCONNECTED',
      message:
        'Studio disconnected before the command finished, so it may have run only in part.',
      fix: 'Check the place is still open in Studio, then run the command again.',
      cause: `Session '${sessionId}' disconnected`,
    });
    this.name = 'SessionDisconnectedError';
  }
}

export class CapabilityNotSupportedError extends StudioBridgeError {
  constructor(
    public readonly capability: string,
    public readonly sessionId: string
  ) {
    super({
      code: 'CAPABILITY_NOT_SUPPORTED',
      message: `The studio-bridge plugin in this Studio can't do '${capability}'.`,
      fix: "Run 'studio-bridge plugin install' to update it.",
      cause: `Session '${sessionId}'`,
    });
    this.name = 'CapabilityNotSupportedError';
  }
}

export class ContextNotFoundError extends StudioBridgeError {
  constructor(
    public readonly context: SessionContext,
    public readonly instanceId: string,
    public readonly availableContexts: SessionContext[]
  ) {
    super({
      code: 'CONTEXT_NOT_FOUND',
      message: `This Studio has no ${context} session; it has ${availableContexts.join(
        ' and '
      )}.`,
      fix: `Run the command with --context ${availableContexts[0] ?? 'edit'}.`,
      cause: `Instance '${instanceId}'`,
    });
    this.name = 'ContextNotFoundError';
  }
}

export class HostUnreachableError extends StudioBridgeError {
  constructor(public readonly host: string, public readonly port: number) {
    super({
      code: 'HOST_UNREACHABLE',
      message: `Lost the bridge host and couldn't reach a new one.`,
      fix: 'Run the command again.',
      cause: `Bridge host unreachable at ${host}:${port}`,
    });
    this.name = 'HostUnreachableError';
  }
}

export const NO_STUDIO_CONNECTED = 'NO_STUDIO_CONNECTED';

export function formatSeconds(ms: number): string {
  return `${Math.round(ms / 100) / 10}s`;
}
