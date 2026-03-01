/**
 * Public API surface for the bridge module.
 *
 * Re-exports ONLY public types — nothing from internal/ leaks out.
 * Consumers import from '@quenty/studio-bridge/bridge' (or this index)
 * and get BridgeConnection, BridgeSession, typed results, and errors.
 */

// Classes
export { BridgeConnection } from './bridge-connection.js';
export type { BridgeConnectionOptions } from './bridge-connection.js';
export { BridgeSession } from './bridge-session.js';

// Types
export type {
  SessionInfo,
  InstanceInfo,
  SessionContext,
  SessionOrigin,
  ExecResult,
  StateResult,
  ScreenshotResult,
  LogsResult,
  DataModelResult,
  LogEntry,
  LogOptions,
  QueryDataModelOptions,
  LogFollowOptions,
  StudioState,
  DataModelInstance,
  OutputLevel,
} from './types.js';

// Error classes
export {
  SessionNotFoundError,
  ActionTimeoutError,
  SessionDisconnectedError,
  CapabilityNotSupportedError,
  ContextNotFoundError,
  HostUnreachableError,
} from './types.js';
