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
} from './server/web-socket-protocol.js';
export type {
  PluginMessage,
  ServerMessage,
  HelloMessage,
  OutputMessage,
  ScriptCompleteMessage,
  WelcomeMessage,
  ExecuteMessage,
  ShutdownMessage,
} from './server/web-socket-protocol.js';
