/**
 * MCP adapter — converts a `CommandDefinition` into an `McpToolDefinition`.
 *
 * Generates tool names as `studio_{group}_{name}` (or `studio_{name}` for
 * top-level commands). Builds JSON Schema from `ArgDefinition` records and
 * injects `sessionId`/`context` for session-scoped tools.
 */

import type { BridgeConnection, SessionContext } from '../../bridge/index.js';
import type { CommandDefinition } from '../../commands/framework/define-command.js';
import { toJsonSchema } from '../../commands/framework/arg-builder.js';
import type {
  McpToolDefinition,
  McpToolResult,
  McpContentBlock,
} from './mcp-adapter.js';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Build an MCP tool definition from a command definition. Returns
 * `undefined` if the command has no `mcp` config (opted out of MCP).
 */
export function buildMcpToolFromDefinition(
  connection: BridgeConnection,
  def: CommandDefinition,
): McpToolDefinition | undefined {
  if (!def.mcp) return undefined;

  const toolName = def.mcp.toolName ?? generateToolName(def);
  const inputSchema = buildInputSchema(def);

  return {
    name: toolName,
    description: def.description,
    inputSchema,
    handler: async (input: Record<string, unknown>): Promise<McpToolResult> => {
      try {
        // Map input to handler args
        const commandArgs = def.mcp!.mapInput
          ? def.mcp!.mapInput(input)
          : extractCommandArgs(def, input);

        let result: unknown;

        if (def.scope === 'session') {
          const sessionId = input.sessionId as string | undefined;
          const context = input.context as SessionContext | undefined;
          const session = await connection.resolveSessionAsync(
            sessionId,
            context,
          );
          result = await (def.handler as any)(session, commandArgs);
        } else if (def.scope === 'connection') {
          result = await (def.handler as any)(connection, commandArgs);
        } else {
          result = await (def.handler as any)(commandArgs);
        }

        const content: McpContentBlock[] = def.mcp!.mapResult
          ? def.mcp!.mapResult(result as any)
          : [{ type: 'text' as const, text: JSON.stringify(result) }];

        return { content };
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : String(err);
        return {
          content: [
            { type: 'text', text: JSON.stringify({ error: message }) },
          ],
          isError: true,
        };
      }
    },
  };
}

/**
 * Build MCP tool definitions for all commands in the registry that
 * have an `mcp` config.
 */
export function buildMcpToolsFromRegistry(
  connection: BridgeConnection,
  defs: readonly CommandDefinition[],
): McpToolDefinition[] {
  const tools: McpToolDefinition[] = [];
  for (const def of defs) {
    const tool = buildMcpToolFromDefinition(connection, def);
    if (tool) tools.push(tool);
  }
  return tools;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function generateToolName(def: CommandDefinition): string {
  if (def.group) {
    return `studio_${def.group}_${def.name}`;
  }
  return `studio_${def.name}`;
}

function buildInputSchema(def: CommandDefinition): Record<string, unknown> {
  const base = toJsonSchema(def.args);
  const schema: {
    type: string;
    properties: Record<string, Record<string, unknown>>;
    required?: string[];
    additionalProperties: boolean;
  } = { ...base };

  // Inject session targeting for session/connection scoped commands
  if (def.scope === 'session' || def.scope === 'connection') {
    schema.properties.sessionId = {
      type: 'string',
      description:
        'Target session ID. Omit to auto-select when only one session is connected.',
    };
    schema.properties.context = {
      type: 'string',
      enum: ['edit', 'client', 'server'],
      description: 'Target context within a Studio instance.',
    };
  }

  return schema;
}

function extractCommandArgs(
  def: CommandDefinition,
  input: Record<string, unknown>,
): Record<string, unknown> {
  const args: Record<string, unknown> = {};
  for (const name of Object.keys(def.args)) {
    if (name in input) {
      args[name] = input[name];
    }
  }
  return args;
}
