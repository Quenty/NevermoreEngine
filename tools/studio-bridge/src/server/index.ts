export { StudioBridgeServer as StudioBridge } from './studio-bridge-server.js';
export type {
  StudioBridgeServerOptions,
  ExecuteOptions,
  StudioBridgeResult,
  StudioBridgePhase,
} from './studio-bridge-server.js';

export { encodeMessage, decodePluginMessage } from './web-socket-protocol.js';
export type {
  OutputLevel,
  PluginMessage,
  ServerMessage,
  HelloMessage,
  OutputMessage,
  ScriptCompleteMessage,
  WelcomeMessage,
  ExecuteMessage,
  ShutdownMessage,
} from './web-socket-protocol.js';
