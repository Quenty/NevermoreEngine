# Validation: Phase 6 -- Integration, Regression, Performance, and Security

> **Shared test infrastructure**: All tests that connect a mock plugin MUST use the standardized `MockPluginClient` from `shared-test-utilities.md`. Do not create ad-hoc WebSocket mocks. See [shared-test-utilities.md](./shared-test-utilities.md) for the full specification, usage examples, and design decisions.

Cross-cutting validation that spans multiple phases: bridge host failover e2e tests, regression tests, performance tests, and security tests.

**Phase**: 6 (Polish / Integration)

**References**:
- Phase plan: `studio-bridge/plans/execution/phases/06-integration.md`
- Agent prompts: `studio-bridge/plans/execution/agent-prompts/06-integration.md`
- Tech spec: `studio-bridge/plans/tech-specs/00-overview.md`
- Sibling validation: `01-bridge-network.md` through `05-mcp-server.md`
- Existing tests: `tools/studio-bridge/src/server/web-socket-protocol.test.ts`, `studio-bridge-server.test.ts`

Base path for source files: `/workspaces/NevermoreEngine/tools/studio-bridge/`

---

## 3. End-to-End Test Plans (continued)

### 3.3 Bridge Host Failover (end-to-end)

These tests complement the focused failover integration tests in section 1.4 (see `01-bridge-network.md`) by exercising failover in the context of real commands and session management -- not just raw bridge connections. They verify that the system recovers transparently from the user's perspective.

- **Test name**: `exec command succeeds after bridge host failover during idle`
- **Priority**: P0
- **Type**: e2e
- **Setup**: Start bridge host (implicit, via `BridgeConnection`). Connect mock plugin. Run `exec 'print("before")'` successfully. Kill the host. Use `vi.useFakeTimers()`.
- **Steps**:
  1. Execute a command successfully (establishes connection, plugin, session).
  2. Kill the bridge host process.
  3. `vi.advanceTimersByTime(5000)` to advance past recovery window.
  4. Run `exec 'print("after")'` (new CLI process).
  5. Verify the command succeeds.
- **Expected result**: New CLI becomes host, plugin reconnects, command output contains "after".
- **Automation**: vitest with `vi.useFakeTimers()` and mock plugin. Restore with `vi.useRealTimers()` in `afterEach`.

---

- **Test name**: `sessions command shows recovered session after failover`
- **Priority**: P1
- **Type**: e2e
- **Setup**: Start host, connect mock plugin, connect client. Kill host. Client takes over.
- **Steps**:
  1. After client becomes new host, run `sessions` command.
  2. Verify the mock plugin's session appears in the list.
- **Expected result**: Session list contains one session with correct metadata. No ghost sessions from before the failover.
- **Automation**: vitest.

---

- **Test name**: `terminal mode survives host failover and continues executing`
- **Priority**: P1
- **Type**: e2e
- **Setup**: Start `studio-bridge terminal` (becomes host). Connect mock plugin. Enter a command.
- **Steps**:
  1. Execute `print("before")` in terminal.
  2. Simulate host death (close transport server directly).
  3. Terminal process detects and recovers (rebinds port as host).
  4. Execute `print("after")` in terminal.
- **Expected result**: Second command succeeds. Terminal does not crash or hang.
- **Automation**: vitest with mock stdin/stdout.

---

- **Test name**: `MCP server reconnects after host failover`
- **Priority**: P2
- **Type**: e2e
- **Setup**: Start MCP server (as client). Start host separately. Connect mock plugin.
- **Steps**:
  1. Send `studio_state` MCP tool call -- succeeds.
  2. Kill the host.
  3. MCP server detects disconnect, takes over as host.
  4. Mock plugin reconnects.
  5. Send `studio_state` again.
- **Expected result**: Second tool call succeeds. MCP server did not crash or require restart.
- **Automation**: vitest with mock MCP transport.

---

## 4. Studio E2E Validation (Manual)

> This section consolidates all manual Studio testing deferred from Phases 2 and 3. These checks require a real Roblox Studio instance and cannot be automated with mock plugins. Perform these after all automated gates for Phases 1-5 have passed.

### 4.1 Plugin Installation and Discovery (from Phase 2)

