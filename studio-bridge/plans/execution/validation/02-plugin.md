# Validation: Phase 2 -- Persistent Plugin

> **Shared test infrastructure**: All tests that connect a mock plugin MUST use the standardized `MockPluginClient` from `shared-test-utilities.md`. Do not create ad-hoc WebSocket mocks. See [shared-test-utilities.md](./shared-test-utilities.md) for the full specification, usage examples, and design decisions.

Test specifications for persistent plugin integration: server + mock plugin handshake, session lifecycle, health endpoint, plugin discovery, and launch flow.

**Phase**: 2 (Persistent Plugin)

**References**:
- Phase plan: `studio-bridge/plans/execution/phases/02-plugin.md`
- Agent prompts: `studio-bridge/plans/execution/agent-prompts/02-plugin.md`
- Tech specs: `studio-bridge/plans/tech-specs/03-persistent-plugin.md`, `studio-bridge/plans/tech-specs/04-action-specs.md`
- Sibling validation: `01-bridge-network.md` (Phase 1), `03-commands.md` (Phase 3)
- Existing tests: `tools/studio-bridge/src/server/web-socket-protocol.test.ts`, `studio-bridge-server.test.ts`

Base path for source files: `/workspaces/NevermoreEngine/tools/studio-bridge/`

---

## 2. Integration Test Plans

### 2.1 Server + Mock Plugin

These tests start a real `StudioBridgeServer` and connect a mock WebSocket client that simulates a v2 plugin.

#### 2.1.1 v2 handshake via register message

- **Test name**: `server accepts register message and responds with v2 welcome`
- **Priority**: P0
- **Type**: integration
- **Setup**: Create `StudioBridgeServer` with mocked external deps. Start server.
- **Steps**:
  1. Connect a WebSocket client to `ws://localhost:{port}/{sessionId}`.
  2. Send `register` message with `protocolVersion: 2`, capabilities, and full payload.
  3. Wait for response.
- **Expected result**: Server sends `welcome` with `protocolVersion: 2` and `capabilities` matching the intersection of plugin and server capabilities.
- **Automation**: vitest, real WebSocket connection, mocked Studio launch.

#### 2.1.2 v2 handshake via extended hello

- **Test name**: `server accepts extended hello with protocolVersion and capabilities`
- **Priority**: P0
- **Type**: integration
- **Setup**: Same as 2.1.1.
- **Steps**:
  1. Connect a WebSocket client.
  2. Send `hello` with `protocolVersion: 2`, `capabilities: ['execute', 'queryState']`, `pluginVersion: '1.0.0'`.
  3. Wait for response.
- **Expected result**: Server sends `welcome` with `protocolVersion: 2` and `capabilities: ['execute', 'queryState']`.
- **Automation**: vitest.

#### 2.1.3 v1 hello still works on v2 server

- **Test name**: `server responds with v1 welcome when plugin sends hello without protocolVersion`
- **Priority**: P0
- **Type**: integration
- **Setup**: Same as 2.1.1.
- **Steps**:
  1. Connect a WebSocket client.
  2. Send v1-style `hello` (no `protocolVersion`, no `capabilities`).
  3. Wait for response.
- **Expected result**: Server sends v1-style `welcome` (no `protocolVersion` field, no `capabilities` field).
- **Automation**: vitest.

#### 2.1.3.1 Multi-context register messages

- **Test name**: `server accepts register messages with context field and groups by instanceId`
- **Priority**: P0
- **Type**: integration
- **Setup**: Create `StudioBridgeServer`. Start server.
- **Steps**:
  1. Connect 3 WebSocket clients, each sending `register` with `instanceId: 'inst-1'` and different `context` values (`edit`, `client`, `server`), plus `placeId: 123` and `gameId: 456`.
  2. Query the server's session list.
- **Expected result**: Server has 3 sessions, all with `instanceId: 'inst-1'`, each with a distinct `context`. All share the same `placeId` and `gameId`.
- **Automation**: vitest, real WebSocket connections.

