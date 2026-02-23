# MCP Server: Technical Specification

This document describes how studio-bridge exposes its capabilities as MCP (Model Context Protocol) tools for AI agents. The MCP server is a thin adapter over the same `CommandDefinition` handlers that the CLI and terminal use -- it does not contain its own business logic. This is the companion document referenced from `00-overview.md` and `02-command-system.md`.

References:
- PRD: `../prd/main.md` (feature F7: MCP Integration)
- Command system: `02-command-system.md` (unified handler pattern, adapter architecture)
- Protocol: `01-protocol.md` (wire protocol message types)
- Action specs: `04-action-specs.md` (per-action MCP tool schemas)

## 1. Purpose

The MCP server exposes studio-bridge capabilities as MCP tools so that AI agents (Claude Code, Cursor, etc.) can discover running Studio sessions, query state, capture screenshots, read logs, inspect the DataModel, and execute Luau scripts -- all through the standard MCP tool-calling interface.

The MCP server is one of three surfaces that consume the shared `CommandDefinition` handlers. It does not implement any business logic of its own. The architecture:

```
CommandDefinition (shared handler in src/commands/*.ts)
  |-- CLI adapter      -> yargs commands, formatted terminal output
  |-- Terminal adapter  -> dot-commands, REPL inline output
  |-- MCP adapter      -> MCP tools, structured JSON responses
```

Adding a new command to `src/commands/` and registering it in `allCommands` automatically makes it available as an MCP tool (unless explicitly opted out via `mcpEnabled: false`). No MCP-specific handler code is needed.

## 2. Architecture

### 2.1 Three-surface model

The MCP server follows the same adapter pattern as the CLI and terminal. Each surface is a thin translation layer between the surface-specific protocol and the shared handler:

| Concern | CLI adapter | Terminal adapter | MCP adapter |
|---------|------------|-----------------|-------------|
| Input parsing | yargs argv | dot-command string split | MCP tool input JSON |
| Session resolution | `resolveSessionAsync` with `interactive: process.stdout.isTTY` | Session already attached | `resolveSessionAsync` with `interactive: false` |
| Handler invocation | `cmd.handler(input, context)` | `cmd.handler(input, context)` | `cmd.handler(input, context)` |
| Output formatting | `summary` text or `JSON.stringify(data)` with `--json` | `summary` text | `JSON.stringify(data)` always (structured JSON) |
| Error handling | `OutputHelper.error()` + `process.exit(1)` | Inline error string | MCP error response with `isError: true` |
| Image handling | Write to file, print path | Write to file, print path | Return base64 in MCP image content block |

### 2.2 No business logic in the MCP layer

The MCP adapter (`src/mcp/adapters/mcp-adapter.ts`) is a generic function that operates on any `CommandDefinition`. It does not know what `queryStateAsync` or `captureScreenshotAsync` does. It:

1. Receives MCP tool input as JSON
2. Calls `resolveSessionAsync` if the command requires a session
3. Calls the command handler
4. Returns `result.data` as the MCP tool response

If you find yourself writing Studio-specific logic in `src/mcp/`, you are violating the golden rule from `02-command-system.md` section 2.

### 2.3 Relationship to BridgeConnection

The MCP server connects to the bridge network via `BridgeConnection.connectAsync()`, just like any other CLI process. It either becomes the bridge host (if no host is running) or connects as a client. This is transparent -- the MCP server does not know or care which role it has.

```
AI Agent (Claude Code)
    |
    | stdio (MCP protocol)
    |
MCP Server (studio-bridge mcp)
    |
    | BridgeConnection (host or client, transparent)
    |
Bridge Host (:38741)
    |
    +-- Plugin A (Studio 1)
    +-- Plugin B (Studio 2)
```

The MCP server is a long-lived process. It maintains a single `BridgeConnection` for its entire lifetime, reusing it across tool invocations. This means sessions discovered by one tool call are immediately available to subsequent calls without reconnection overhead.

## 3. MCP Tool Definitions

Each MCP-eligible command in `allCommands` generates one MCP tool. The tool name is `studio_${cmd.name}` by default (overridable via `mcpName` on the `CommandDefinition`). Commands with `mcpEnabled: false` are excluded.

