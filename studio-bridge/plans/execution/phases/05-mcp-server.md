# Phase 5: MCP Integration

Goal: Expose all capabilities as MCP tools so AI agents (Claude Code, etc.) can discover and use them. The MCP server is a thin adapter over the same `CommandDefinition` handlers used by the CLI and terminal -- no separate business logic. Full design: `studio-bridge/plans/tech-specs/06-mcp-server.md`.

References:
- MCP server: `studio-bridge/plans/tech-specs/06-mcp-server.md`

Base path for all file references: `/workspaces/NevermoreEngine/tools/studio-bridge/`

Cross-references:
- Agent prompts: `studio-bridge/plans/execution/agent-prompts/05-mcp-server.md`
- Validation: `studio-bridge/plans/execution/validation/05-mcp-server.md`
- Depends on Phase 3 (all command handlers) and Task 1.7 -- see `01-bridge-network.md` and `03-commands.md`

---

### Dependency Changes

Phase 5 introduces a new runtime dependency:

| Package | Version constraint | Type | Notes |
|---------|-------------------|------|-------|
| `@modelcontextprotocol/sdk` | `^1` | `dependency` | Required at runtime for the MCP server (stdio transport, tool registration, JSON-RPC framing). This is a `dependency`, NOT a `devDependency`, because the MCP server runs as `studio-bridge mcp` in production. No peer dependencies required. |

Add this to `tools/studio-bridge/package.json` in Task 5.1 when creating the MCP server scaffold.

---

### Task 5.1: MCP server scaffold and mcp command

**Description**: Create an MCP server that runs as a long-lived process, registers with MCP-compatible clients, and shares session state with the CLI. The `studio-bridge mcp` command follows the `CommandDefinition` pattern (with `mcpEnabled: false` and `requiresSession: false`) and starts the MCP server via `startMcpServerAsync()`. See `06-mcp-server.md` section 5 for the server lifecycle.

**Files to create**:
- `src/mcp/mcp-server.ts` -- MCP server lifecycle (`startMcpServerAsync`), tool registration from `allCommands`, stdio transport setup. See `06-mcp-server.md` section 5.2.
- `src/mcp/index.ts` -- public exports.
- `src/commands/mcp.ts` -- `mcpCommand: CommandDefinition` with `requiresSession: false` and `mcpEnabled: false`. Calls `startMcpServerAsync()`.

**Files to modify**:
- `src/commands/index.ts` -- add `mcpCommand` to exports and `allCommands`.
- `package.json` -- add `@modelcontextprotocol/sdk` dependency.

**Dependencies**: Task 1.7 (command handler infrastructure), Phase 3 complete (all action handlers available).

**Complexity**: M

**Acceptance criteria**:
- `studio-bridge mcp` starts an MCP server communicating via stdio transport.
- The server connects to the bridge network via `BridgeConnection.connectAsync({ keepAlive: true })`.
- The server advertises tool definitions for all MCP-eligible commands (sessions, state, screenshot, logs, query, exec).
- The `mcp` command itself is NOT exposed as an MCP tool (`mcpEnabled: false`).
- The server stays alive as long as the MCP client is connected.
- Diagnostic logs go to stderr, not stdout (to avoid interfering with stdio transport).

### Task 5.2: MCP adapter (tool generation from CommandDefinitions)

**Description**: Implement the `createMcpTool` adapter that generates MCP tool definitions from `CommandDefinition` handlers. This is the third adapter alongside `createCliCommand` and `createDotCommandHandler`. Each MCP tool is generated -- NOT hand-written. See `06-mcp-server.md` section 4 and `02-command-system.md` section 10.

**Tools generated** (all from existing handlers via the adapter loop):
- `studio_sessions` -- from `sessionsCommand` in `src/commands/sessions.ts`
- `studio_state` -- from `stateCommand` in `src/commands/state.ts`
- `studio_screenshot` -- from `screenshotCommand` in `src/commands/screenshot.ts`
- `studio_logs` -- from `logsCommand` in `src/commands/logs.ts`
- `studio_query` -- from `queryCommand` in `src/commands/query.ts`
- `studio_exec` -- from `execCommand` in `src/commands/exec.ts`

**Files to create**:
- `src/mcp/adapters/mcp-adapter.ts` -- `createMcpTool(definition, connection)` that generates an MCP tool from a `CommandDefinition`. Handles session resolution via `resolveSessionAsync` with `interactive: false`, returns `data` as JSON in text content blocks, returns base64 image in image content blocks for screenshots, maps errors to `isError: true` tool results. See `06-mcp-server.md` section 4.

There are NO per-tool files. No `src/mcp/tools/studio-state-tool.ts`. No `src/mcp/tools/index.ts`. Tools are registered in the loop in `mcp-server.ts`.

**Dependencies**: Task 5.1, Task 1.7 (CommandDefinition types and adapters).

**Complexity**: M

