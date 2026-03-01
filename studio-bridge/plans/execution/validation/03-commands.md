# Validation: Phase 3 -- Action Commands

> **Shared test infrastructure**: All tests that connect a mock plugin MUST use the standardized `MockPluginClient` from `shared-test-utilities.md`. Do not create ad-hoc WebSocket mocks. See [shared-test-utilities.md](./shared-test-utilities.md) for the full specification, usage examples, and design decisions.

Test specifications for action handlers (query state, capture screenshot, query logs, query data model), CLI command handlers, and command-layer integration tests.

**Phase**: 3 (New Action Commands)

**References**:
- Phase plan: `studio-bridge/plans/execution/phases/03-commands.md`
- Agent prompts: `studio-bridge/plans/execution/agent-prompts/03-commands.md`
- Tech specs: `studio-bridge/plans/tech-specs/02-command-system.md`, `studio-bridge/plans/tech-specs/04-action-specs.md`
- Sibling validation: `01-bridge-network.md` (Phase 1), `02-plugin.md` (Phase 2)
- Existing tests: `tools/studio-bridge/src/server/web-socket-protocol.test.ts`, `studio-bridge-server.test.ts`

Base path for source files: `/workspaces/NevermoreEngine/tools/studio-bridge/`

---

## 1. Unit Test Plans (continued)

### 1.5 Action Handlers (server-side)

Tests for `src/server/actions/query-state.ts`, `capture-screenshot.ts`, `query-logs.ts`, `query-datamodel.ts`. Each gets its own test file alongside the source.

#### 1.5.1 query-state action

- **Test name**: `queryStateAsync sends queryState message and returns stateResult payload`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock `performActionAsync` to resolve with a `stateResult` payload.
- **Steps**:
  1. Call `queryStateAsync(server)`.
  2. Verify `performActionAsync` was called with `type: 'queryState'`, an auto-generated `requestId`, and empty payload.
- **Expected result**: Returns `{ state: 'Edit', placeId: 123, placeName: 'Test', gameId: 456 }`.
- **Automation**: vitest with mock.

---

- **Test name**: `queryStateAsync rejects with timeout error when plugin does not respond`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock `performActionAsync` to reject with timeout error.
- **Steps**:
  1. Call `queryStateAsync(server)`.
- **Expected result**: Rejects with error message containing "timed out" and "5 seconds".
- **Automation**: vitest with mock.

---

- **Test name**: `queryStateAsync rejects when plugin lacks queryState capability`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock `performActionAsync` to throw "Plugin does not support capability: queryState".
- **Steps**:
  1. Call `queryStateAsync(server)`.
- **Expected result**: Rejects with error about missing capability.
- **Automation**: vitest with mock.

#### 1.5.2 capture-screenshot action

- **Test name**: `captureScreenshotAsync returns base64 data from screenshotResult`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock `performActionAsync` to resolve with screenshotResult payload.
- **Steps**:
  1. Call `captureScreenshotAsync(server)`.
- **Expected result**: Returns `{ data: 'iVBOR...', format: 'png', width: 1920, height: 1080 }`.
- **Automation**: vitest with mock.

---

- **Test name**: `captureScreenshotAsync rejects with SCREENSHOT_FAILED error`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock `performActionAsync` to reject with `SCREENSHOT_FAILED` code.
- **Steps**:
  1. Call `captureScreenshotAsync(server)`.
- **Expected result**: Rejects with error about screenshot capture failure.
- **Automation**: vitest with mock.

#### 1.5.3 query-logs action

- **Test name**: `queryLogsAsync sends queryLogs with correct payload fields`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock `performActionAsync`.
- **Steps**:
  1. Call `queryLogsAsync(server, { count: 100, direction: 'tail', levels: ['Error', 'Warning'], includeInternal: false })`.
  2. Verify the message payload matches.
- **Expected result**: `performActionAsync` called with correct payload. Returns the mocked `logsResult`.
- **Automation**: vitest with mock.

#### 1.5.4 query-datamodel action

- **Test name**: `queryDataModelAsync prepends 'game.' to paths that don't start with it`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock `performActionAsync`.
- **Steps**:
  1. Call `queryDataModelAsync(server, { path: 'Workspace.SpawnLocation' })`.
  2. Verify the message payload has `path: 'game.Workspace.SpawnLocation'`.
- **Expected result**: Path is correctly prefixed.
- **Automation**: vitest with mock.

---

- **Test name**: `queryDataModelAsync does not double-prefix paths starting with 'game.'`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock `performActionAsync`.
- **Steps**:
  1. Call `queryDataModelAsync(server, { path: 'game.Workspace.SpawnLocation' })`.
  2. Verify the message payload has `path: 'game.Workspace.SpawnLocation'` (not `game.game.Workspace...`).
- **Expected result**: No double prefix.
- **Automation**: vitest with mock.

