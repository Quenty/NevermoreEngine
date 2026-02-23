# Phase 5: MCP Integration -- Agent Prompts

**Phase reference**: [studio-bridge/plans/execution/phases/05-mcp-server.md](../phases/05-mcp-server.md)
**Validation**: [studio-bridge/plans/execution/validation/05-mcp-server.md](../validation/05-mcp-server.md)

Base path for all file references: `/workspaces/NevermoreEngine/tools/studio-bridge/`

## How to Use These Prompts

1. Copy the full prompt for a single task into a Claude Code sub-agent session.
2. The agent should read the "Read First" files, then implement the "Requirements" section.
3. The agent should run the acceptance criteria checks before reporting completion.
4. Do not give an agent a task whose dependencies have not been completed yet (see the dependency graph in [studio-bridge/plans/execution/phases/05-mcp-server.md](../phases/05-mcp-server.md)).

Key conventions that apply to every prompt:

- **TypeScript ESM** with `.js` extensions on all local imports (e.g., `import { Foo } from './foo.js';`)
- **`Async` suffix** on all async functions (e.g., `listSessionsAsync`, `resolveRequestAsync`)
- **Private `_` prefix** on all private fields and methods
- **vitest** for tests: `describe`/`it`/`expect`, test files named `*.test.ts` alongside source
- **No default exports** -- always use named exports
- **yargs `CommandModule` pattern** for CLI commands (class with `command`, `describe`, `builder`, `handler`)
- **`@quenty/` scoped packages** for workspace imports (e.g., `@quenty/cli-output-helpers`)
- **`OutputHelper`** from `@quenty/cli-output-helpers` for all user-facing output

---

## Handoff Notes for Tasks Requiring Orchestrator Coordination

### Task 5.1: MCP Server Scaffold

**Prerequisites**: Task 1.7a (shared CLI utilities) and Phase 3 (all action commands) must be completed first.

**Why requires coordination**: Code quality and SDK integration can be verified by a review agent. Claude Code validation (verifying tools appear and function correctly) is a separate validation step that requires a running Claude Code instance.

**Handoff**: Create `src/mcp/mcp-server.ts` with tool registration and request routing. Create `src/cli/commands/mcp-command.ts` for the `studio-bridge mcp` command. Use `@modelcontextprotocol/sdk` (the official MCP SDK) -- this is decided, not a choice. It handles JSON-RPC framing, stdio transport, tool/resource registration, and protocol negotiation. Import `Server` from `@modelcontextprotocol/sdk/server/index.js` and `StdioServerTransport` from `@modelcontextprotocol/sdk/server/stdio.js`. See `06-mcp-server.md` section 5.2 for the exact import pattern and server setup.

---

## Task 5.2: MCP Tool Definitions

**Prerequisites**: Tasks 5.1 (MCP server scaffold) and 1.7a (shared CLI utilities) must be completed first.

**Context**: Studio-bridge exposes capabilities to AI agents via the Model Context Protocol (MCP). Each tool maps to an existing server action. The MCP server scaffold (Task 5.1) provides the registration mechanism. This task defines the individual tool implementations.