### 3.1 `studio_sessions` -- List running sessions

**Wraps**: `sessionsCommand` from `src/commands/sessions.ts`

**Description**: List all running Roblox Studio sessions connected to studio-bridge. Returns session IDs, place names, Studio state, and connection metadata. Call this first to discover available sessions.

**Input schema**:
```json
{
  "type": "object",
  "properties": {},
  "additionalProperties": false
}
```

**Output format** (JSON in MCP text content block):

Single instance in Edit mode:
```json
{
  "sessions": [
    {
      "sessionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "placeName": "TestPlace.rbxl",
      "placeFile": "/Users/dev/game/TestPlace.rbxl",
      "context": "edit",
      "state": "Edit",
      "instanceId": "inst-001",
      "placeId": 1234567890,
      "gameId": 9876543210,
      "origin": "user",
      "uptimeMs": 150000
    }
  ]
}
```

Single instance in Play mode (3 sessions sharing an instanceId):
```json
{
  "sessions": [
    {
      "sessionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "placeName": "TestPlace.rbxl",
      "placeFile": "/Users/dev/game/TestPlace.rbxl",
      "context": "edit",
      "state": "Play",
      "instanceId": "inst-001",
      "placeId": 1234567890,
      "gameId": 9876543210,
      "origin": "user",
      "uptimeMs": 150000
    },
    {
      "sessionId": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
      "placeName": "TestPlace.rbxl",
      "placeFile": "/Users/dev/game/TestPlace.rbxl",
      "context": "server",
      "state": "Play",
      "instanceId": "inst-001",
      "placeId": 1234567890,
      "gameId": 9876543210,
      "origin": "user",
      "uptimeMs": 149800
    },
    {
      "sessionId": "c3d4e5f6-a7b8-9012-cdef-123456789012",
      "placeName": "TestPlace.rbxl",
      "placeFile": "/Users/dev/game/TestPlace.rbxl",
      "context": "client",
      "state": "Play",
      "instanceId": "inst-001",
      "placeId": 1234567890,
      "gameId": 9876543210,
      "origin": "user",
      "uptimeMs": 149800
    }
  ]
}
```

Sessions from the same Studio instance share an `instanceId`. In Play mode, the instance produces up to three sessions with different `context` values: `edit` (always present), `server`, and `client`.

**Error cases**:
- No bridge host running: descriptive error with guidance ("No bridge host running. Start Studio with the studio-bridge plugin installed, then try again.")
- Bridge host running, no plugins connected: descriptive error ("No active sessions. Is Studio running with the studio-bridge plugin installed?")

### 3.2 `studio_state` -- Query Studio state

**Wraps**: `stateCommand` from `src/commands/state.ts`

**Description**: Get the current state of a Roblox Studio session: run mode (Edit, Play, Paused, Run, Server, Client), place name, place ID, and game ID.

**Input schema**:
```json
{
  "type": "object",
  "properties": {
    "sessionId": {
      "type": "string",
      "description": "Target session ID. Optional if only one Studio instance is connected."
    },
    "context": {
      "type": "string",
      "enum": ["edit", "client", "server"],
      "description": "Target session context. Optional. Defaults to edit. Use server or client to target Play mode contexts."
    }
  },
  "additionalProperties": false
}
```

**Output format**:
```json
{
  "state": "Edit",
  "placeName": "TestPlace",
  "placeId": 1234567890,
  "gameId": 9876543210
}
```

**Error cases**:
- No sessions available: descriptive error with guidance
- Session not found: MCP `InvalidParams` error
- Plugin timeout: MCP `InternalError` error ("State query timed out after 5 seconds.")

### 3.3 `studio_screenshot` -- Capture viewport screenshot

**Wraps**: `screenshotCommand` from `src/commands/screenshot.ts`

**Description**: Capture a screenshot of the Roblox Studio 3D viewport. Returns the image as base64-encoded PNG data. Use this to see what the user sees in Studio.

