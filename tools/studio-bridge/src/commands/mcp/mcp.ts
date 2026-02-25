/**
 * `mcp` — start the MCP server that exposes studio-bridge capabilities
 * as MCP tools over stdio.
 */

import { defineCommand } from '../framework/define-command.js';
import { startMcpServerAsync } from '../../mcp/index.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface McpResult {
  summary: string;
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

/**
 * Start the MCP server. This blocks until the stdio transport closes.
 */
export async function mcpHandlerAsync(): Promise<McpResult> {
  await startMcpServerAsync();

  return {
    summary: 'MCP server stopped.',
  };
}

// ---------------------------------------------------------------------------
// Command definition
// ---------------------------------------------------------------------------

export const mcpCommand = defineCommand({
  group: null,
  name: 'mcp',
  description: 'Start the MCP server',
  category: 'infrastructure',
  safety: 'none',
  scope: 'standalone',
  args: {},
  handler: async () => mcpHandlerAsync(),
});