---

- **Test name**: `server handles Play mode lifecycle: edit session exists, then client/server join, then client/server leave`
- **Priority**: P0
- **Type**: integration
- **Setup**: Create server. Connect one mock plugin with `context: 'edit'`.
- **Steps**:
  1. Verify 1 session (edit).
  2. Connect 2 more mock plugins with same `instanceId`, contexts `client` and `server`.
  3. Verify 3 sessions.
  4. Disconnect the `client` and `server` plugins (simulating Stop Play).
  5. Verify 1 session remains (edit).
- **Expected result**: Session count tracks Play mode enter/exit correctly.
- **Automation**: vitest.

---

- **Test name**: `server sends welcome with context acknowledgment to each register`
- **Priority**: P1
- **Type**: integration
- **Setup**: Start server. Connect a mock plugin sending `register` with `context: 'server'`.
- **Steps**:
  1. Wait for `welcome` response.
- **Expected result**: `welcome` message is sent. Server internally records the session's context as `'server'`.
- **Automation**: vitest.

---

- **Test name**: `register message without context field defaults to 'edit'`
- **Priority**: P1
- **Type**: integration
- **Setup**: Start server. Connect a mock plugin sending `register` without the `context` field (backwards compatibility).
- **Steps**:
  1. Wait for registration.
  2. Query server session list.
- **Expected result**: Session has `context: 'edit'` (default).
- **Automation**: vitest.

#### 2.1.4 Heartbeat tracking

- **Test name**: `server updates heartbeat timestamp when heartbeat message arrives`
- **Priority**: P1
- **Type**: integration
- **Setup**: Establish v2 connection.
- **Steps**:
  1. Send `heartbeat` message with `uptimeMs: 15000`, `state: 'Edit'`, `pendingRequests: 0`.
  2. Check the server's internal heartbeat timestamp (access via test helper or exposed method).
- **Expected result**: Last heartbeat timestamp is updated.
- **Automation**: vitest, access private field or add a test-only getter.

#### 2.1.5 performActionAsync end-to-end with mock plugin

- **Test name**: `performActionAsync sends queryState and resolves when mock plugin responds`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start server, connect v2 mock client.
- **Steps**:
  1. Call `server.performActionAsync({ type: 'queryState', ... })`.
  2. On the mock client, receive the `queryState` message with a `requestId`.
  3. Mock client sends `stateResult` with the same `requestId`.
- **Expected result**: `performActionAsync` resolves with the stateResult payload.
- **Automation**: vitest, real WebSocket.

---

- **Test name**: `performActionAsync rejects when mock plugin sends error`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start server, connect v2 mock client.
- **Steps**:
  1. Call `server.performActionAsync({ type: 'queryDataModel', ... })`.
  2. Mock client sends `error` with matching `requestId` and code `INSTANCE_NOT_FOUND`.
- **Expected result**: `performActionAsync` rejects with error containing the code and message.
- **Automation**: vitest.

---

- **Test name**: `performActionAsync rejects on timeout when mock plugin does not respond`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start server, connect v2 mock client. Use `vi.useFakeTimers()`.
- **Steps**:
  1. Call `server.performActionAsync({ type: 'queryState', ... })` with a timeout of 200ms.
  2. Do not respond from mock client.
  3. `vi.advanceTimersByTime(200)` to trigger the timeout.
- **Expected result**: Promise rejects with timeout error.
- **Automation**: vitest with `vi.useFakeTimers()` and `vi.advanceTimersByTime()`. Restore with `vi.useRealTimers()` in `afterEach`.

---

- **Test name**: `performActionAsync throws when v1 plugin is connected`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start server, connect v1 client (no capabilities).
- **Steps**:
  1. Call `server.performActionAsync({ type: 'queryState', ... })`.
- **Expected result**: Throws immediately with "Plugin does not support v2 actions".
- **Automation**: vitest.

---

