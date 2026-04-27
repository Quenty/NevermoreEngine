/**
 * @quenty/studio-bridge — WebSocket-based bridge for running Luau scripts in
 * Roblox Studio. Replaces the unmaintained run-in-roblox tool.
 *
 * Primary API:
 *   import { StudioBridge } from '@quenty/studio-bridge';
 *   const bridge = new StudioBridge({ placePath });
 *   await bridge.startAsync();
 *   const result = await bridge.executeAsync({ scriptContent });
 *   await bridge.stopAsync();
 */

export { StudioBridgeServer as StudioBridge } from './server/studio-bridge-server.js';
export type {
  StudioBridgeServerOptions,
  ExecuteOptions,
  StudioBridgeResult,
  StudioBridgePhase,
} from './server/studio-bridge-server.js';
export type { OutputLevel } from './server/web-socket-protocol.js';

// Bridge network layer (persistent sessions)
export {
  BridgeConnection,
  BridgeSession,
  SessionNotFoundError,
  ActionTimeoutError,
  SessionDisconnectedError,
  CapabilityNotSupportedError,
  ContextNotFoundError,
  HostUnreachableError,
} from './bridge/index.js';

export type {
  BridgeConnectionOptions,
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
} from './bridge/index.js';

// v2 protocol types
export type {
  Capability,
  StudioState,
  DataModelInstance,
  ErrorCode,
  SerializedValue,
} from './server/web-socket-protocol.js';

// Lower-level exports for advanced usage / testing
export {
  findStudioPathAsync,
  findPluginsFolder,
  launchStudioAsync,
} from './process/studio-process-manager.js';
export { injectPluginAsync } from './plugin/plugin-injector.js';
export {
  encodeMessage,
  decodePluginMessage,
  decodeServerMessage,
} from './server/web-socket-protocol.js';
export type {
  // v1 messages
  PluginMessage,
  ServerMessage,
  HelloMessage,
  OutputMessage,
  ScriptCompleteMessage,
  WelcomeMessage,
  ExecuteMessage,
  ShutdownMessage,
  // v2 plugin -> server messages
  RegisterMessage,
  StateResultMessage,
  ScreenshotResultMessage,
  DataModelResultMessage,
  LogsResultMessage,
  StateChangeMessage,
  HeartbeatMessage,
  PluginErrorMessage,
  // v2 server -> plugin messages
  QueryStateMessage,
  CaptureScreenshotMessage,
  QueryDataModelMessage,
  QueryLogsMessage,
  ServerErrorMessage,
  // v2 dynamic action registration
  RegisterActionMessage,
  RegisterActionResultMessage,
} from './server/web-socket-protocol.js';
