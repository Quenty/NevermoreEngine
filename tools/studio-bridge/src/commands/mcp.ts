/**
 * Handler for the `mcp` command. Starts the MCP server that exposes
 * studio-bridge capabilities as MCP tools over stdio.
 */

import { startMcpServerAsync } from '../mcp/index.js';

export interface McpResult {
  summary: string;
}

/**
 * Start the MCP server. This blocks until the stdio transport closes.
 */
export async function mcpHandlerAsync(): Promise<McpResult> {
  await startMcpServerAsync();

  return {
    summary: 'MCP server stopped.',
  };
}
