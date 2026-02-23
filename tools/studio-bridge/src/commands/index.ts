/**
 * Command registry barrel export. Every new command handler adds an
 * export line here. cli.ts and future consumers (terminal-mode, MCP)
 * import from this barrel.
 */

export { listSessionsHandlerAsync, type SessionsResult } from './sessions.js';
export { serveHandlerAsync, type ServeOptions, type ServeResult } from './serve.js';
export { installPluginHandlerAsync, type InstallPluginResult } from './install-plugin.js';
export { uninstallPluginHandlerAsync, type UninstallPluginResult } from './uninstall-plugin.js';
