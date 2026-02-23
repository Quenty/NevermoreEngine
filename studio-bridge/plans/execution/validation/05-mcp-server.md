# Validation: Phase 5 -- MCP Integration

> **Shared test infrastructure**: All tests that connect a mock plugin MUST use the standardized `MockPluginClient` from `shared-test-utilities.md`. Do not create ad-hoc WebSocket mocks. See [shared-test-utilities.md](./shared-test-utilities.md) for the full specification, usage examples, and design decisions.

Test specifications for MCP server: tool listing, tool calls, session auto-selection.

**Phase**: 5 (MCP Integration)

**References**:
- Phase plan: `studio-bridge/plans/execution/phases/05-mcp-server.md`
- Agent prompts: `studio-bridge/plans/execution/agent-prompts/05-mcp-server.md`
- Tech spec: `studio-bridge/plans/tech-specs/06-mcp-server.md`
- Sibling validation: `03-commands.md` (Phase 3), `04-split-server.md` (Phase 4)

Base path for source files: `/workspaces/NevermoreEngine/tools/studio-bridge/`

---

## 3. End-to-End Test Plans (continued)

### 3.5 MCP Integration

- **Test name**: `MCP server advertises all six tools on initialization`
- **Priority**: P1
- **Type**: e2e
- **Setup**: Start MCP server in-process via stdio transport mock.
- **Steps**:
  1. Send MCP `tools/list` request.
  2. Parse the response.
- **Expected result**: Response contains `studio_sessions`, `studio_state`, `studio_screenshot`, `studio_logs`, `studio_query`, `studio_exec`.
- **Automation**: vitest, mock stdio transport.

---

- **Test name**: `MCP studio_exec tool executes script and returns structured result`
- **Priority**: P1
- **Type**: e2e
- **Setup**: Start MCP server. Start bridge server with mock plugin.
- **Steps**:
  1. Send MCP `tools/call` with `studio_exec` tool and `{ script: 'print("hi")' }`.
  2. Mock plugin responds with output + scriptComplete.
- **Expected result**: MCP response contains `{ success: true, logs: [{ level: 'Print', body: 'hi' }] }`.
- **Automation**: vitest.

---

- **Test name**: `MCP studio_state tool returns state JSON`
- **Priority**: P1
- **Type**: e2e
- **Setup**: Same as above.
- **Steps**:
  1. Send MCP `tools/call` with `studio_state`.
  2. Mock plugin responds with stateResult.
- **Expected result**: MCP response contains `{ state: 'Edit', placeName: 'Test', placeId: 123, gameId: 456 }`.
- **Automation**: vitest.

---

- **Test name**: `MCP studio_screenshot tool returns base64 image`
- **Priority**: P1
- **Type**: e2e
- **Setup**: Same as above.
- **Steps**:
  1. Send MCP `tools/call` with `studio_screenshot`.
  2. Mock plugin responds with screenshotResult.
- **Expected result**: MCP response contains base64 image data with correct format and dimensions.
- **Automation**: vitest.

---

- **Test name**: `MCP session auto-selection: errors when multiple sessions exist and no sessionId provided`
- **Priority**: P1
- **Type**: e2e
- **Setup**: Register two sessions in the registry.
- **Steps**:
  1. Send MCP `tools/call` with `studio_state` and no `sessionId` input.
- **Expected result**: MCP error response listing available sessions.
- **Automation**: vitest.

---

- **Test name**: `MCP session auto-selection: auto-selects when exactly one session exists`
- **Priority**: P1
- **Type**: e2e
- **Setup**: Register one session.
- **Steps**:
  1. Send MCP `tools/call` with `studio_state` and no `sessionId`.
- **Expected result**: Successfully queries the single session.
- **Automation**: vitest.

---

## Phase 5 Gate

**Criteria**: MCP server works. All six tools respond correctly. Session resolution works in MCP context.

**Required passing tests**:
1. All Phase 4 gate tests (see `04-split-server.md`).
2. MCP tool listing (3.5).
3. MCP `studio_exec` (3.5).
4. MCP `studio_state` (3.5).
5. MCP `studio_screenshot` (3.5).
6. MCP session auto-selection: single session (3.5).
7. MCP session auto-selection: multiple sessions error (3.5).

8. MCP `studio_screenshot` with a realistic Studio viewport (3D scene with parts, lighting, terrain) -- verify the base64 payload decodes to a valid PNG and the total MCP response (including JSON framing) stays under the 16 MB WebSocket payload limit (3.5). Typical viewport screenshots are 1-3 MB as PNG; verify the base64-encoded version (~1.3x overhead) plus JSON framing fits comfortably.

**Manual verification**:
1. Configure Claude Code MCP with `studio-bridge mcp` entry.
2. Verify Claude Code discovers all six tools.
3. Use `studio_exec` from Claude Code to run a script in Studio.
4. Use `studio_state` from Claude Code to check Studio state.