1. Run `studio-bridge install-plugin` -- verify file appears in Studio plugins folder.
2. Open Studio -- verify `[StudioBridge]` messages in output log.
3. Start server (`studio-bridge launch`) -- verify plugin discovers and connects.
4. Run `studio-bridge sessions` -- verify session listed.
5. Run `studio-bridge exec --session <id> 'print("hello")'` -- verify output.

### 4.2 Plugin Reconnection (from Phase 2)

6. Kill server -- verify plugin enters reconnecting state (visible in Studio output).
7. Restart server -- verify plugin reconnects.

### 4.3 Multi-Context Detection (from Phase 2)

8. Enter Play mode -- verify 2 additional sessions appear (client, server contexts) in `studio-bridge sessions`.
9. Stop Play mode -- verify client/server sessions disappear, edit session remains.

**Studio test matrix for context detection** (verify all rows):

| Scenario | Expected edit context | Expected server context | Expected client context |
|----------|----------------------|------------------------|------------------------|
| Edit mode (no Play) | 1 session, state=Edit | none | none |
| Play mode (client+server) | 1 session, state=Play | 1 session, state=Run | 1 session, state=Play |
| Play Solo (server only) | 1 session, state=Play | 1 session, state=Run | none |
| Stop Play -> return to Edit | 1 session, state=Edit | disconnected | disconnected |
| Start Play -> Pause -> Resume | 1 session, state=Paused then Play | 1 session, state=Paused then Run | 1 session, state=Paused then Play |
| Rapid Play/Stop toggle (5x) | Survives, 1 session remains | Connects/disconnects cleanly each cycle | Connects/disconnects cleanly each cycle |

### 4.4 Action Handlers in Real Studio (from Phase 3)

10. `studio-bridge state` -- verify output matches Studio state.
11. `studio-bridge state --watch` -- change Studio mode (Play/Edit), verify updates appear.
12. `studio-bridge screenshot` -- verify PNG file is written and viewable.
13. `studio-bridge logs` -- verify output matches Studio output window.
14. `studio-bridge logs --follow` -- print something in Studio, verify it appears in the CLI.
15. `studio-bridge query Workspace` -- verify children listed.
16. `studio-bridge query Workspace.SpawnLocation --properties Position,Anchored` -- verify properties.
17. In terminal mode: `.state`, `.screenshot`, `.logs`, `.query Workspace` -- all work.

### 4.5 Context-Aware Commands in Real Studio (from Phase 3)

18. Enter Play mode in Studio -- verify `studio-bridge sessions` shows 3 sessions (edit/client/server) for the instance.
19. `studio-bridge exec --context server 'print(game:GetService("ServerStorage"))'` -- verify it runs against the server context.
20. `studio-bridge exec --context client 'print(game:GetService("Players").LocalPlayer)'` -- verify it runs against the client context.
21. `studio-bridge query --context server ServerStorage` -- verify server-only services are accessible.
22. `studio-bridge logs --context server` -- verify server-side logs are shown.
23. Stop Play mode -- verify client/server sessions disappear from `studio-bridge sessions`.

### 4.6 Failover Recovery in Real Studio

24. Start server, connect real Studio plugin, verify session active.
25. Kill server process -- verify plugin enters reconnecting state.
26. Start new CLI process -- verify it becomes host and plugin reconnects.
27. Run `studio-bridge exec 'print("after failover")'` -- verify command succeeds.

### 4.7 Sessions Command with Real Studio

28. Run `studio-bridge sessions` -- verify real Studio session appears with correct Place name, state, and context.
29. Run `studio-bridge sessions --json` -- verify JSON output includes all fields.
30. Run `studio-bridge sessions --watch` -- enter/exit Play mode, verify updates appear in real-time.

---

## 5. Regression Tests

### 5.1 Existing CLI Commands

These tests verify that commands that exist before the persistent sessions feature continue to work identically.

- **Test name**: `exec command works without --session flag when no sessions exist (launch mode)`
- **Priority**: P0
- **Type**: integration
- **Setup**: Empty session registry. Mock Studio launch.
- **Steps**:
  1. Call `studio-bridge exec 'print("hello")'` without `--session`.
- **Expected result**: Falls back to current behavior: launches Studio, injects temporary plugin, executes, returns output.
- **Automation**: vitest, existing test pattern from `studio-bridge-server.test.ts`.

---