- **Test name**: `performActionAsync throws for unsupported capability`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start server, connect v2 client with `capabilities: ['execute', 'queryState']` (no `captureScreenshot`).
- **Steps**:
  1. Call `server.performActionAsync({ type: 'captureScreenshot', ... })`.
- **Expected result**: Throws immediately with "Plugin does not support capability: captureScreenshot".
- **Automation**: vitest.

#### 2.1.6 Concurrent requests

- **Test name**: `server handles concurrent queryState and queryLogs requests`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start server, connect v2 mock client.
- **Steps**:
  1. Call `server.performActionAsync(queryState)` and `server.performActionAsync(queryLogs)` simultaneously.
  2. From mock client, receive both messages (they will have different `requestId` values).
  3. Respond to `queryLogs` first, then `queryState`.
- **Expected result**: Both promises resolve with their correct responses, regardless of response order.
- **Automation**: vitest.

---

- **Test name**: `server handles execute + queryState concurrent (query returns before execute completes)`
- **Priority**: P1
- **Type**: integration
- **Setup**: Start server, connect v2 mock client.
- **Steps**:
  1. Send `execute` request.
  2. Send `queryState` request.
  3. Mock client responds with `stateResult` first, then `output` + `scriptComplete`.
- **Expected result**: `queryState` resolves first. `execute` resolves after `scriptComplete`.
- **Automation**: vitest.

### 2.2 Session Registry + Server Lifecycle

- **Test name**: `session file appears after startAsync and disappears after stopAsync`
- **Priority**: P0
- **Type**: integration
- **Setup**: Create `StudioBridgeServer` with custom registry base path (temp dir).
- **Steps**:
  1. Call `server.startAsync()` (with mock plugin connecting).
  2. List the temp registry directory.
  3. Call `server.stopAsync()`.
  4. List the temp registry directory again.
- **Expected result**: Step 2 shows one `.json` file. Step 4 shows zero files.
- **Automation**: vitest, `fs.readdirSync`.

---

- **Test name**: `bridge host removes session when plugin process crashes`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start a `BridgeConnection` (host mode). Connect a mock plugin, then abruptly close its WebSocket.
- **Steps**:
  1. Call `connection.listSessionsAsync()` after the plugin disconnects.