**Input schema**:
```json
{
  "type": "object",
  "properties": {
    "sessionId": {
      "type": "string",
      "description": "Target session ID. Optional if only one Studio instance is connected."
    },
    "context": {
      "type": "string",
      "enum": ["edit", "client", "server"],
      "description": "Target session context. Optional. Defaults to edit. Use server or client to target Play mode contexts."
    }
  },
  "additionalProperties": false
}
```

**Output format**: MCP image content block (not a text content block):
```json
{
  "content": [
    {
      "type": "image",
      "data": "iVBORw0KGgoAAAANSUhEUgAA...",
      "mimeType": "image/png"
    }
  ]
}
```

The MCP adapter detects that the command is `screenshot` and returns an image content block instead of a text block. This allows MCP clients that support multimodal input (like Claude) to process the image directly.

**Error cases**:
- CaptureService call fails at runtime: tool result with `isError: true`
- Viewport not available: tool result with `isError: true`
- Plugin timeout: MCP `InternalError` error ("Screenshot capture timed out after 15 seconds.")

### 3.4 `studio_logs` -- Retrieve output logs

**Wraps**: `logsCommand` from `src/commands/logs.ts`

**Description**: Retrieve buffered output log lines from a Roblox Studio session. Returns recent log entries with timestamps and severity levels. Use this to check for errors, warnings, or print output.

**Input schema**:
```json
{
  "type": "object",
  "properties": {
    "sessionId": {
      "type": "string",
      "description": "Target session ID. Optional if only one Studio instance is connected."
    },
    "context": {
      "type": "string",
      "enum": ["edit", "client", "server"],
      "description": "Target session context. Optional. Defaults to edit. Use server or client to target Play mode contexts."
    },
    "count": {
      "type": "number",
      "description": "Maximum number of log entries to return. Default: 50.",
      "default": 50
    },
    "direction": {
      "type": "string",
      "enum": ["head", "tail"],
      "description": "Return oldest entries first ('head') or newest first ('tail'). Default: 'tail'.",
      "default": "tail"
    },
    "levels": {
      "type": "array",
      "items": { "type": "string", "enum": ["Print", "Info", "Warning", "Error"] },
      "description": "Filter by log level. Default: all levels."
    },
    "includeInternal": {
      "type": "boolean",
      "description": "Include internal [StudioBridge] messages. Default: false.",
      "default": false
    }
  },
  "additionalProperties": false
}
```

**Output format**:
```json
{
  "entries": [
    { "level": "Print", "body": "Hello from script", "timestamp": 12340 },
    { "level": "Warning", "body": "Infinite yield possible", "timestamp": 12345 }
  ],
  "total": 847,
  "bufferCapacity": 1000
}
```

MCP does not support follow/streaming mode. Each invocation returns a snapshot of the log buffer. Agents that need to monitor logs should poll `studio_logs` periodically.

**Error cases**:
- Plugin timeout: MCP `InternalError` error ("Log query timed out after 10 seconds.")

### 3.5 `studio_query` -- Query the DataModel

**Wraps**: `queryCommand` from `src/commands/query.ts`

**Description**: Query the Roblox DataModel to inspect instances, properties, attributes, and children. Use dot-separated paths like "Workspace.SpawnLocation" to navigate the instance tree. Returns structured JSON with class names, properties, and child counts.

**Input schema**:
```json
{
  "type": "object",
  "properties": {
    "sessionId": {
      "type": "string",
      "description": "Target session ID. Optional if only one Studio instance is connected."
    },
    "context": {
      "type": "string",
      "enum": ["edit", "client", "server"],
      "description": "Target session context. Optional. Defaults to edit. Use server or client to target Play mode contexts."
    },
    "path": {
      "type": "string",
      "description": "Dot-separated instance path, e.g. 'Workspace.SpawnLocation'. The 'game.' prefix is optional."
    },
    "depth": {
      "type": "number",
      "description": "Max child traversal depth. 0 = instance only, 1 = include children, etc. Default: 0.",
      "default": 0
    },
    "properties": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Specific property names to include. Default: Name, ClassName, Parent."
    },
    "includeAttributes": {
      "type": "boolean",
      "description": "Include all attributes on the instance. Default: false.",
      "default": false
    },
    "children": {
      "type": "boolean",
      "description": "List immediate children instead of querying the instance itself. Default: false.",
      "default": false
    },
    "listServices": {
      "type": "boolean",
      "description": "List all loaded services in the DataModel. Ignores path. Default: false.",
      "default": false
    }
  },
  "required": ["path"],
  "additionalProperties": false
}
```