- **Test name**: `run command reads file and executes`
- **Priority**: P0
- **Type**: integration
- **Setup**: Write a temp Lua file with `print("from file")`. Mock Studio launch.
- **Steps**:
  1. Call `studio-bridge run /tmp/test.lua`.
- **Expected result**: Script content is read and executed. Output contains "from file".
- **Automation**: vitest.

---

- **Test name**: `terminal command enters REPL in launch mode`
- **Priority**: P1
- **Type**: integration
- **Setup**: Empty session registry. Mock Studio launch.
- **Steps**:
  1. Start `studio-bridge terminal`.
  2. Verify it launches Studio and enters REPL.
- **Expected result**: REPL prompt appears after Studio launch and plugin handshake.
- **Automation**: vitest, mock stdin/stdout.

---

- **Test name**: `exec --place flag still works`
- **Priority**: P0
- **Type**: integration
- **Setup**: Mock Studio launch.
- **Steps**:
  1. Call `studio-bridge exec --place /path/to/Game.rbxl 'print("test")'`.
- **Expected result**: Server is created with the specified place path.
- **Automation**: vitest.

---

- **Test name**: `exec --timeout flag still works`
- **Priority**: P1
- **Type**: integration
- **Setup**: Mock Studio launch. Do not respond from mock plugin. Use `vi.useFakeTimers()`.
- **Steps**:
  1. Call `studio-bridge exec --timeout 200 'while true do end'`.
  2. `vi.advanceTimersByTime(200)` to trigger the timeout.
- **Expected result**: Rejects with timeout error.
- **Automation**: vitest with `vi.useFakeTimers()` and `vi.advanceTimersByTime()`. Restore with `vi.useRealTimers()` in `afterEach`.

### 5.2 Library API (LocalJobContext)

These verify the programmatic API used by other tools (e.g., `nevermore-cli`).

- **Test name**: `StudioBridge (re-exported as StudioBridge) constructor accepts same options as before`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. `new StudioBridge({ placePath: '/test.rbxl', timeoutMs: 5000 })` -- no errors.
- **Expected result**: Constructor does not throw. No new required options.
- **Automation**: vitest.

---

- **Test name**: `StudioBridge.startAsync + executeAsync + stopAsync lifecycle works`
- **Priority**: P0
- **Type**: integration
- **Setup**: Mocked external deps.
- **Steps**:
  1. Call `startAsync()`, connect mock plugin, `executeAsync({ scriptContent: '...' })`, `stopAsync()`.
- **Expected result**: Identical behavior to existing tests in `studio-bridge-server.test.ts`.
- **Automation**: vitest. This is effectively a duplicate of the existing test suite running against the modified code.

---

- **Test name**: `index.ts still exports all v1 types`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Import all v1 exports from `@quenty/studio-bridge`: `StudioBridge`, `StudioBridgeServerOptions`, `ExecuteOptions`, `StudioBridgeResult`, `StudioBridgePhase`, `OutputLevel`, `findStudioPathAsync`, `findPluginsFolder`, `launchStudioAsync`, `injectPluginAsync`, `encodeMessage`, `decodePluginMessage`, `PluginMessage`, `ServerMessage`, `HelloMessage`, `OutputMessage`, `ScriptCompleteMessage`, `WelcomeMessage`, `ExecuteMessage`, `ShutdownMessage`.
- **Expected result**: All imports resolve without errors.
- **Automation**: vitest, import assertion test.

---

- **Test name**: `index.ts also exports new v2 types`
- **Priority**: P1
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Import new exports: `BridgeConnection`, `BridgeSession`, `decodeServerMessage`, `RegisterMessage`, `StateResultMessage`, `ScreenshotResultMessage`, `DataModelResultMessage`, `LogsResultMessage`, `StateChangeMessage`, `HeartbeatMessage`, `SubscribeResultMessage`, `UnsubscribeResultMessage`, `PluginErrorMessage`, `QueryStateMessage`, `CaptureScreenshotMessage`, `QueryDataModelMessage`, `QueryLogsMessage`, `SubscribeMessage`, `UnsubscribeMessage`, `ServerErrorMessage`, `Capability`, `ErrorCode`, `StudioState`, `SerializedValue`, `DataModelInstance`.
- **Expected result**: All imports resolve.
- **Automation**: vitest.

### 5.3 Protocol v1 Backward Compatibility

