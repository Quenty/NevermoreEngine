/**
 * @quenty/studio-bridge — WebSocket-based bridge for running Luau scripts in
 * Roblox Studio. Replaces the unmaintained run-in-roblox tool.
 *
 * Primary API:
 *   import { StudioBridge } from '@quenty/studio-bridge';
 *   const result = await StudioBridge.executeAsync({ scriptContent });
 */

export { StudioBridge } from './studio-bridge.js';
export type { StudioBridgeOptions, StudioBridgeResult, StudioBridgePhase } from './studio-bridge.js';
export type { OutputLevel } from './protocol.js';

// Lower-level exports for advanced usage / testing
export { buildRbxmx } from './rbxmx-builder.js';
export { buildMinimalPlaceAsync } from './place-builder.js';
export { findStudioPathAsync, findPluginsFolder, launchStudioAsync } from './studio-process.js';
export { injectPluginAsync, substituteTemplate, escapeLuaString } from './plugin-injector.js';
export {
  encodeMessage,
  decodePluginMessage,
} from './protocol.js';
export type {
  PluginMessage,
  ServerMessage,
  HelloMessage,
  OutputMessage,
  ScriptCompleteMessage,
  WelcomeMessage,
  ExecuteMessage,
  ShutdownMessage,
} from './protocol.js';