**Output format**:
```json
{
  "instance": {
    "name": "SpawnLocation",
    "className": "SpawnLocation",
    "path": "game.Workspace.SpawnLocation",
    "properties": {
      "Position": { "type": "Vector3", "value": [0, 4, 0] },
      "Anchored": true
    },
    "attributes": {},
    "childCount": 0
  }
}
```

**Error cases**:
- Instance not found: tool result with `isError: true` ("No instance found at path: game.Workspace.NonExistent")
- Property not found: tool result with `isError: true`
- Plugin timeout: MCP `InternalError` error ("DataModel query timed out after 10 seconds.")

### 3.6 `studio_exec` -- Execute Luau script

**Wraps**: `execCommand` from `src/commands/exec.ts`

**Description**: Execute a Luau script in a Roblox Studio session. Returns the script's success status, any error message, and captured log output. Use this to run code, modify the game state, or perform actions that other tools cannot express.

**Input schema**:
```json
{
  "type": "object",
  "properties": {
    "sessionId": {
      "type": "string",
      "description": "Target session ID. Optional if only one Studio instance is connected."
    },
    "context": {
      "type": "string",
      "enum": ["edit", "client", "server"],
      "description": "Target session context. Optional. Defaults to server for exec (mutating command). Use edit or client to target other contexts in Play mode."
    },
    "script": {
      "type": "string",
      "description": "Luau code to execute in Studio."
    }
  },
  "required": ["script"],
  "additionalProperties": false
}
```

**Output format**:
```json
{
  "success": true,
  "logs": [
    { "level": "Print", "body": "Hello from Studio" }
  ]
}
```

On script error:
```json
{
  "success": false,
  "error": "Script:2: attempt to index nil with 'Name'",
  "logs": [
    { "level": "Print", "body": "Starting..." }
  ]
}
```

Script execution errors are returned as successful tool results with `success: false` in the data (not as MCP errors). This allows the agent to see the error message and partial output, then decide how to proceed.

**Error cases**:
- Plugin busy: tool result with `isError: true` ("Plugin is busy executing another script.")
- Plugin timeout: MCP `InternalError` error ("Script execution timed out after 120 seconds.")

## 4. MCP Adapter Implementation

The MCP adapter creates MCP tools from `CommandDefinition`s. It is a generic function that operates on any command -- it does not contain command-specific logic.

### 4.1 Core adapter function

```typescript
// src/mcp/adapters/mcp-adapter.ts

import type { CommandDefinition, CommandContext, CommandResult } from '../../commands/types.js';
import { resolveSessionAsync } from '../../commands/session-resolver.js';
import type { BridgeConnection } from '../../bridge/index.js';

export interface McpToolDefinition {
  name: string;
  description: string;
  inputSchema: object;
  handler: (input: Record<string, unknown>) => Promise<McpToolResult>;
}

export interface McpToolResult {
  content: McpContentBlock[];
  isError?: boolean;
}

export type McpContentBlock =
  | { type: 'text'; text: string }
  | { type: 'image'; data: string; mimeType: string };

export function createMcpTool<TInput, TOutput>(
  definition: CommandDefinition<TInput, TOutput>,
  connection: BridgeConnection
): McpToolDefinition {
  return {
    name: definition.mcpName ?? `studio_${definition.name}`,
    description: definition.mcpDescription ?? definition.description,
    inputSchema: buildJsonSchema(definition.args, definition.requiresSession),
    handler: async (input: Record<string, unknown>): Promise<McpToolResult> => {
      const context: CommandContext = { connection, interactive: false };

      if (definition.requiresSession) {
        const resolved = await resolveSessionAsync(connection, {
          sessionId: input.sessionId as string | undefined,
          context: input.context as SessionContext | undefined,
          interactive: false,
        });
        context.session = resolved.session;
        context.context = resolved.context;
      }

      try {
        const result = await definition.handler(input as TInput, context);
        const commandResult = result as CommandResult<unknown>;

        // Special case: screenshot returns an image content block
        if (definition.name === 'screenshot' && commandResult.data) {
          const data = commandResult.data as { base64Data?: string };
          if (data.base64Data) {
            return {
              content: [{
                type: 'image',
                data: data.base64Data,
                mimeType: 'image/png',
              }],
            };
          }
        }

        return {
          content: [{
            type: 'text',
            text: JSON.stringify(commandResult.data),
          }],
        };
      } catch (err) {
        return {
          content: [{
            type: 'text',
            text: JSON.stringify({
              error: err instanceof Error ? err.message : String(err),
            }),
          }],
          isError: true,
        };
      } finally {
        // MCP tools disconnect from user sessions after each call.
        // Managed sessions are not stopped (the MCP server does not own them).
        if (context.session && context.session.origin !== 'managed') {
          await context.session.disconnectAsync();
        }
      }
    },
  };
}
```

