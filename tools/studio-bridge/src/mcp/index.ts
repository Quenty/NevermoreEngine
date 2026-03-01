/**
 * Public exports for the MCP server module.
 */

export { startMcpServerAsync, buildToolDefinitions } from './mcp-server.js';
export type { McpServerOptions } from './mcp-server.js';
export {
  createMcpTool,
  type McpToolDefinition,
  type McpToolResult,
  type McpContentBlock,
  type McpToolOptions,
} from './adapters/mcp-adapter.js';