- **Test name**: `v1 plugin (no protocolVersion) receives v1 welcome and can execute scripts`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start v2 server. Connect a v1 mock client.
- **Steps**:
  1. Send v1 `hello`.
  2. Receive v1 `welcome` (no `protocolVersion`, no `capabilities`).
  3. Receive `execute` message.
  4. Send `output` + `scriptComplete`.
- **Expected result**: Full v1 execute cycle works on the v2 server. No `requestId` on any message.
- **Automation**: vitest.

---

- **Test name**: `v1 plugin ignores unknown v2 messages gracefully`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start v2 server. Connect v1 mock client.
- **Steps**:
  1. Complete v1 handshake.
  2. Server accidentally sends a `queryState` message to the v1 client (this should never happen, but test robustness).
  3. v1 client's message handler encounters an unknown type.
- **Expected result**: The v1 client's decoder returns `null` for the unknown type. No crash. No disconnect.
- **Automation**: vitest.

---

- **Test name**: `v2 plugin sending heartbeat to v1 server does not crash`
- **Priority**: P1
- **Type**: integration
- **Setup**: Start a mock v1 server (existing code path). Connect v2 mock client.
- **Steps**:
  1. Complete handshake (v1 welcome).
  2. v2 client sends `heartbeat` message.
- **Expected result**: v1 server's `decodePluginMessage` returns `null` for heartbeat. Server ignores it. No error.
- **Automation**: vitest.

---

- **Test name**: `v2 plugin register to v1 server falls back to hello after 3 seconds`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start a mock v1 server that ignores `register` messages. Use `vi.useFakeTimers()`.
- **Steps**:
  1. Connect v2 mock client.
  2. v2 client sends `register`.
  3. `vi.advanceTimersByTime(3000)` to advance past the fallback timeout.
  4. Verify v2 client sends `hello` (fallback).
  5. v1 server sends v1 `welcome`.
- **Expected result**: Handshake completes after the fallback. Negotiated version is 1.
- **Automation**: vitest with `vi.useFakeTimers()` and `vi.advanceTimersByTime()`. Restore with `vi.useRealTimers()` in `afterEach`.

---

## 6. Performance Validation

- **Test name**: `PendingRequestMap handles 100 concurrent requests without degradation`
- **Priority**: P2
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Add 100 requests with 10-second timeouts.
  2. Resolve all 100 in random order.
  3. Measure total time.
- **Expected result**: All 100 resolve. Total time under 100ms (excluding timer overhead).
- **Automation**: vitest, `performance.now()`.

---

- **Test name**: `Session registry handles 50 concurrent sessions`
- **Priority**: P2
- **Type**: unit
- **Setup**: Temp directory.
- **Steps**:
  1. Register 50 sessions.
  2. Call `listSessionsAsync()`.
  3. Release all 50.
- **Expected result**: List returns 50 sessions. All cleanup succeeds.
- **Automation**: vitest.

---

- **Test name**: `Large screenshot payload (2MB base64) transmits without error`
- **Priority**: P1
- **Type**: integration
- **Setup**: Start server, connect v2 mock plugin.
- **Steps**:
  1. Send `captureScreenshot` to mock plugin.
  2. Mock plugin responds with 2MB base64 string in `screenshotResult`.
- **Expected result**: Server receives and parses the full payload. No WebSocket frame errors.
- **Automation**: vitest, generate 2MB base64 string.

---

- **Test name**: `DataModel query with depth=3 and 100+ instances serializes within timeout`
- **Priority**: P2
- **Type**: integration
- **Setup**: Mock plugin constructs a large DataModel response (100 instances, 3 levels deep).
- **Steps**:
  1. Send `queryDataModel` with `depth: 3`.
  2. Mock plugin responds with the large result.
- **Expected result**: Response arrives within 10-second timeout. JSON parsing succeeds.
- **Automation**: vitest.

---

- **Test name**: `Health endpoint responds under 50ms`
- **Priority**: P2
- **Type**: integration
- **Setup**: Start server.
- **Steps**:
  1. Measure time for `GET /health` response.
- **Expected result**: Under 50ms.
- **Automation**: vitest, `performance.now()`.

---

- **Test name**: `WebSocket connection + v2 handshake completes under 200ms`
- **Priority**: P2
- **Type**: integration
- **Setup**: Start server.
- **Steps**:
  1. Measure time from WebSocket connection start to receiving `welcome`.