### 4.2 JSON schema generation from ArgSpec

The adapter generates MCP-compatible JSON Schema from the command's `ArgSpec` array. Session-requiring commands automatically receive optional `sessionId` and `context` parameters for session targeting.

```typescript
function buildJsonSchema(args: ArgSpec[], requiresSession: boolean): object {
  const properties: Record<string, object> = {};

  // Session-requiring commands get sessionId and context parameters automatically
  if (requiresSession) {
    properties.sessionId = {
      type: 'string',
      description: 'Target session ID. Optional if only one Studio instance is connected.',
    };
    properties.context = {
      type: 'string',
      enum: ['edit', 'client', 'server'],
      description: `Target session context. Optional. Defaults to ${cmd.defaultContext ?? 'edit'}. Use server or client to target Play mode contexts.`,
    };
  }

  const required: string[] = [];

  for (const arg of args) {
    properties[arg.name] = {
      type: arg.type,
      description: arg.description,
      ...(arg.default !== undefined ? { default: arg.default } : {}),
    };
    if (arg.required) {
      required.push(arg.name);
    }
  }

  return {
    type: 'object',
    properties,
    required: required.length > 0 ? required : undefined,
    additionalProperties: false,
  };
}
```

### 4.3 Screenshot handling

The `studio_screenshot` tool is the one case where the MCP adapter does something surface-specific: it returns an MCP image content block instead of a text content block.

When the MCP adapter invokes the screenshot handler, the handler returns a `CommandResult<ScreenshotOutput>` with `base64Data` in the data field. The adapter detects this (via the command name) and wraps it in an MCP image content block:

```typescript
{
  content: [{
    type: 'image',
    data: result.data.base64Data,  // raw base64 PNG
    mimeType: 'image/png',
  }]
}
```

The screenshot handler must be invoked with `base64: true` semantics when called from MCP (it should not write to a file). The MCP adapter passes `{ base64: true }` as part of the input to ensure the handler returns base64 data rather than a file path.

This is the ONLY command-specific behavior in the MCP adapter. It is a presentation concern (how to encode the response), not business logic.

## 5. MCP Server Implementation

### 5.1 Server lifecycle

The MCP server is started via the `studio-bridge mcp` CLI command:

```
$ studio-bridge mcp
```

This starts a long-lived process that:

1. Connects to the bridge network via `BridgeConnection.connectAsync({ keepAlive: true })`
2. Creates an MCP server instance using the MCP SDK (stdio transport)
3. Registers all MCP-eligible tools from `allCommands`
4. Listens for MCP tool invocations over stdio
5. Stays alive until the MCP client disconnects or the process is killed

The `mcp` command is itself a `CommandDefinition` in `src/commands/` with `requiresSession: false` and `mcpEnabled: false` (it would be nonsensical for the MCP server to expose itself as a tool).

### 5.2 Server entry point