---

- **Test name**: `queryDataModelAsync rejects with INSTANCE_NOT_FOUND error`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock `performActionAsync` to reject with an error carrying `code: 'INSTANCE_NOT_FOUND'`.
- **Steps**:
  1. Call `queryDataModelAsync(server, { path: 'Workspace.NonExistent' })`.
- **Expected result**: Rejects with error containing "No instance found at path".
- **Automation**: vitest with mock.

### 1.6 CLI Commands

Tests for CLI command handlers. These tests verify argument parsing and handler logic in isolation, mocking the underlying server interactions.

- **Test name**: `sessions command outputs table format by default`
- **Priority**: P1
- **Type**: unit
- **Setup**: Mock `BridgeConnection.listSessionsAsync` to return two sessions (one with `origin: 'user'`, one with `origin: 'managed'`).
- **Steps**:
  1. Invoke the sessions command handler with default args.
  2. Capture stdout.
- **Expected result**: Output contains session IDs, place names, states, origin values (`user`/`managed`), and connection duration. The Origin column is present. Ends with "2 sessions connected."
- **Automation**: vitest, capture stdout.

---

- **Test name**: `sessions command with --json outputs JSON array`
- **Priority**: P1
- **Type**: unit
- **Setup**: Mock `BridgeConnection.listSessionsAsync` to return sessions.
- **Steps**:
  1. Invoke handler with `{ json: true }`.
  2. Capture stdout.
  3. Parse as JSON.
- **Expected result**: Valid JSON array with session objects.
- **Automation**: vitest.

---

- **Test name**: `sessions command prints message when no sessions exist`
- **Priority**: P1
- **Type**: unit
- **Setup**: Mock `BridgeConnection.listSessionsAsync` to return empty array.
- **Steps**:
  1. Invoke handler.
  2. Capture stdout.
- **Expected result**: Output contains "No active sessions."
- **Automation**: vitest.

---

- **Test name**: `install-plugin command calls rojo build and writes to plugins folder`
- **Priority**: P1
- **Type**: unit
- **Setup**: Mock `rojoBuildAsync`, mock `findPluginsFolder`, mock `fs.copyFile`.
- **Steps**:
  1. Invoke install-plugin handler.
- **Expected result**: Rojo build was called with the persistent plugin template. File was copied to the plugins folder path.
- **Automation**: vitest with mocks.

---

- **Test name**: `state command outputs human-readable format by default`
- **Priority**: P1
- **Type**: unit
- **Setup**: Mock `queryStateAsync` to return `{ state: 'Edit', placeName: 'TestPlace', placeId: 123, gameId: 456 }`.
- **Steps**:
  1. Invoke state command handler.
  2. Capture stdout.
- **Expected result**: Output contains `Place: TestPlace`, `PlaceId: 123`, `GameId: 456`, `Mode: Edit`.
- **Automation**: vitest.

---

- **Test name**: `screenshot command writes file and prints path`
- **Priority**: P1
- **Type**: unit
- **Setup**: Mock `captureScreenshotAsync`. Mock `fs.writeFile`.
- **Steps**:
  1. Invoke screenshot command handler with `{ output: '/tmp/test.png' }`.
- **Expected result**: `writeFile` called with `/tmp/test.png` and decoded base64 data.
- **Automation**: vitest with mocks.

---

- **Test name**: `exec command session resolution: auto-selects single session`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock registry with one session. Mock `StudioBridgeServer`.
- **Steps**:
  1. Invoke exec handler without `--session` flag.
- **Expected result**: Connects to the single available session.
- **Automation**: vitest.

---

- **Test name**: `exec command session resolution: errors on multiple sessions without --session`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock registry with two sessions.
- **Steps**:
  1. Invoke exec handler without `--session` flag.
- **Expected result**: Throws/prints error listing available sessions.
- **Automation**: vitest.

---

- **Test name**: `exec command session resolution: falls back to launch when no sessions`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock registry with zero sessions.
- **Steps**:
  1. Invoke exec handler without `--session` flag.
- **Expected result**: Falls through to launch flow (calls `startAsync`).
- **Automation**: vitest.

---

#### 1.6.1 Context-aware session resolution

- **Test name**: `exec command with --context server targets the server context of a Play mode instance`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock `BridgeConnection.listSessionsAsync` to return 3 sessions with `instanceId: 'inst-1'` and contexts `edit`, `client`, `server`.
- **Steps**:
  1. Invoke exec handler with `{ context: 'server', code: 'print("hello")' }`.
- **Expected result**: Resolves to the session with `context: 'server'`. Executes against that session.
- **Automation**: vitest.

---

- **Test name**: `exec command defaults to server context when no --context flag and instance has multiple contexts`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock 3 sessions with same `instanceId`, contexts `edit`, `client`, `server`. No `--context` flag provided.
- **Steps**:
  1. Invoke exec handler without `--context`.