**Acceptance criteria**:
- Each tool is generated from the same `CommandDefinition` handler used by the CLI and terminal -- no separate handler implementations exist.
- `createMcpTool` uses `mcpName` and `mcpDescription` from the definition when available, falling back to `studio_${name}` and `description`.
- Each tool has a JSON Schema for input and output (auto-generated from the `ArgSpec` array, with `sessionId` injected for session-requiring commands).
- Session resolution uses `resolveSessionAsync` with `interactive: false`.
- Script execution errors are returned as normal tool results with `success: false` (not `isError: true`). Infrastructure errors (no session, timeout, connection failure) use `isError: true`.
- `studio_screenshot` returns base64 image data in an MCP image content block (`type: 'image'`).
- All other tools return structured JSON in text content blocks.

### Task 5.3: MCP transport and configuration

**Description**: Support the stdio MCP transport (for Claude Code integration) via the `@modelcontextprotocol/sdk` library. Write a configuration example showing how to register studio-bridge as an MCP tool provider. See `06-mcp-server.md` section 8 for configuration details.

**Files to modify**:
- `src/mcp/mcp-server.ts` -- wire the `StdioServerTransport` from the MCP SDK.

**Dependencies**: Tasks 5.1, 5.2.

**Complexity**: S

**Acceptance criteria**:
- The MCP server communicates correctly over stdio (JSON-RPC) using `StdioServerTransport`.
- A Claude Code MCP configuration entry (`{ "command": "studio-bridge", "args": ["mcp"] }`) can discover all tools.
- The `--remote` flag on the `mcp` command connects to a remote bridge host (for devcontainer use).
- The `--log-level` flag controls diagnostic output on stderr.

### Parallelization within Phase 5

Task 5.1 must complete first. Tasks 5.2 and 5.3 depend on 5.1 but can be done in parallel.

```
5.1 (scaffold) --> 5.2 (tool definitions)
               --> 5.3 (transport)
```

---

## Testing Strategy (Phase 5)

See `06-mcp-server.md` section 11 for the full testing strategy.

**Unit tests**:
- `createMcpTool` generates correct tool name, description, input schema from a `CommandDefinition`.
- `createMcpTool` uses `mcpName`/`mcpDescription` overrides when set.
- Each MCP tool produces correct output for valid input (structured JSON, not formatted text).
- Each MCP tool returns `isError: true` for infrastructure failures (no session, timeout).
- Script execution errors return `success: false` in data (NOT `isError: true`).
- `studio_screenshot` returns an image content block (not text).
- Session auto-selection works within MCP context (`interactive: false`).
- Commands with `mcpEnabled: false` are not registered as MCP tools.

**Integration tests**:
- Start MCP server in subprocess, send `tools/list` via stdio, verify all expected tools listed.
- Send `tools/call` for each tool with mock bridge connection, verify structured JSON response.
- Send `tools/call` for unknown tool, verify JSON-RPC error response.

**Manual validation**:
- Register in Claude Code MCP configuration, verify tools appear.
- Call `studio_sessions`, `studio_exec`, `studio_screenshot` from Claude Code.

---

## Failure Modes

Default policy: **escalate integration issues to review agent, self-fix isolated issues.**

| Task | Likely Failure | Recovery Action |
|------|---------------|-----------------|
| 5.1 (MCP scaffold) | `@modelcontextprotocol/sdk` API has changed since the tech spec was written | Self-fix: check the SDK version pinned in `package.json`, consult SDK docs, and adapt. The SDK is stable but method names may differ. |
| 5.1 (MCP scaffold) | MCP server's `BridgeConnection` conflicts with the CLI's `BridgeConnection` when both run in the same process | Escalate: this is an architecture issue. The MCP server should use `BridgeConnection.connectAsync({ keepAlive: true })` and share the connection. If the connection model does not support this, review with the bridge module owner. |
| 5.1 (MCP scaffold) | Diagnostic logs on stderr interfere with MCP stdio transport | Self-fix: ensure all `console.log` calls go to stderr, not stdout. Add a `--silent` mode that suppresses all stderr output. |
| 5.2 (MCP adapter) | `createMcpTool` cannot generate JSON Schema from `ArgSpec` because the type information is insufficient | Self-fix: add explicit `jsonSchema` field to `ArgSpec` entries. Each command defines its own schema inline. |
| 5.2 (MCP adapter) | Session resolution with `interactive: false` throws instead of returning an error result | Self-fix: catch the resolution error and return it as an `isError: true` tool result with a descriptive message. |
| 5.2 (MCP adapter) | Screenshot base64 data is too large for an MCP response | Self-fix: check MCP response size limits. If exceeded, write to temp file and return the file path instead. |
| 5.3 (transport) | Claude Code MCP client does not discover tools because the `tools/list` response format is wrong | Self-fix: test with `echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | studio-bridge mcp` and verify the response matches the MCP spec. |
| 5.3 (transport) | `--remote` flag on `mcp` command does not work because `BridgeConnection` initialization happens before the flag is parsed | Self-fix: ensure connection is created lazily (on first tool call) or that the `--remote` flag is passed through `BridgeConnectionOptions`. |