```typescript
// src/mcp/mcp-server.ts

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { allCommands } from '../commands/index.js';
import { createMcpTool } from './adapters/mcp-adapter.js';
import { BridgeConnection } from '../bridge/index.js';

export async function startMcpServerAsync(): Promise<void> {
  const connection = await BridgeConnection.connectAsync({ keepAlive: true });

  const server = new Server(
    { name: 'studio-bridge', version: '1.0.0' },
    { capabilities: { tools: {} } }
  );

  // Register all MCP-eligible commands as tools
  const tools: McpToolDefinition[] = [];
  for (const cmd of allCommands.filter(c => c.mcpEnabled !== false)) {
    tools.push(createMcpTool(cmd, connection));
  }

  server.setRequestHandler('tools/list', async () => ({
    tools: tools.map(t => ({
      name: t.name,
      description: t.description,
      inputSchema: t.inputSchema,
    })),
  }));

  server.setRequestHandler('tools/call', async (request) => {
    const tool = tools.find(t => t.name === request.params.name);
    if (!tool) {
      throw new Error(`Unknown tool: ${request.params.name}`);
    }
    return tool.handler(request.params.arguments ?? {});
  });

  const transport = new StdioServerTransport();
  await server.connect(transport);

  // The server runs until the transport closes (MCP client disconnects)
  // or the process receives SIGTERM/SIGINT.
}
```

### 5.3 Registration loop

The registration loop filters `allCommands` by `mcpEnabled`:

```typescript
for (const cmd of allCommands.filter(c => c.mcpEnabled !== false)) {
  tools.push(createMcpTool(cmd, connection));
}
```

Commands excluded from MCP (`mcpEnabled: false`):
- `serve` -- process-level command (starts a bridge host). Not a session action.
- `install-plugin` -- local setup command. Requires user action (restarting Studio).
- `mcp` -- the MCP server itself. Cannot expose itself as a tool.
- `connect` -- enters interactive terminal mode. Not meaningful for MCP.
- `disconnect` -- terminal session management. Not meaningful for MCP.
- `launch` -- explicitly launches Studio. Agents should discover existing sessions instead.

Commands included in MCP (`mcpEnabled: true` or default):
- `sessions`, `state`, `screenshot`, `logs`, `query`, `exec`

### 5.4 Transport

The primary transport is **stdio** (standard input/output). This is the transport used by Claude Code and most MCP clients:

```
Claude Code <--stdio--> studio-bridge mcp <--BridgeConnection--> Bridge Host <--WebSocket--> Studio Plugin
```

The stdio transport reads JSON-RPC messages from stdin and writes responses to stdout. The MCP SDK handles framing and JSON-RPC protocol details.

An optional **SSE (Server-Sent Events)** transport could be added later for web-based MCP clients, but it is not required for the initial implementation. The architecture supports it because the MCP server and bridge connection are decoupled from the transport.

### 5.5 Shared bridge connection

The MCP server shares the bridge network with any co-running CLI processes. If the user has `studio-bridge terminal` open in one tab and Claude Code using the MCP server in another, both see the same sessions because they both connect to the same bridge host on port 38741.

The MCP server's `BridgeConnection` is created with `keepAlive: true` so the bridge host does not idle-exit while the MCP server is connected. This ensures sessions remain discoverable between tool invocations.

## 6. Session Auto-Selection

MCP tools accept optional `sessionId` and `context` parameters. The auto-selection heuristic matches the CLI behavior via `resolveSessionAsync`, using **instance-aware resolution**. Sessions are grouped by `instanceId` before applying the heuristic:

| Instances | `sessionId` | `context` | Behavior |
|-----------|------------|-----------|----------|
| 0 | no | any | Error: "No active sessions. Is Studio running with the studio-bridge plugin installed?" |
| 0 | yes | any | Error: "Session not found: {id}" |
| 1 (Edit mode) | no | not set | Auto-select the Edit session (zero-config) |
| 1 (Edit mode) | no | `edit` | Select Edit session |
| 1 (Edit mode) | no | `server`/`client` | Error: "No server/client context available. Studio is in Edit mode." |
| 1 (Play mode) | no | not set | Default to command's `defaultContext` (Edit for read-only commands, Server for mutating; see context default table in `04-action-specs.md`) |
| 1 (Play mode) | no | `server` | Select Server session |
| 1 (Play mode) | no | `client` | Select Client session |
| 1 | yes | any | Use specified session directly |
| N > 1 | no | any | Error: "Multiple Studio instances connected. Specify a sessionId." + session list in error details |
| N > 1 | yes | any | Use specified session directly |

