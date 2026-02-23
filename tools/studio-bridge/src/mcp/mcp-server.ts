/**
 * MCP server entry point. Creates a bridge connection, registers tools
 * that wrap existing command handlers via the generic adapter, and
 * communicates over stdio transport.
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
  listSessionsHandlerAsync,
  queryStateHandlerAsync,
  captureScreenshotHandlerAsync,
  queryLogsHandlerAsync,
  queryDataModelHandlerAsync,
  execHandlerAsync,
} from '../commands/index.js';
import { createMcpTool, type McpToolDefinition } from './adapters/mcp-adapter.js';
import type { OutputLevel } from '../server/web-socket-protocol.js';

// ---------------------------------------------------------------------------
// Tool schemas
// ---------------------------------------------------------------------------

const SESSION_PROPERTIES = {
  sessionId: {
    type: 'string',
    description: 'Target session ID. Omit to auto-select when only one session is connected.',
  },
  context: {
    type: 'string',
    enum: ['edit', 'client', 'server'],
    description: 'Target context within a Studio instance.',
  },
} as const;

// ---------------------------------------------------------------------------
// Tool registration
// ---------------------------------------------------------------------------

/**
 * Build the full set of MCP tool definitions from the command handlers.
 * Exported for testing — the server calls this internally.
 */
export function buildToolDefinitions(connection: BridgeConnection): McpToolDefinition[] {
  return [
    // ---- studio_sessions (no session needed) ----
    createMcpTool(connection, {
      name: 'studio_sessions',
      description: 'List active Roblox Studio sessions connected to the bridge.',
      inputSchema: {
        type: 'object',
        properties: {},
        additionalProperties: false,
      },
      needsSession: false,
      handler: listSessionsHandlerAsync,
      mapResult: (result) => [{
        type: 'text',
        text: JSON.stringify({ sessions: result.sessions, summary: result.summary }),
      }],
    }),

    // ---- studio_state ----
    createMcpTool(connection, {
      name: 'studio_state',
      description: 'Query the current Studio state (mode, place info) from a connected session.',
      inputSchema: {
        type: 'object',
        properties: {
          ...SESSION_PROPERTIES,
        },
        additionalProperties: false,
      },
      needsSession: true,
      handler: queryStateHandlerAsync,
      mapResult: (result) => [{
        type: 'text',
        text: JSON.stringify({
          state: result.state,
          placeId: result.placeId,
          placeName: result.placeName,
          gameId: result.gameId,
        }),
      }],
    }),

    // ---- studio_screenshot ----
    createMcpTool(connection, {
      name: 'studio_screenshot',
      description: 'Capture a viewport screenshot from a connected Studio session.',
      inputSchema: {
        type: 'object',
        properties: {
          ...SESSION_PROPERTIES,
        },
        additionalProperties: false,
      },
      needsSession: true,
      handler: captureScreenshotHandlerAsync,
      mapResult: (result) => {
        if (result.data) {
          return [{
            type: 'image',
            data: result.data,
            mimeType: 'image/png',
          }];
        }
        return [{
          type: 'text',
          text: JSON.stringify({ width: result.width, height: result.height, summary: result.summary }),
        }];
      },
    }),

    // ---- studio_logs ----
    createMcpTool(connection, {
      name: 'studio_logs',
      description: 'Retrieve buffered log history from a connected Studio session.',
      inputSchema: {
        type: 'object',
        properties: {
          ...SESSION_PROPERTIES,
          count: { type: 'number', description: 'Number of log entries to return (default 50).' },
          direction: { type: 'string', enum: ['head', 'tail'], description: 'Read from head (oldest) or tail (newest).' },
          levels: {
            type: 'array',
            items: { type: 'string' },
            description: 'Filter by output level (e.g. "Print", "Warning", "Error").',
          },
          includeInternal: { type: 'boolean', description: 'Include internal/system log messages.' },
        },
        additionalProperties: false,
      },
      needsSession: true,
      mapInput: (input) => ({
        count: input.count as number | undefined,
        direction: input.direction as 'head' | 'tail' | undefined,
        levels: input.levels as OutputLevel[] | undefined,
        includeInternal: input.includeInternal as boolean | undefined,
      }),
      handler: queryLogsHandlerAsync,
      mapResult: (result) => [{
        type: 'text',
        text: JSON.stringify({
          entries: result.entries,
          total: result.total,
          bufferCapacity: result.bufferCapacity,
        }),
      }],
    }),

    // ---- studio_query ----
    createMcpTool(connection, {
      name: 'studio_query',
      description: 'Query the Roblox DataModel instance tree from a connected Studio session.',
      inputSchema: {
        type: 'object',
        properties: {
          ...SESSION_PROPERTIES,
          path: { type: 'string', description: 'DataModel path to query (e.g. "Workspace" or "game.Workspace").' },
          depth: { type: 'number', description: 'How many levels of descendants to include.' },
          properties: {
            type: 'array',
            items: { type: 'string' },
            description: 'Property names to include. Omit to exclude properties.',
          },
          includeAttributes: { type: 'boolean', description: 'Include instance attributes.' },
          children: { type: 'boolean', description: 'Include direct children.' },
        },
        required: ['path'],
        additionalProperties: false,
      },
      needsSession: true,
      mapInput: (input) => ({
        path: input.path as string,
        depth: input.depth as number | undefined,
        properties: input.properties !== undefined ? true : undefined,
        attributes: input.includeAttributes as boolean | undefined,
        children: input.children as boolean | undefined,
      }),
      handler: queryDataModelHandlerAsync,
      mapResult: (result) => [{
        type: 'text',
        text: JSON.stringify({ node: result.node }),
      }],
    }),

    // ---- studio_exec ----
    createMcpTool(connection, {
      name: 'studio_exec',
      description: 'Execute inline Luau code in a connected Roblox Studio session.',
      inputSchema: {
        type: 'object',
        properties: {
          ...SESSION_PROPERTIES,
          script: { type: 'string', description: 'Luau source code to execute.' },
        },
        required: ['script'],
        additionalProperties: false,
      },
      needsSession: true,
      mapInput: (input) => ({
        scriptContent: input.script as string,
      }),
      handler: execHandlerAsync,
      mapResult: (result) => [{
        type: 'text',
        text: JSON.stringify({
          success: result.success,
          output: result.output,
          error: result.error,
        }),
      }],
    }),
  ];
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