- **Expected result**: Under 200ms on localhost.
- **Automation**: vitest, `performance.now()`.

---

## 7. Security Validation

- **Test name**: `WebSocket connection with incorrect session ID in URL is rejected`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start server with session ID `'abc-123'`.
- **Steps**:
  1. Connect WebSocket to `ws://localhost:{port}/wrong-id`.
- **Expected result**: Connection is rejected (HTTP 404 or WebSocket close). No handshake occurs.
- **Automation**: vitest. (This already exists in the current tests -- verify it still passes.)

---

- **Test name**: `WebSocket connection with correct URL but wrong sessionId in hello is rejected`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start server with session ID `'abc-123'`.
- **Steps**:
  1. Connect WebSocket to `ws://localhost:{port}/abc-123`.
  2. Send `hello` with `sessionId: 'wrong-id'` in the message body.
- **Expected result**: Server closes the connection. (This already exists in current tests.)
- **Automation**: vitest.

---

- **Test name**: `Session ID is a valid UUIDv4`
- **Priority**: P1
- **Type**: unit
- **Setup**: Create a `StudioBridgeServer` with default options (no explicit session ID).
- **Steps**:
  1. Inspect the auto-generated session ID.
- **Expected result**: Matches UUID v4 format: `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`.
- **Automation**: vitest, regex match.

---

- **Test name**: `Health endpoint does not leak sensitive information`
- **Priority**: P1
- **Type**: integration
- **Setup**: Start server.
- **Steps**:
  1. Call `GET /health`.
  2. Inspect response body.
- **Expected result**: Response contains only: `status`, `sessionId`, `port`, `protocolVersion`, `serverVersion`. No file paths, no PIDs, no auth tokens.
- **Automation**: vitest, verify exact keys.

---

- **Test name**: `Plugin error messages do not leak internal stack traces to CLI output`
- **Priority**: P1
- **Type**: integration
- **Setup**: Start server, connect v2 mock plugin.
- **Steps**:
  1. Send `queryDataModel` for a non-existent path.
  2. Mock plugin responds with `error` including `details: { internalStack: '...' }`.
  3. Verify the CLI-facing error message does not include the internal stack.
- **Expected result**: CLI error shows "No instance found at path: ..." without internal details.
- **Automation**: vitest, capture output.

---

- **Test name**: `Server rejects second plugin connection on same session`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start server, connect first mock plugin and complete handshake.
- **Steps**:
  1. Connect a second WebSocket client to the same URL.
  2. Send `hello` from the second client.
- **Expected result**: Server rejects or closes the second connection. First connection remains active.
- **Automation**: vitest.

---

- **Test name**: `execute payload does not allow script injection beyond the provided string`
- **Priority**: P1
- **Type**: integration
- **Setup**: Start server, connect mock plugin.
- **Steps**:
  1. Execute a script containing string interpolation attempts: `'print("hi"); --[[evil]]'`.
  2. Verify the mock plugin receives exactly the provided string in `payload.script`.
- **Expected result**: The script string is transmitted verbatim. No interpretation or modification.
- **Automation**: vitest.

---

- **Test name**: `Registry files have restrictive permissions (user-only read/write)`
- **Priority**: P2
- **Type**: unit
- **Setup**: Create a session file.
- **Steps**:
  1. Check file mode of the created session file.
- **Expected result**: File mode is `0o600` (owner read/write only) on Linux/macOS.
- **Automation**: vitest, `fs.statSync`, skip on Windows.

---

- **Test name**: `Daemon authentication token is required for CLI-to-daemon connections`
- **Priority**: P1
- **Type**: integration
- **Setup**: Start daemon with token written to session file.
- **Steps**:
  1. Connect CLI client without providing the token.
  2. Attempt to send a command.
- **Expected result**: Connection is rejected or command fails with auth error.
- **Automation**: vitest.

---

- **Test name**: `Daemon authentication token is accepted for valid CLI-to-daemon connections`
- **Priority**: P1
- **Type**: integration
- **Setup**: Start daemon. Read token from session file.
- **Steps**:
  1. Connect CLI client with the correct token.
  2. Send a command.
- **Expected result**: Command executes successfully.
- **Automation**: vitest.