When zero instances are available, the MCP server does NOT launch Studio (unlike the CLI's `exec` and `run` commands, which fall back to launching). Launching Studio is an action that requires user intent. The agent should inform the user to launch Studio instead.

The `interactive` flag is always `false` for MCP. There is no prompt, no user input. Ambiguity results in a descriptive error.

**Common MCP usage pattern for Play mode debugging**:
1. Agent calls `studio_sessions` to discover sessions and see their contexts.
2. Agent calls `studio_exec` with `context: "server"` to run server-side debugging code.
3. Agent calls `studio_logs` with `context: "client"` to check client-side output.

## 7. Error Mapping

Studio-bridge errors are mapped to MCP error responses. The MCP protocol uses `isError: true` on tool results for tool-level errors, and JSON-RPC error codes for protocol-level errors.

### 7.1 Tool-level errors (returned as tool results with `isError: true`)

These are errors that occur during tool execution. They are returned as normal tool results with `isError: true` so the agent can see the error message and decide how to proceed.

| Studio-bridge error | MCP tool result |
|--------------------|------------------------------------|
| No sessions available | `{ isError: true, content: [{ type: 'text', text: '{"error": "No active sessions. Is Studio running with the studio-bridge plugin installed?"}' }] }` |
| Session not found | `{ isError: true, content: [{ type: 'text', text: '{"error": "Session not found: {id}. Call studio_sessions to see available sessions."}' }] }` |
| Multiple instances, none specified | `{ isError: true, content: [{ type: 'text', text: '{"error": "Multiple Studio instances connected. Specify a sessionId.", "sessions": [...]}' }] }` |
| Context not available | `{ isError: true, content: [{ type: 'text', text: '{"error": "No server context available. Studio is in Edit mode. Use context: edit or omit context."}' }] }` |
| Plugin timeout | `{ isError: true, content: [{ type: 'text', text: '{"error": "State query timed out after 5 seconds."}' }] }` |
| Instance not found | `{ isError: true, content: [{ type: 'text', text: '{"error": "No instance found at path: game.Workspace.NonExistent"}' }] }` |
| Screenshot failed | `{ isError: true, content: [{ type: 'text', text: '{"error": "Screenshot capture failed: viewport is not available."}' }] }` |
| Script execution error | Normal result (not `isError`): `{ content: [{ type: 'text', text: '{"success": false, "error": "...", "logs": [...]}' }] }` |

Note that script execution errors (syntax errors, runtime errors) are NOT mapped to `isError: true`. They are returned as successful tool results with `success: false` in the data. This allows the agent to see the error message and partial output. `isError: true` is reserved for infrastructure failures (no session, timeout, connection error).

### 7.2 Protocol-level errors (JSON-RPC error codes)

These are errors in the MCP protocol itself, not in tool execution:

| Condition | JSON-RPC error code | Message |
|-----------|-------------------|---------|
| Unknown tool name | `-32602` (InvalidParams) | "Unknown tool: {name}" |
| Invalid input schema | `-32602` (InvalidParams) | "Invalid input: {validation error}" |
| Bridge connection failed | `-32603` (InternalError) | "Cannot connect to studio-bridge. Is the bridge host running?" |
| Unexpected server error | `-32603` (InternalError) | "Internal error: {message}" |

## 8. Configuration

### 8.1 Claude Code MCP configuration

To register studio-bridge as an MCP tool provider in Claude Code, add the following to your MCP configuration (e.g., `~/.claude/claude_desktop_config.json` or `.mcp.json` in the project root):

```json
{
  "mcpServers": {
    "studio-bridge": {
      "command": "studio-bridge",
      "args": ["mcp"]
    }
  }
}
```

If studio-bridge is installed locally (not globally), use the full path or `npx`:

```json
{
  "mcpServers": {
    "studio-bridge": {
      "command": "npx",
      "args": ["studio-bridge", "mcp"]
    }
  }
}
```

### 8.2 Split-server mode (devcontainer)

When using studio-bridge in a devcontainer with the bridge host running on the host OS, the MCP server should connect to the remote bridge host:

```json
{
  "mcpServers": {
    "studio-bridge": {
      "command": "studio-bridge",
      "args": ["mcp", "--remote", "localhost:38741"]
    }
  }
}
```

In most devcontainer setups, port 38741 is automatically forwarded, so the default configuration (without `--remote`) works.

### 8.3 MCP command flags

The `studio-bridge mcp` command accepts these flags:

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--remote` | string | (auto) | Connect to a remote bridge host instead of local |
| `--port` | number | 38741 | Bridge host port |
| `--log-level` | string | `error` | Log level for MCP server diagnostics (written to stderr) |

Diagnostic logs are written to stderr (not stdout) to avoid interfering with the MCP stdio transport on stdout.

## 9. File Layout

The MCP server adds a minimal set of files:

```
src/
  mcp/
    mcp-server.ts               MCP server lifecycle (startMcpServerAsync), tool registration
    adapters/
      mcp-adapter.ts            createMcpTool() -- generic adapter: CommandDefinition -> MCP tool
    index.ts                    Public exports
  commands/
    mcp.ts                      'studio-bridge mcp' command handler (mcpEnabled: false)
  cli/
    (no changes)                cli.ts already loops over allCommands
```

There are no per-command MCP tool files. `studio-state-tool.ts`, `studio-exec-tool.ts`, etc. do NOT exist. Each tool is generated from the corresponding `CommandDefinition` by `createMcpTool`. See `02-command-system.md` section 3.4 for why.

### 9.1 What does NOT exist

To be explicit:

- `src/mcp/tools/studio-state-tool.ts` -- does not exist. No per-tool files.
- `src/mcp/tools/studio-exec-tool.ts` -- does not exist.
- `src/mcp/tools/studio-screenshot-tool.ts` -- does not exist.
- `src/mcp/tools/index.ts` -- does not exist. Tools are registered in the loop in `mcp-server.ts`.
- `src/mcp/session-resolver.ts` -- does not exist. Uses `resolveSessionAsync` from `src/commands/session-resolver.ts`.

## 10. Dependencies

### 10.1 MCP SDK

The MCP server uses the `@modelcontextprotocol/sdk` package for protocol handling and transport:

```json
{
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0"
  }
}
```

The SDK provides:
- `Server` class for handling MCP protocol requests
- `StdioServerTransport` for stdio communication
- Type definitions for MCP messages

### 10.2 Internal dependencies

The MCP server depends on:
- `src/commands/index.ts` -- the `allCommands` registry
- `src/commands/types.ts` -- `CommandDefinition`, `CommandContext`, `CommandResult`
- `src/commands/session-resolver.ts` -- `resolveSessionAsync`
- `src/bridge/index.ts` -- `BridgeConnection`, `BridgeSession`

It does NOT depend on:
- `src/cli/` -- no CLI-specific code
- `src/bridge/internal/` -- no internal networking code
- `src/server/` -- no direct server interaction (goes through `BridgeSession`)

## 11. Testing Strategy

### 11.1 Unit tests

- `mcp-adapter.test.ts`: Verify `createMcpTool` generates correct tool name, description, input schema from a `CommandDefinition`. Verify handler calls `resolveSessionAsync` and the command handler, and returns structured JSON. Verify screenshot returns image content block.

### 11.2 Integration tests

- Start MCP server in a subprocess, send `tools/list` request via stdio, verify all expected tools are listed with correct schemas.
- Send `tools/call` for `studio_sessions` with a mock bridge connection, verify structured JSON response.
- Send `tools/call` for `studio_state` with a mock session, verify state data is returned.
- Send `tools/call` for an unknown tool name, verify error response with correct JSON-RPC error code.
- Send `tools/call` for `studio_exec` with a script that errors, verify `success: false` is in the result (not `isError: true`).

### 11.3 Manual validation

- Register in Claude Code MCP configuration, verify tools appear in the tool list.
- Call `studio_sessions` from Claude Code, verify session list is returned.
- Call `studio_exec` from Claude Code with `print("hello")`, verify output appears.
- Call `studio_screenshot` from Claude Code, verify image is displayed inline.