**Objective**: Implement the six MCP tool handlers that map to studio-bridge actions.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/mcp/mcp-server.ts` (the MCP server scaffold from Task 5.1 -- must exist before this task)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/actions/query-state.ts` (action handler pattern)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/actions/query-logs.ts` (action handler pattern)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/bridge-connection.ts` (for session resolution via in-memory tracking)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/web-socket-protocol.ts` (v2 types)

**Files to Create**:
- `src/mcp/tools/studio-sessions-tool.ts`
- `src/mcp/tools/studio-state-tool.ts`
- `src/mcp/tools/studio-screenshot-tool.ts`
- `src/mcp/tools/studio-logs-tool.ts`
- `src/mcp/tools/studio-query-tool.ts`
- `src/mcp/tools/studio-exec-tool.ts`

**Requirements**:

1. Each tool file exports a tool definition object with:
   - `name: string` -- the MCP tool name (e.g., `'studio_sessions'`)
   - `description: string` -- human-readable description for tool discovery
   - `inputSchema: object` -- JSON Schema for the tool input
   - `handler: (input: Record<string, unknown>) => Promise<McpToolResponse>` -- the implementation

2. **`studio_sessions`** tool:
   - No input required (empty schema or optional `{}`).
   - Calls `BridgeConnection.listSessionsAsync()` to get all currently connected sessions.
   - Returns the array of sessions as JSON.

3. **`studio_state`** tool:
   - Input: `{ sessionId?: string }`
   - Resolves session (auto-select if one exists, error if multiple and no ID).
   - Calls `queryStateAsync`.
   - Returns state JSON.

4. **`studio_screenshot`** tool:
   - Input: `{ sessionId?: string }`
   - Calls `captureScreenshotAsync`.
   - Returns `{ data: <base64>, format: 'png', width, height }` as MCP image content.

5. **`studio_logs`** tool:
   - Input: `{ sessionId?: string, count?: number, levels?: string[] }`
   - Calls `queryLogsAsync`.
   - Returns entries as JSON.

6. **`studio_query`** tool:
   - Input: `{ sessionId?: string, path: string, depth?: number, properties?: string[], includeAttributes?: boolean }`
   - Calls `queryDataModelAsync`.
   - Returns the DataModel instance JSON.

7. **`studio_exec`** tool:
   - Input: `{ sessionId?: string, script: string }`
   - Calls `execAsync`.
   - Returns `{ success: boolean, logs: string }`.

8. Session resolution for all tools that require a session:
   - If `sessionId` is provided, find by ID.
   - If omitted and exactly one session exists, auto-select.
   - If omitted and multiple sessions exist, return an MCP error listing available sessions.
   - If omitted and zero sessions exist, return an MCP error.

9. Error handling:
   - Use structured MCP error responses, not process exits.
   - Timeout errors should include a clear message.

**Acceptance Criteria**:
- Each tool has a valid JSON Schema for input.
- Session auto-selection works correctly.
- Errors return structured MCP responses.
- `studio_screenshot` returns base64 image data.
- All tools return structured JSON, not formatted text.
- All tool files compile without errors.

**Do NOT**:
- Implement the MCP server scaffold (that is Task 5.1).
- Import `@modelcontextprotocol/sdk` types in the adapter layer -- define local interfaces to keep the adapter decoupled from the SDK.
- Use default exports.
- Forget `.js` extensions on local imports.

---

## Task 5.3: MCP Transport and Configuration

**Prerequisites**: Tasks 5.1 (MCP server scaffold) and 5.2 (MCP tool definitions) must be completed first.

**Context**: The MCP server needs to communicate with Claude Code and other MCP-compatible clients via the stdio transport (JSON-RPC over stdin/stdout). This task wires the transport into the MCP server.

**Objective**: Implement stdio transport for the MCP server so it can be registered as a Claude Code MCP tool provider.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/mcp/mcp-server.ts` (the MCP server from Task 5.1)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/cli.ts` (for the `mcp` command registration)

**Files to Create**:
- (no custom transport file needed -- use `StdioServerTransport` from `@modelcontextprotocol/sdk`)

**Files to Modify**:
- `src/mcp/mcp-server.ts` -- wire the stdio transport
- `src/cli/commands/mcp-command.ts` -- ensure the `mcp` command starts the server with stdio transport

**Requirements**:

1. Use the `@modelcontextprotocol/sdk` package's `StdioServerTransport` for the stdio transport. The SDK handles JSON-RPC framing and MCP lifecycle messages (`initialize`, `tools/list`, `tools/call`) automatically.

2. The `studio-bridge mcp` command:
   - Starts the MCP server with stdio transport.
   - The server stays alive as long as stdin is open.
   - On stdin close, the server shuts down gracefully.

3. The MCP server responds to:
   - `initialize` -- returns server info and capabilities.
   - `tools/list` -- returns the list of all tool definitions.
   - `tools/call` -- dispatches to the matching tool handler from Task 5.2.

**Acceptance Criteria**:
- `studio-bridge mcp` starts and communicates via stdio JSON-RPC.
- The MCP server correctly responds to `initialize`, `tools/list`, and `tools/call`.
- A Claude Code MCP configuration pointing to `studio-bridge mcp` discovers all six tools.
- The server shuts down cleanly when stdin closes.

**Do NOT**:
- Implement the tool handlers (that is Task 5.2).
- Use default exports.
- Forget `.js` extensions on local imports.
- Write to stderr in a way that would interfere with MCP JSON-RPC on stdout.

---

## Cross-References

- Phase plan: [studio-bridge/plans/execution/phases/05-mcp-server.md](../phases/05-mcp-server.md)
- Validation: [studio-bridge/plans/execution/validation/05-mcp-server.md](../validation/05-mcp-server.md)
- Tech spec: `studio-bridge/plans/tech-specs/06-mcp-server.md`
