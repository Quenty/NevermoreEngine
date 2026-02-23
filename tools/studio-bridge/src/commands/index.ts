/**
 * Command registry barrel export. Every new command handler adds an
 * export line here. cli.ts and future consumers (terminal-mode, MCP)
 * import from this barrel.
 */

export { listSessionsHandlerAsync, type SessionsResult } from './sessions.js';
export { serveHandlerAsync, type ServeOptions, type ServeResult } from './serve.js';
export { installPluginHandlerAsync, type InstallPluginResult } from './install-plugin.js';
export { uninstallPluginHandlerAsync, type UninstallPluginResult } from './uninstall-plugin.js';
export { queryStateHandlerAsync, type StateResult } from './state.js';
export { queryLogsHandlerAsync, type LogsResult, type LogsOptions } from './logs.js';
export { captureScreenshotHandlerAsync, type ScreenshotResult, type ScreenshotOptions } from './screenshot.js';
export { queryDataModelHandlerAsync, type QueryResult, type QueryOptions, type DataModelNode } from './query.js';
export { execHandlerAsync, type ExecOptions, type ExecResult } from './exec.js';
export { runHandlerAsync, type RunOptions, type RunResult } from './run.js';
export { launchHandlerAsync, type LaunchOptions, type LaunchResult } from './launch.js';