- **Expected result**: Returns empty (crashed plugin's session is removed from in-memory tracking).
- **Automation**: vitest.

---

- **Test name**: `health endpoint returns correct JSON after startAsync`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start a `StudioBridgeServer`.
- **Steps**:
  1. Send `GET http://localhost:{port}/health` via `fetch` or `http.get`.
  2. Parse response.
- **Expected result**: Status 200. Body contains `{ status: 'ready', sessionId, port, protocolVersion: 2, serverVersion }`.
- **Automation**: vitest, `node:http` or `fetch`.

---

- **Test name**: `health endpoint returns 404 for non-matching paths`
- **Priority**: P1
- **Type**: integration
- **Setup**: Start a `StudioBridgeServer`.
- **Steps**:
  1. Send `GET http://localhost:{port}/nonexistent`.
- **Expected result**: Status 404.
- **Automation**: vitest.

### 2.3 CLI to Server to Mock Plugin to Result

- **Test name**: `exec command sends script through server to mock plugin and returns output`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start server, connect mock v2 plugin. Mock plugin auto-responds to `execute` messages.
- **Steps**:
  1. Call the exec command handler with `{ code: 'print("hello")' }`.
  2. Mock plugin receives `execute`, sends `output` with `[{ level: 'Print', body: 'hello' }]`, then `scriptComplete { success: true }`.
- **Expected result**: Exec handler returns `{ success: true }` with logs containing "hello".
- **Automation**: vitest, mock plugin client.

---

- **Test name**: `state command queries mock plugin and formats result`
- **Priority**: P1
- **Type**: integration
- **Setup**: Start server with connected mock v2 plugin. Mock plugin auto-responds to `queryState`.
- **Steps**:
  1. Call the state command handler.
  2. Mock plugin sends `stateResult { state: 'Play', placeId: 123, placeName: 'Game', gameId: 456 }`.
- **Expected result**: Handler returns structured state result.
- **Automation**: vitest.

---

## 3. End-to-End Test Plans

### 3.1 Full Launch Flow

- **Test name**: `launch command starts server, mock plugin discovers and connects via health endpoint`
- **Priority**: P0
- **Type**: e2e
- **Setup**: Mock Studio launch (no real Studio). Implement a mock plugin client that polls `/health`, then connects via WebSocket and performs v2 handshake.
- **Steps**:
  1. Start `studio-bridge launch` (programmatically).
  2. Mock plugin polls `localhost:{port}/health` and discovers the server.
  3. Mock plugin connects via WebSocket and sends `register`.
  4. Server sends `welcome`.
  5. Verify launch command resolves with session info.
- **Expected result**: Full discovery and handshake cycle completes. Session appears in registry.
- **Automation**: vitest, mock plugin process simulated in same test process.

---

- **Test name**: `full lifecycle: launch, execute, query state, query logs, stop`
- **Priority**: P0
- **Type**: e2e
- **Setup**: Same as above.
- **Steps**:
  1. Start server.
  2. Mock plugin connects.
  3. Execute `print("hello")` via server API.
  4. Mock plugin responds.
  5. Query state via server API.
  6. Mock plugin responds.
  7. Query logs via server API.
  8. Mock plugin responds.
  9. Stop server.
  10. Verify session removed from registry.
- **Expected result**: Each action resolves correctly. Cleanup is complete.
- **Automation**: vitest.

### 3.2 Persistent Plugin Discovery

- **Test name**: `persistent plugin discovery via port scanning`
- **Priority**: P0
- **Type**: e2e
- **Setup**: Start a WebSocket server with a health endpoint on a random port in the scan range (38741-38760). Simulate the plugin's discovery algorithm.
- **Steps**:
  1. Start the server on a port within the scan range.
  2. Run the discovery algorithm (TypeScript reimplementation of the Luau logic).
  3. Verify it finds the server.
- **Expected result**: Discovery returns the server's session info.
- **Automation**: vitest. TypeScript port of the discovery logic for testing.

---

- **Test name**: `persistent plugin falls back to hello when register gets no response`
- **Priority**: P0
- **Type**: e2e
- **Setup**: Start a v1-only WebSocket server (ignores `register`, responds to `hello`). Use `vi.useFakeTimers()`.
- **Steps**:
  1. Mock plugin connects and sends `register`.
  2. `vi.advanceTimersByTime(3000)` to trigger the fallback timeout.
  3. Verify mock plugin sends `hello`.
  4. v1 server responds with v1 `welcome`.
- **Expected result**: Plugin detects v1 mode and disables extended features.
- **Automation**: vitest with `vi.useFakeTimers()` and `vi.advanceTimersByTime()`. Restore with `vi.useRealTimers()` in `afterEach`.

---

- **Test name**: `persistent plugin reconnects after WebSocket drops`
- **Priority**: P0
- **Type**: e2e
- **Setup**: Start server, connect mock plugin.
- **Steps**:
  1. Establish connection.
  2. Server forcibly closes WebSocket.
  3. Mock plugin enters reconnecting state.
  4. After backoff (1s), mock plugin re-discovers server via health endpoint.
  5. Mock plugin reconnects and performs handshake.
- **Expected result**: Second handshake completes. Server accepts the reconnection.
- **Automation**: vitest, simulate disconnect, verify reconnection.

---

- **Test name**: `persistent plugin returns to searching (no backoff) on shutdown message`
- **Priority**: P1
- **Type**: e2e
- **Setup**: Start server, connect mock plugin.
- **Steps**:
  1. Server sends `shutdown` to plugin.
  2. Plugin disconnects.
  3. Verify plugin enters `searching` state with zero backoff delay.
- **Expected result**: No backoff wait before polling resumes.
- **Automation**: vitest, mock the state machine.

---

- **Test name**: `persistent plugin handles server restart with new session ID`
- **Priority**: P1
- **Type**: e2e
- **Setup**: Start server A, connect mock plugin. Stop server A. Start server B on same port but different session ID.
- **Steps**:
  1. Establish connection with server A.
  2. Server A stops (WebSocket drops).
  3. Mock plugin enters reconnecting state.
  4. Server B starts on same port.
  5. Mock plugin discovers server B via health check (different session ID).
  6. Mock plugin sends fresh `register` to server B.
- **Expected result**: Plugin connects to new server with new session ID. Old session state is cleared.
- **Automation**: vitest.

### 3.3 Multi-context Plugin Behavior

- **Test name**: `server and client plugin instances join existing edit session during Play mode`
- **Priority**: P0
- **Type**: e2e
- **Setup**: Start server. Connect an edit-context mock plugin (simulating the always-running edit instance). Then simulate entering Play mode by connecting 2 additional mock plugin clients (server, client) sharing the same `instanceId`.
- **Steps**:
  1. Verify edit-context plugin is already connected.
  2. Connect server-context plugin (simulating Play mode creating a new server instance).
  3. Connect client-context plugin (simulating Play mode creating a new client instance).
  4. Each new plugin sends an independent `register` message with its own `context`.
  5. Query server session list.
- **Expected result**: 3 distinct sessions grouped under one `instanceId`. Each session can independently handle actions. The edit session was never interrupted.
- **Automation**: vitest, 3 mock plugin WebSocket clients.

---

- **Test name**: `client and server contexts disconnect when Play mode ends, edit context persists`
- **Priority**: P0
- **Type**: e2e
- **Setup**: Start server with 3 connected mock plugins (edit/client/server, same instanceId).
- **Steps**:
  1. Close the `client` and `server` plugin WebSockets (simulating Stop Play).
  2. Query server session list.
  3. Verify the `edit` plugin is still connected and functional.
- **Expected result**: Only edit session remains. Actions sent to edit session succeed.
- **Automation**: vitest.

---

- **Test name**: `plugin reconnection after failover preserves context identity`
- **Priority**: P0
- **Type**: e2e
- **Setup**: Start server. Connect 3 mock plugins (edit/client/server, same instanceId).
- **Steps**:
  1. Force-close the server.
  2. Start a new server on the same port.
  3. Each mock plugin reconnects and re-registers with the same `(instanceId, context)`.
  4. Query the new server's session list.
- **Expected result**: All 3 sessions re-appear with the correct `(instanceId, context)` pairs. New session IDs are assigned.
- **Automation**: vitest.

---

## Phase 2 Gate

**Criteria**: Persistent plugin installs successfully. Health endpoint works. Plugin discovery and handshake complete. Session management commands work. Existing commands work with `--session` flag.

**Required passing tests**:
1. All Phase 1 gate tests (see `01-bridge-network.md`).
2. Health endpoint returns correct JSON (2.2).
3. Health endpoint returns 404 for bad paths (2.2).
4. Full launch flow with mock plugin discovery (3.1).
5. Persistent plugin fallback to hello (3.2).
6. Plugin reconnection after disconnect (3.2).
7. `install-plugin` command writes to correct path (1.6 -- see `03-commands.md`).
8. `sessions` command lists sessions (Phase 1: 1.7b).
9. `exec` command session resolution -- all three scenarios (1.6 -- see `03-commands.md`).
10. `exec` command end-to-end with mock plugin (2.3).
11. Multi-context register messages: 3 contexts grouped by instanceId (2.1.3.1).
12. Play mode lifecycle: contexts appear/disappear correctly (2.1.3.1).
13. Register without context defaults to 'edit' (2.1.3.1).
14. Server and client plugin instances join existing edit session during Play mode (3.3).
15. Client/server contexts disconnect on Play mode exit, edit persists (3.3).

> **Manual Studio testing deferred to Phase 6 E2E validation.** See `06-integration.md` for the consolidated Studio verification checklist. All automated test criteria above remain required for the Phase 2 gate.
