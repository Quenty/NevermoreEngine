/**
 * Command registry barrel export. Every new command handler adds an
 * export line here. cli.ts and future consumers (terminal-mode, MCP)
 * import from this barrel.
 */

export { listSessionsHandlerAsync, type SessionsResult } from './process/list/list.js';
export { serveHandlerAsync, type ServeOptions, type ServeResult } from './serve/serve.js';
export { installPluginHandlerAsync, type InstallPluginResult } from './plugin/install/install.js';
export { uninstallPluginHandlerAsync, type UninstallPluginResult } from './plugin/uninstall/uninstall.js';
export { queryStateHandlerAsync, type StateResult } from './process/info/info.js';
export { queryLogsHandlerAsync, type LogsResult, type LogsOptions } from './console/logs/logs.js';
export { captureScreenshotHandlerAsync, type ScreenshotResult, type ScreenshotOptions } from './viewport/screenshot/screenshot.js';
export { queryDataModelHandlerAsync, type QueryResult, type QueryOptions, type DataModelNode } from './explorer/query/query.js';
export { execHandlerAsync, type ExecOptions, type ExecResult } from './console/exec/exec.js';
export { runHandlerAsync, type RunOptions, type RunResult } from './console/exec/exec.js';
export { launchHandlerAsync, type LaunchOptions, type LaunchResult } from './process/launch/launch.js';
export { connectHandlerAsync, type ConnectOptions, type ConnectResult } from './connect.js';
export { disconnectHandler, type DisconnectResult } from './disconnect.js';
export { mcpHandlerAsync, type McpResult } from './mcp/mcp.js';
export { type TerminalOptions, type TerminalResult } from './terminal/terminal.js';
export { processRunHandlerAsync, type ProcessRunOptions, type ProcessRunResult } from './process/run/run.js';
export { processCloseHandlerAsync, type ProcessCloseResult } from './process/close/close.js';
export { invokeActionHandlerAsync, type ActionResult } from './action/action.js';