- **Expected result**: Auto-selects the `server` context session for exec (mutating command; see context default table in `tech-specs/04-action-specs.md`).
- **Automation**: vitest.

---

- **Test name**: `exec command with --context errors when specified context does not exist`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock 1 session with `instanceId: 'inst-1'`, `context: 'edit'` (Edit mode, no Play mode).
- **Steps**:
  1. Invoke exec handler with `{ context: 'server' }`.
- **Expected result**: Errors with "No session with context 'server' found for instance inst-1. Studio may not be in Play mode."
- **Automation**: vitest.

---

- **Test name**: `state command with --context client queries the client context`
- **Priority**: P1
- **Type**: unit
- **Setup**: Mock 3 sessions (edit/client/server) for one instance.
- **Steps**:
  1. Invoke state handler with `{ context: 'client' }`.
- **Expected result**: Queries the client-context session. Returns state from that context.
- **Automation**: vitest.

---

- **Test name**: `logs command with --context server queries the server context log buffer`
- **Priority**: P1
- **Type**: unit
- **Setup**: Mock 3 sessions for one instance.
- **Steps**:
  1. Invoke logs handler with `{ context: 'server' }`.
- **Expected result**: Queries the server-context session's log buffer.
- **Automation**: vitest.

---

- **Test name**: `query command with --context server queries the server DataModel`
- **Priority**: P1
- **Type**: unit
- **Setup**: Mock 3 sessions for one instance.
- **Steps**:
  1. Invoke query handler with `{ context: 'server', path: 'ServerStorage' }`.
- **Expected result**: Queries the server-context session. ServerStorage is only accessible from the server context.
- **Automation**: vitest.

---

- **Test name**: `sessions command shows context column for each session`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock `BridgeConnection.listSessionsAsync` to return sessions with different contexts.
- **Steps**:
  1. Invoke sessions handler.
  2. Capture stdout.
- **Expected result**: Output includes a Context column showing `edit`, `client`, or `server` for each session. Sessions from the same instance are visually grouped.
- **Automation**: vitest, capture stdout.

---

- **Test name**: `sessions command with --json includes context, instanceId, placeId, gameId fields`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock sessions with multi-context data.
- **Steps**:
  1. Invoke sessions handler with `{ json: true }`.
  2. Parse output.
- **Expected result**: Each session object includes `context`, `instanceId`, `placeId`, `gameId` fields.
- **Automation**: vitest.

---

- **Test name**: `session resolution with --session flag and multiple contexts: selects the instance and applies --context`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock sessions. Instance 'inst-1' has 3 contexts.
- **Steps**:
  1. Invoke exec handler with `{ session: 'inst-1', context: 'server' }`.
- **Expected result**: Resolves to the server-context session of instance inst-1.
- **Automation**: vitest.

---

- **Test name**: `session resolution auto-selects single instance even with multiple contexts`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock 3 sessions all from the same `instanceId` (Play mode).
- **Steps**:
  1. Invoke exec handler without `--session` flag.
- **Expected result**: Auto-selects the instance (only 1 instance exists) and picks the default context.
- **Automation**: vitest.

## 2. Integration Test Plans (continued)

### 2.3 CLI to Server to Mock Plugin to Result

> **Note**: This section covers both the exec command (also relevant to Phase 2 -- see `02-plugin.md`) and the state command. The full section is included here because it primarily tests command-layer integration.

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

## Phase 3 Gate

**Criteria**: All four new actions work end-to-end. Subscription mechanism works. Terminal dot-commands work.

**Required passing tests**:
1. All Phase 2 gate tests (see `02-plugin.md`).
2. `queryStateAsync` action handler tests (1.5.1).
3. `captureScreenshotAsync` action handler tests (1.5.2).
4. `queryLogsAsync` action handler tests (1.5.3).
5. `queryDataModelAsync` action handler tests (1.5.4) including path prefixing.
6. State command outputs correct format (1.6).
7. Screenshot command writes file (1.6).
8. Full lifecycle e2e (3.1 -- see `02-plugin.md`) including all actions.
9. Concurrent execute + queryState (2.1.6 -- see `02-plugin.md`).
10. `state` command end-to-end with mock plugin (2.3).
11. `--context` flag targets the correct context in Play mode (1.6.1).
12. `--context` errors when specified context does not exist (1.6.1).
13. Session resolution auto-selects single instance even with multiple contexts (1.6.1).
14. Sessions command shows context column and instance grouping (1.6.1).
15. Sessions `--json` includes context, instanceId, placeId, gameId fields (1.6.1).

> **Manual Studio testing deferred to Phase 6 E2E validation.** See `06-integration.md` for the consolidated Studio verification checklist. All automated test criteria above remain required for the Phase 3 gate.
