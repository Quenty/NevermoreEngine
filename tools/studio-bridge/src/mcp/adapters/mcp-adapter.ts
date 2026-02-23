/**
 * Generic adapter that creates MCP tool definitions from existing command
 * handlers. Each tool definition contains the tool metadata and a handler
 * function that bridges MCP input to the underlying command handler.
 *
 * This is the sole adapter — there are no per-tool files.
 */

import type { BridgeConnection } from '../../bridge/index.js';
import type { SessionContext } from '../../bridge/index.js';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

export type McpContentBlock =
  | { type: 'text'; text: string }
  | { type: 'image'; data: string; mimeType: string };

export interface McpToolResult {
  content: McpContentBlock[];
  isError?: boolean;
}

export interface McpToolDefinition {
  name: string;
  description: string;
  inputSchema: Record<string, unknown>;
  handler: (input: Record<string, unknown>) => Promise<McpToolResult>;
}

// ---------------------------------------------------------------------------
// Session-aware adapter options
// ---------------------------------------------------------------------------

export interface McpToolOptions<TOptions, TResult> {
  /** MCP tool name (e.g. "studio_exec"). */
  name: string;

  /** One-line description shown to MCP clients. */
  description: string;

  /** JSON Schema for the tool's input. */
  inputSchema: Record<string, unknown>;

  /** Whether this tool needs a resolved session (most do). */
  needsSession: boolean;

  /**
   * Map raw MCP input to the options the command handler expects.
   * Only called for tools that take options beyond session.
   */
  mapInput?: (input: Record<string, unknown>) => TOptions;

  /**
   * The command handler to invoke.
   * - For session-based tools: receives (session, options).
   * - For connection-based tools (needsSession=false): receives (connection).
   */
  handler: (...args: any[]) => Promise<TResult>;

  /**
   * Map the handler result into MCP content blocks.
   * Defaults to returning a single text block with JSON.stringify.
   */
  mapResult?: (result: TResult) => McpContentBlock[];
}

// ---------------------------------------------------------------------------
// Factory
// ---------------------------------------------------------------------------

/**
 * Create an MCP tool definition from a command handler. Handles session
 * resolution, error wrapping, and result formatting generically.
 */
export function createMcpTool<TOptions, TResult>(
  connection: BridgeConnection,
  options: McpToolOptions<TOptions, TResult>,
): McpToolDefinition {
  return {
    name: options.name,
    description: options.description,
    inputSchema: options.inputSchema,
    handler: async (input: Record<string, unknown>): Promise<McpToolResult> => {
      try {
        let result: TResult;

        if (options.needsSession) {
          const sessionId = input.sessionId as string | undefined;
          const context = input.context as SessionContext | undefined;
          const session = await connection.resolveSession(sessionId, context);

          const mapped = options.mapInput ? options.mapInput(input) : undefined;
          result = mapped !== undefined
            ? await options.handler(session, mapped)
            : await options.handler(session);
        } else {
          result = await options.handler(connection);
        }

        const content = options.mapResult
          ? options.mapResult(result)
          : [{ type: 'text' as const, text: JSON.stringify(result) }];

        return { content };
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : String(err);
        return {
          content: [{ type: 'text', text: JSON.stringify({ error: message }) }],
          isError: true,
        };
      }
    },
  };
}
