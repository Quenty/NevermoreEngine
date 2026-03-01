/**
 * MCP server entry point. Creates a bridge connection, registers tools
 * from command definitions via the adapter layer, and communicates over
 * stdio transport.
 *
 * Diagnostic output goes to stderr to avoid interfering with the MCP
 * JSON-RPC protocol on stdout.
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';

import { BridgeConnection } from '../bridge/index.js';
import {
  buildMcpToolsFromRegistry,
} from './adapters/mcp-command-adapter.js';
import type { McpToolDefinition } from './adapters/mcp-adapter.js';

// Command definitions (explicit imports for deterministic ordering)
import { execCommand } from '../commands/console/exec/exec.js';
import { logsCommand } from '../commands/console/logs/logs.js';
import { queryCommand } from '../commands/explorer/query/query.js';
import { screenshotCommand } from '../commands/viewport/screenshot/screenshot.js';
import { infoCommand } from '../commands/process/info/info.js';
import { listCommand } from '../commands/process/list/list.js';
import { processCloseCommand } from '../commands/process/close/close.js';
import { actionCommand } from '../commands/action/action.js';

// All commands that opt into MCP (those with an `mcp` config)
const MCP_COMMANDS = [
  execCommand,
  logsCommand,
  queryCommand,
  screenshotCommand,
  infoCommand,
  listCommand,
  processCloseCommand,
  actionCommand,
];

// ---------------------------------------------------------------------------
// Tool registration
// ---------------------------------------------------------------------------

/**
 * Build the full set of MCP tool definitions from the command definitions.
 * Exported for testing — the server calls this internally.
 */
export function buildToolDefinitions(connection: BridgeConnection): McpToolDefinition[] {
  return buildMcpToolsFromRegistry(connection, MCP_COMMANDS);
}

// ---------------------------------------------------------------------------
// Server lifecycle
// ---------------------------------------------------------------------------

export interface McpServerOptions {
  /** Override for the bridge connection (useful for testing). */
  connection?: BridgeConnection;
}

/**
 * Start the MCP server. Connects to the bridge, registers tools, and
 * listens on stdio until the transport closes.
 */
export async function startMcpServerAsync(
  options: McpServerOptions = {},
): Promise<void> {
  const connection = options.connection ??
    await BridgeConnection.connectAsync({ keepAlive: true });

  const tools = buildToolDefinitions(connection);
  const toolMap = new Map(tools.map((t) => [t.name, t]));

  const server = new Server(
    { name: 'studio-bridge', version: '0.7.0' },
    { capabilities: { tools: {} } },
  );

  // tools/list
  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: tools.map((t) => ({
      name: t.name,
      description: t.description,
      inputSchema: t.inputSchema,
    })),
  }));

  // tools/call
  server.setRequestHandler(CallToolRequestSchema, async (request, _extra) => {
    const toolName = request.params.name;
    const tool = toolMap.get(toolName);

    if (!tool) {
      return {
        content: [{ type: 'text' as const, text: JSON.stringify({ error: `Unknown tool: ${toolName}` }) }],
        isError: true,
      };
    }

    const input = (request.params.arguments ?? {}) as Record<string, unknown>;
    const result = await tool.handler(input);
    return {
      content: result.content.map((block) => {
        if (block.type === 'image') {
          return { type: 'image' as const, data: block.data, mimeType: block.mimeType };
        }
        return { type: 'text' as const, text: block.text };
      }),
      isError: result.isError,
    };
  });

  const transport = new StdioServerTransport();
  await server.connect(transport);

  // Diagnostic output goes to stderr
  console.error('[studio-bridge mcp] Server started on stdio');

  // Keep alive until transport closes
  await new Promise<void>((resolve) => {
    transport.onclose = () => {
      resolve();
    };
  });

  await connection.disconnectAsync();
}
