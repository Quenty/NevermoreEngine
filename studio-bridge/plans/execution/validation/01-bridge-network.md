# Validation: Phase 1 -- Bridge Network Foundation

> **Shared test infrastructure**: All tests that connect a mock plugin MUST use the standardized `MockPluginClient` from `shared-test-utilities.md`. Do not create ad-hoc WebSocket mocks. See [shared-test-utilities.md](./shared-test-utilities.md) for the full specification, usage examples, and design decisions.

Test specifications for the bridge network layer: protocol v2, session tracking, pending request map, and host failover.

**Phase**: 1 (Bridge Network Foundation)

**References**:
- Phase plan: `studio-bridge/plans/execution/phases/01-bridge-network.md`
- Agent prompts: `studio-bridge/plans/execution/agent-prompts/01-bridge-network.md`
- Tech specs: `studio-bridge/plans/tech-specs/01-protocol.md`, `studio-bridge/plans/tech-specs/02-command-system.md`, `studio-bridge/plans/tech-specs/07-bridge-network.md`, `studio-bridge/plans/tech-specs/08-host-failover.md`
- Existing tests: `tools/studio-bridge/src/server/web-socket-protocol.test.ts`, `studio-bridge-server.test.ts`

Base path for source files: `/workspaces/NevermoreEngine/tools/studio-bridge/`

---

## 1. Unit Test Plans

### 1.1 Protocol Layer

Tests for `src/server/web-socket-protocol.ts`. All tests go in `src/server/web-socket-protocol.test.ts` (extend existing file).

#### 1.1.1 decodePluginMessage -- register message

- **Test name**: `decodePluginMessage decodes a valid register message with all fields`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Call `decodePluginMessage` with a JSON string containing `type: 'register'`, `sessionId: 'abc'`, `protocolVersion: 2`, and a full payload (`pluginVersion`, `instanceId`, `placeName`, `placeFile`, `state: 'Edit'`, `pid: 12345`, `capabilities: [...]`).
  2. Verify the returned object matches the `RegisterMessage` shape.
- **Expected result**: Returns a `RegisterMessage` with all fields populated, including `protocolVersion: 2` and `capabilities` array.
- **Automation**: vitest, inline JSON construction.

---

- **Test name**: `decodePluginMessage decodes register with optional placeFile omitted`
- **Priority**: P1
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Call `decodePluginMessage` with a register message where `placeFile` is absent.
  2. Verify the returned object has `placeFile: undefined`.
- **Expected result**: Returns `RegisterMessage` with `placeFile` undefined.
- **Automation**: vitest.

---

- **Test name**: `decodePluginMessage returns null for register with missing required fields`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Call `decodePluginMessage` with register messages missing each required field in turn: `pluginVersion`, `instanceId`, `placeName`, `state`, `capabilities`.
  2. Verify each returns `null`.
- **Expected result**: Returns `null` for every variant with a missing required field.
- **Automation**: vitest, parameterized test or loop.

---

- **Test name**: `decodePluginMessage returns null for register with invalid state value`
- **Priority**: P1
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Call `decodePluginMessage` with register where `state` is `"InvalidState"`.
- **Expected result**: Returns `null`.
- **Automation**: vitest.

#### 1.1.2 decodePluginMessage -- stateResult message

- **Test name**: `decodePluginMessage decodes a valid stateResult`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Call `decodePluginMessage` with `type: 'stateResult'`, `requestId: 'req-001'`, payload with `state: 'Edit'`, `placeId: 123`, `placeName: 'Test'`, `gameId: 456`.
- **Expected result**: Returns a typed `StateResultMessage` with all fields matching.
- **Automation**: vitest.

---

- **Test name**: `decodePluginMessage returns null for stateResult without requestId`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Call `decodePluginMessage` with a `stateResult` message that has no `requestId`.
- **Expected result**: Returns `null`.
- **Automation**: vitest.

---

- **Test name**: `decodePluginMessage returns null for stateResult with invalid state enum`
- **Priority**: P1
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Call `decodePluginMessage` with `stateResult` where `state` is `"Bogus"`.
- **Expected result**: Returns `null`.
- **Automation**: vitest.

#### 1.1.3 decodePluginMessage -- screenshotResult message

- **Test name**: `decodePluginMessage decodes a valid screenshotResult`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Call `decodePluginMessage` with `type: 'screenshotResult'`, `requestId: 'req-002'`, payload with `data: 'iVBOR...'`, `format: 'png'`, `width: 1920`, `height: 1080`.
- **Expected result**: Returns a typed `ScreenshotResultMessage`.
- **Automation**: vitest.

---

- **Test name**: `decodePluginMessage returns null for screenshotResult with missing data field`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Omit `data` from the payload.
- **Expected result**: Returns `null`.
- **Automation**: vitest.

---

- **Test name**: `decodePluginMessage returns null for screenshotResult with non-string data`
- **Priority**: P1
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Set `data` to a number in the payload.
- **Expected result**: Returns `null`.
- **Automation**: vitest.

#### 1.1.4 decodePluginMessage -- dataModelResult message

- **Test name**: `decodePluginMessage decodes a valid dataModelResult with nested children`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Construct a `dataModelResult` with `instance` containing `name`, `className`, `path`, `properties` (including a `Vector3` serialized value), `attributes`, `childCount: 1`, and `children` array with one child.
- **Expected result**: Returns a typed `DataModelResultMessage` with the full instance tree.
- **Automation**: vitest.

---

- **Test name**: `decodePluginMessage returns null for dataModelResult without instance field`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Send `dataModelResult` with empty payload.
- **Expected result**: Returns `null`.
- **Automation**: vitest.

#### 1.1.5 decodePluginMessage -- logsResult message

- **Test name**: `decodePluginMessage decodes a valid logsResult`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Construct `logsResult` with `entries` array (3 entries with `level`, `body`, `timestamp`), `total: 100`, `bufferCapacity: 1000`.
- **Expected result**: Returns a typed `LogsResultMessage`.
- **Automation**: vitest.

---

- **Test name**: `decodePluginMessage decodes logsResult with empty entries array`
- **Priority**: P1
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Send `logsResult` with `entries: []`, `total: 0`, `bufferCapacity: 1000`.
- **Expected result**: Returns valid `LogsResultMessage` with empty entries.
- **Automation**: vitest.

---

- **Test name**: `decodePluginMessage returns null for logsResult without total field`
- **Priority**: P1
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Omit `total` from payload.
- **Expected result**: Returns `null`.
- **Automation**: vitest.

#### 1.1.6 decodePluginMessage -- stateChange message

- **Test name**: `decodePluginMessage decodes a valid stateChange push message`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Construct `stateChange` with `previousState: 'Edit'`, `newState: 'Play'`, `timestamp: 47230`. No `requestId`.
- **Expected result**: Returns a typed `StateChangeMessage` with no `requestId`.
- **Automation**: vitest.

---

- **Test name**: `decodePluginMessage returns null for stateChange with missing previousState`
- **Priority**: P1
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Omit `previousState` from payload.
- **Expected result**: Returns `null`.
- **Automation**: vitest.

#### 1.1.7 decodePluginMessage -- heartbeat message

- **Test name**: `decodePluginMessage decodes a valid heartbeat`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Construct `heartbeat` with `uptimeMs: 45000`, `state: 'Edit'`, `pendingRequests: 0`. No `requestId`.
- **Expected result**: Returns a typed `HeartbeatMessage`.
- **Automation**: vitest.

---

- **Test name**: `decodePluginMessage returns null for heartbeat with missing uptimeMs`
- **Priority**: P1
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Omit `uptimeMs` from heartbeat payload.
- **Expected result**: Returns `null`.
- **Automation**: vitest.

#### 1.1.8 decodePluginMessage -- subscribeResult and unsubscribeResult

- **Test name**: `decodePluginMessage decodes a valid subscribeResult`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Construct `subscribeResult` with `requestId: 'sub-001'`, `events: ['stateChange', 'logPush']`.
- **Expected result**: Returns a typed `SubscribeResultMessage`.
- **Automation**: vitest.

---

- **Test name**: `decodePluginMessage decodes a valid unsubscribeResult`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Construct `unsubscribeResult` with `requestId: 'unsub-001'`, `events: ['logPush']`.
- **Expected result**: Returns a typed `UnsubscribeResultMessage`.
- **Automation**: vitest.

---

- **Test name**: `decodePluginMessage returns null for subscribeResult without events array`
- **Priority**: P1
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Omit `events` from subscribeResult payload.
- **Expected result**: Returns `null`.
- **Automation**: vitest.

#### 1.1.9 decodePluginMessage -- error message (plugin-originated)

- **Test name**: `decodePluginMessage decodes a plugin error with requestId`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Construct `error` with `requestId: 'req-005'`, `code: 'INSTANCE_NOT_FOUND'`, `message: 'No instance...'`, `details: { resolvedTo: 'game.Workspace' }`.
- **Expected result**: Returns a typed `PluginErrorMessage` with code, message, and details.
- **Automation**: vitest.

---

- **Test name**: `decodePluginMessage decodes a plugin error without requestId`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Construct `error` without `requestId`, with `code: 'INTERNAL_ERROR'`, `message: 'Something broke'`.
- **Expected result**: Returns `PluginErrorMessage` with `requestId: undefined`.
- **Automation**: vitest.

---

- **Test name**: `decodePluginMessage returns null for error without code`
- **Priority**: P1
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Omit `code` from error payload.
- **Expected result**: Returns `null`.
- **Automation**: vitest.

#### 1.1.10 decodePluginMessage -- v1 messages preserved

- **Test name**: `decodePluginMessage still decodes v1 hello without protocolVersion`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Send the exact same hello message as the existing test (no `protocolVersion`, no `capabilities`).
- **Expected result**: Returns `HelloMessage` identical to current behavior.
- **Automation**: vitest. This is a regression check -- existing test still passes.

---

- **Test name**: `decodePluginMessage decodes extended hello with protocolVersion and capabilities`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Send hello with `protocolVersion: 2`, `capabilities: ['execute', 'queryState']`, `pluginVersion: '1.0.0'`.
- **Expected result**: Returns `HelloMessage` with the additional fields populated.
- **Automation**: vitest.

---

- **Test name**: `decodePluginMessage still returns null for unknown message types`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Send `{ type: 'futureMessage', sessionId: 'x', payload: {} }`.
- **Expected result**: Returns `null`. This is the forward-compatibility behavior.
- **Automation**: vitest.

#### 1.1.11 decodeServerMessage (new function)

- **Test name**: `decodeServerMessage decodes welcome with v2 fields`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Call `decodeServerMessage` with a welcome message containing `protocolVersion: 2`, `capabilities`, `serverVersion`.
- **Expected result**: Returns a typed `WelcomeMessage`.
- **Automation**: vitest.

---

- **Test name**: `decodeServerMessage decodes queryState`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Call `decodeServerMessage` with `{ type: 'queryState', sessionId: 'abc', requestId: 'req-001', payload: {} }`.
- **Expected result**: Returns a typed `QueryStateMessage`.
- **Automation**: vitest.

---

- **Test name**: `decodeServerMessage decodes captureScreenshot`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Call `decodeServerMessage` with `captureScreenshot` including `requestId` and `payload: { format: 'png' }`.
- **Expected result**: Returns a typed `CaptureScreenshotMessage`.
- **Automation**: vitest.

---

- **Test name**: `decodeServerMessage decodes queryDataModel with all payload fields`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Call `decodeServerMessage` with `queryDataModel` including `path`, `depth`, `properties`, `includeAttributes`, `find`, `listServices`.
- **Expected result**: Returns a typed `QueryDataModelMessage` with all optional fields.
- **Automation**: vitest.

---

- **Test name**: `decodeServerMessage decodes queryLogs`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Call `decodeServerMessage` with `queryLogs` including `count`, `direction`, `levels`, `includeInternal`.
- **Expected result**: Returns a typed `QueryLogsMessage`.
- **Automation**: vitest.

---

- **Test name**: `decodeServerMessage decodes subscribe and unsubscribe`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Call `decodeServerMessage` with `subscribe` and `unsubscribe` messages.
- **Expected result**: Returns typed `SubscribeMessage` and `UnsubscribeMessage`.
- **Automation**: vitest.

---

- **Test name**: `decodeServerMessage decodes server error`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Call `decodeServerMessage` with `{ type: 'error', sessionId: 'x', requestId: 'r', payload: { code: 'TIMEOUT', message: 'Timed out' } }`.
- **Expected result**: Returns a typed `ServerErrorMessage`.
- **Automation**: vitest.

---

- **Test name**: `decodeServerMessage returns null for unknown type`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Call `decodeServerMessage` with `{ type: 'unknownServer', sessionId: 'x', payload: {} }`.
- **Expected result**: Returns `null`.
- **Automation**: vitest.

---

- **Test name**: `decodeServerMessage returns null for malformed JSON`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Call `decodeServerMessage('not valid json')`.
- **Expected result**: Returns `null`.
- **Automation**: vitest.

#### 1.1.12 encodeMessage -- v2 messages

- **Test name**: `encodeMessage round-trips all v2 server message types`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. For each v2 `ServerMessage` type (`queryState`, `captureScreenshot`, `queryDataModel`, `queryLogs`, `subscribe`, `unsubscribe`, server `error`), construct a valid message object.
  2. Call `encodeMessage(msg)`.
  3. Parse the resulting JSON string.
  4. Verify the parsed object matches the original.
- **Expected result**: JSON round-trip preserves all fields including `requestId`.
- **Automation**: vitest, parameterized test.

---

- **Test name**: `encodeMessage preserves v1 message format unchanged`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Encode `welcome`, `execute`, `shutdown` messages identical to existing tests.
  2. Verify output matches the existing test expectations exactly.
- **Expected result**: Output is byte-identical to current behavior.
- **Automation**: vitest. Regression check against existing test data.

#### 1.1.13 Encode/decode round-trip for all message types

- **Test name**: `encode then decode round-trip for every v2 server message type`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. For each `ServerMessage` type, construct a message, encode it with `encodeMessage`, decode it with `decodeServerMessage`.
  2. Compare the decoded result to the original.
- **Expected result**: Decoded message matches the original for every type.
- **Automation**: vitest, parameterized.

---

- **Test name**: `decode then encode round-trip for every v2 plugin message type`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. For each `PluginMessage` type, construct a JSON string, decode with `decodePluginMessage`, re-encode as JSON, parse, and compare.
- **Expected result**: All fields are preserved through the round-trip.
- **Automation**: vitest, parameterized.

### 1.2 Session Tracking

Tests for in-memory session tracking. There is no `SessionFile` or `SessionRegistry` class -- session tracking is done in-memory by the bridge host. New test file `src/registry/session-tracker.test.ts`.

#### 1.2.1 SessionTracker

- **Test name**: `SessionTracker.addSession adds a session with the correct (instanceId, context) key`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create a `SessionTracker` instance.
- **Steps**:
  1. Call `tracker.addSession({ sessionId: 'sess-1', instanceId: 'inst-1', context: 'edit', placeName: 'TestPlace', state: 'Edit' })`.
  2. Call `tracker.getSession('sess-1')`.
- **Expected result**: Returns the session object with matching `sessionId`, `instanceId`, `context`, `placeName`, and `state`.
- **Automation**: vitest.

---

- **Test name**: `SessionTracker.removeSession removes a session and emits an event`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create a `SessionTracker` instance with one session added. Subscribe to the `onSessionRemoved` event.
- **Steps**:
  1. Call `tracker.removeSession('sess-1')`.
  2. Call `tracker.getSession('sess-1')`.
  3. Check the event listener.
- **Expected result**: `getSession` returns `undefined`. The `onSessionRemoved` event was emitted with the removed session's info.
- **Automation**: vitest.

---

- **Test name**: `SessionTracker.getSession returns undefined for unknown sessionId`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create a `SessionTracker` instance with no sessions.
- **Steps**:
  1. Call `tracker.getSession('nonexistent')`.
- **Expected result**: Returns `undefined`.
- **Automation**: vitest.

---

- **Test name**: `SessionTracker.getSessionsByInstance groups sessions by instanceId`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create a `SessionTracker` instance. Add 3 sessions sharing `instanceId: 'inst-1'` with contexts `edit`, `client`, `server`. Add 1 session with `instanceId: 'inst-2'`, context `edit`.
- **Steps**:
  1. Call `tracker.getSessionsByInstance('inst-1')`.
  2. Call `tracker.getSessionsByInstance('inst-2')`.
- **Expected result**: First call returns 3 sessions (edit, client, server). Second call returns 1 session (edit).
- **Automation**: vitest.

---

- **Test name**: `SessionTracker.listInstances returns unique instance IDs`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create a `SessionTracker` instance. Add sessions for `inst-1` (3 contexts) and `inst-2` (1 context).
- **Steps**:
  1. Call `tracker.listInstances()`.
- **Expected result**: Returns `['inst-1', 'inst-2']` (or equivalent unordered set). No duplicates.
- **Automation**: vitest.

---

- **Test name**: `SessionTracker removes instance group when last context is removed`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create a `SessionTracker` instance. Add 2 sessions for `instanceId: 'inst-1'` with contexts `edit` and `server`.
- **Steps**:
  1. Call `tracker.removeSession` for the `edit` session.
  2. Call `tracker.listInstances()` -- verify `inst-1` is still listed.
  3. Call `tracker.removeSession` for the `server` session.
  4. Call `tracker.listInstances()` -- verify `inst-1` is no longer listed.
  5. Call `tracker.getSessionsByInstance('inst-1')`.
- **Expected result**: After removing the last context, `listInstances` no longer includes `inst-1`. `getSessionsByInstance` returns an empty array (or undefined).
- **Automation**: vitest.

#### 1.2.2 BridgeConnection session tracking

> **Note**: There is no `SessionRegistry` class. Session tracking is done in-memory by the bridge host via `BridgeConnection`. Plugin connections on the `/plugin` WebSocket path register sessions; disconnections remove them. Each session carries an `origin` field (`'user'` or `'managed'`).

- **Test name**: `BridgeConnection.listSessionsAsync returns connected plugin sessions`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create a `BridgeConnection` (host mode) on a test port. Connect a mock plugin WebSocket that sends a `register` message.
- **Steps**:
  1. Wait for the plugin to register.
  2. Call `connection.listSessionsAsync()`.
- **Expected result**: List contains one entry with matching `sessionId`, `placeName`, `placeFile`, `state`, `pluginVersion`, `capabilities`, `connectedAt`, and `origin` fields.
- **Automation**: vitest.

---

- **Test name**: `BridgeConnection tracks session origin as 'user' for self-connecting plugins`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create a `BridgeConnection` (host mode). Connect a mock plugin that discovers the host on its own (no prior launch request).
- **Steps**:
  1. Wait for plugin registration.
  2. Call `connection.listSessionsAsync()`.
- **Expected result**: The session's `origin` field is `'user'`.
- **Automation**: vitest.

---

- **Test name**: `BridgeConnection tracks session origin as 'managed' for launched sessions`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create a `BridgeConnection` (host mode). Launch Studio via the connection (temporary plugin injection path), then connect the mock plugin.
- **Steps**:
  1. Trigger a Studio launch through the connection.
  2. Connect a mock plugin with the expected session ID.
  3. Call `connection.listSessionsAsync()`.
- **Expected result**: The session's `origin` field is `'managed'`.
- **Automation**: vitest.

---

- **Test name**: `BridgeConnection.getSession returns a session by ID`
- **Priority**: P0
- **Type**: unit
- **Setup**: Connect a mock plugin.
- **Steps**:
  1. Call `connection.getSession('abc')`.
- **Expected result**: Returns the `BridgeSession`.
- **Automation**: vitest.

---

- **Test name**: `BridgeConnection.getSession returns undefined for unknown ID`
- **Priority**: P0
- **Type**: unit
- **Setup**: No plugins connected.
- **Steps**:
  1. Call `connection.getSession('nonexistent')`.
- **Expected result**: Returns `undefined`.
- **Automation**: vitest.

---

- **Test name**: `BridgeConnection removes session when plugin disconnects`
- **Priority**: P0
- **Type**: unit
- **Setup**: Connect a mock plugin, then close its WebSocket.
- **Steps**:
  1. Call `connection.listSessionsAsync()` after disconnect.
- **Expected result**: List is empty.
- **Automation**: vitest.

---

- **Test name**: `BridgeConnection handles multiple concurrent sessions`
- **Priority**: P1
- **Type**: unit
- **Setup**: Connect three mock plugins with different session IDs.
- **Steps**:
  1. Call `connection.listSessionsAsync()`.
  2. Disconnect one plugin.
  3. Call `connection.listSessionsAsync()` again.
- **Expected result**: First call returns 3 sessions. Second call returns 2 sessions.
- **Automation**: vitest.

---

#### 1.2.3 Multi-context session tracking (instance grouping)

- **Test name**: `BridgeConnection groups sessions by instanceId across contexts`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create a `BridgeConnection` (host mode) on a test port. Connect 3 mock plugins sharing the same `instanceId` but with different `context` values (`edit`, `client`, `server`).
- **Steps**:
  1. Wait for all 3 plugins to register.
  2. Call `connection.listSessionsAsync()`.
- **Expected result**: List contains 3 entries, all with the same `instanceId` but different `context` values. Each session has a unique `sessionId`.
- **Automation**: vitest.

---

- **Test name**: `BridgeConnection treats (instanceId, context) as the unique session key`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create a `BridgeConnection` (host mode). Connect a mock plugin with `instanceId: 'inst-1'` and `context: 'edit'`.
- **Steps**:
  1. Connect a second mock plugin with the same `instanceId: 'inst-1'` and `context: 'edit'` (duplicate).
  2. Call `connection.listSessionsAsync()`.
- **Expected result**: The second registration replaces the first. List contains 1 session (not 2) for that `(instanceId, context)` pair.
- **Automation**: vitest.

---

- **Test name**: `BridgeConnection register message includes context, placeId, and gameId`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create a `BridgeConnection` (host mode). Connect a mock plugin sending a `register` message with `instanceId: 'inst-1'`, `context: 'server'`, `placeId: 123`, `gameId: 456`.
- **Steps**:
  1. Wait for plugin to register.
  2. Call `connection.listSessionsAsync()`.
- **Expected result**: The session has `context: 'server'`, `placeId: 123`, `gameId: 456`.
- **Automation**: vitest.

---

- **Test name**: `BridgeConnection removes only the disconnected context when one plugin in an instance group disconnects`
- **Priority**: P0
- **Type**: unit
- **Setup**: Connect 3 mock plugins sharing `instanceId: 'inst-1'` with contexts `edit`, `client`, `server`.
- **Steps**:
  1. Disconnect the `client` context plugin.
  2. Call `connection.listSessionsAsync()`.
- **Expected result**: List contains 2 sessions (`edit` and `server` for `inst-1`). The `client` session is gone.
- **Automation**: vitest.

---

- **Test name**: `BridgeConnection emits session events for each context independently during Play mode`
- **Priority**: P1
- **Type**: unit
- **Setup**: Create `BridgeConnection` (host mode). Subscribe to `onSessionConnected` and `onSessionDisconnected` events.
- **Steps**:
  1. Connect 3 mock plugins with the same `instanceId` but different contexts (simulating Play mode).
  2. Count `onSessionConnected` events.
  3. Disconnect all 3.
  4. Count `onSessionDisconnected` events.
- **Expected result**: 3 `onSessionConnected` events fired (one per context). 3 `onSessionDisconnected` events fired.
- **Automation**: vitest.

---

- **Test name**: `BridgeConnection handles Play mode enter/exit lifecycle`
- **Priority**: P1
- **Type**: unit
- **Setup**: Create `BridgeConnection` (host mode). Connect a mock plugin with `instanceId: 'inst-1'`, `context: 'edit'`.
- **Steps**:
  1. Verify 1 session (edit).
  2. Connect 2 additional mock plugins with `instanceId: 'inst-1'`, contexts `client` and `server` (simulating entering Play mode).
  3. Verify 3 sessions.
  4. Disconnect the `client` and `server` mock plugins (simulating exiting Play mode).
  5. Call `connection.listSessionsAsync()`.
- **Expected result**: After step 5, 1 session remains (the `edit` context).
- **Automation**: vitest.

### 1.2.4 BridgeConnection subtask tests (Tasks 1.3d1-1.3d4)

> **Note**: Task 1.3d has been split into 5 subtasks. The first 4 are agent-assignable with concrete test specifications. Task 1.3d5 (barrel export review) is a review checkpoint with no automated tests beyond import verification -- a review agent verifies the export surface against the tech spec.

#### 1.2.4.1 Role detection (Task 1.3d1)

- **Test name**: `BridgeConnection.connectAsync becomes host on unused port`
- **Priority**: P0
- **Type**: unit
- **Setup**: Choose an ephemeral port known to be free.
- **Steps**:
  1. Call `BridgeConnection.connectAsync({ port })`.
  2. Check `connection.role`.
  3. Check `connection.isConnected`.
- **Expected result**: `role === 'host'`, `isConnected === true`.
- **Automation**: vitest.

---

- **Test name**: `Two concurrent connectAsync calls: first becomes host, second becomes client`
- **Priority**: P0
- **Type**: integration
- **Setup**: Choose an ephemeral port.
- **Steps**:
  1. Call `BridgeConnection.connectAsync({ port })` twice concurrently (start both, await both).
  2. Check roles of both connections.
- **Expected result**: Exactly one has `role === 'host'`, the other has `role === 'client'`. Both have `isConnected === true`.
- **Automation**: vitest.

---

- **Test name**: `disconnectAsync sets isConnected to false`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create a `BridgeConnection`.
- **Steps**:
  1. Call `disconnectAsync()`.
  2. Check `isConnected`.
- **Expected result**: `isConnected === false`.
- **Automation**: vitest.

---

- **Test name**: `Environment detection: bind success returns host role`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock port bind to succeed.
- **Steps**:
  1. Call `detectRoleAsync({ port })`.
- **Expected result**: Returns `{ role: 'host' }`.
- **Automation**: vitest.

---

- **Test name**: `Environment detection: EADDRINUSE with healthy host returns client role`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock port bind to fail with EADDRINUSE. Mock health check to succeed.
- **Steps**:
  1. Call `detectRoleAsync({ port })`.
- **Expected result**: Returns `{ role: 'client' }`.
- **Automation**: vitest.

---

- **Test name**: `Environment detection: EADDRINUSE with stale host retries and becomes host`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock port bind to fail with EADDRINUSE. Mock health check to fail. Mock second bind attempt to succeed.
- **Steps**:
  1. Call `detectRoleAsync({ port })`.
- **Expected result**: Returns `{ role: 'host' }` after retry.
- **Automation**: vitest.

---

- **Test name**: `Environment detection: remoteHost option skips bind and returns client`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Call `detectRoleAsync({ port: 38741, remoteHost: 'localhost:38741' })`.
- **Expected result**: Returns `{ role: 'client' }` without attempting port bind.
- **Automation**: vitest.

#### 1.2.4.2 Session query methods (Task 1.3d2)

- **Test name**: `BridgeConnection.listSessions returns connected plugin sessions (host mode)`
- **Priority**: P0
- **Type**: integration
- **Setup**: Create `BridgeConnection` (host mode) on ephemeral port. Connect a mock plugin that sends `register`.
- **Steps**:
  1. Wait for plugin to register.
  2. Call `connection.listSessions()`.
- **Expected result**: List contains one entry with matching session metadata.
- **Automation**: vitest.

---

- **Test name**: `BridgeConnection.listInstances groups sessions by instanceId`
- **Priority**: P0
- **Type**: integration
- **Setup**: Create `BridgeConnection` (host mode). Connect 3 mock plugins sharing `instanceId` with different contexts (edit, client, server).
- **Steps**:
  1. Wait for all plugins to register.
  2. Call `connection.listInstances()`.
- **Expected result**: Returns 1 instance with 3 contexts.
- **Automation**: vitest.

---

- **Test name**: `BridgeConnection.listSessions works through client mode (forwarded)`
- **Priority**: P0
- **Type**: integration
- **Setup**: Create host + client connections on same port. Connect a mock plugin to the host.
- **Steps**:
  1. Call `listSessions()` on the client connection.
- **Expected result**: Client sees the same session as the host.
- **Automation**: vitest.

---

- **Test name**: `BridgeConnection.getSession returns BridgeSession or undefined`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create `BridgeConnection` with one mock plugin connected.
- **Steps**:
  1. Call `getSession(knownId)` -> returns `BridgeSession`.
  2. Call `getSession('unknown')` -> returns `undefined`.
- **Expected result**: Known ID returns session, unknown returns `undefined`.
- **Automation**: vitest.

#### 1.2.4.3 Session resolution (Task 1.3d3)

- **Test name**: `resolveSession with 0 sessions throws error`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create `BridgeConnection` with no plugins connected.
- **Steps**:
  1. Call `resolveSession()`.
- **Expected result**: Throws with message containing "No sessions connected".
- **Automation**: vitest.

---

- **Test name**: `resolveSession with 1 session returns it automatically`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create `BridgeConnection` with one mock plugin.
- **Steps**:
  1. Call `resolveSession()` with no arguments.
- **Expected result**: Returns the single session.
- **Automation**: vitest.

---

- **Test name**: `resolveSession with N instances from different instanceIds throws with list`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create `BridgeConnection` with 2 mock plugins from different `instanceId` values.
- **Steps**:
  1. Call `resolveSession()` with no arguments.
- **Expected result**: Throws with message containing both instance IDs and instructions to use `--session` or `--instance`.
- **Automation**: vitest.

---

- **Test name**: `resolveSession with explicit sessionId returns that session`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create `BridgeConnection` with multiple mock plugins.
- **Steps**:
  1. Call `resolveSession('known-id')`.
- **Expected result**: Returns the session with matching ID.
- **Automation**: vitest.

---

- **Test name**: `resolveSession with unknown sessionId throws`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create `BridgeConnection` with one mock plugin.
- **Steps**:
  1. Call `resolveSession('unknown-id')`.
- **Expected result**: Throws with "Session 'unknown-id' not found".
- **Automation**: vitest.

---

- **Test name**: `resolveSession with 1 instance and 3 contexts returns Edit by default`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create `BridgeConnection` with 3 mock plugins sharing `instanceId`, contexts: edit, client, server.
- **Steps**:
  1. Call `resolveSession()` with no arguments.
- **Expected result**: Returns the Edit context session.
- **Automation**: vitest.

---

- **Test name**: `resolveSession with 1 instance and context arg returns matching context`
- **Priority**: P0
- **Type**: unit
- **Setup**: Same as above (3 contexts).
- **Steps**:
  1. Call `resolveSession(undefined, 'server')`.
- **Expected result**: Returns the server context session.
- **Automation**: vitest.

---

- **Test name**: `resolveSession with instanceId and context returns matching session`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create `BridgeConnection` with 2 instances, each with 2 contexts.
- **Steps**:
  1. Call `resolveSession(undefined, 'server', 'inst-1')`.
- **Expected result**: Returns the server context for `inst-1`.
- **Automation**: vitest.

#### 1.2.4.4 Async wait and events (Task 1.3d4)

- **Test name**: `waitForSession resolves when plugin connects after call`
- **Priority**: P0
- **Type**: integration
- **Setup**: Create `BridgeConnection` (host mode) with no plugins.
- **Steps**:
  1. Call `waitForSession()` (do not await yet).
  2. Connect a mock plugin.
  3. Await the promise.
- **Expected result**: Promise resolves with the session.
- **Automation**: vitest.

---

- **Test name**: `waitForSession resolves immediately when session already exists`
- **Priority**: P0
- **Type**: integration
- **Setup**: Create `BridgeConnection` with one mock plugin already connected.
- **Steps**:
  1. Call `await waitForSession()`.
- **Expected result**: Resolves immediately with the session.
- **Automation**: vitest.

---

- **Test name**: `waitForSession rejects on timeout`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create `BridgeConnection` with no plugins. Use `vi.useFakeTimers()` or a short real timeout.
- **Steps**:
  1. Call `waitForSession(500)`.
  2. Advance timers or wait 500ms.
- **Expected result**: Rejects with timeout error containing "timed out".
- **Automation**: vitest.

---

- **Test name**: `session-connected event fires when plugin registers`
- **Priority**: P0
- **Type**: integration
- **Setup**: Create `BridgeConnection` (host mode). Subscribe to `session-connected` event.
- **Steps**:
  1. Connect a mock plugin.
  2. Check event listener.
- **Expected result**: Event fires with `BridgeSession` argument.
- **Automation**: vitest.

---

- **Test name**: `session-disconnected event fires when plugin disconnects`
- **Priority**: P0
- **Type**: integration
- **Setup**: Create `BridgeConnection` (host mode). Connect a mock plugin. Subscribe to `session-disconnected` event.
- **Steps**:
  1. Disconnect the mock plugin.
  2. Check event listener.
- **Expected result**: Event fires with the session ID.
- **Automation**: vitest.

---

- **Test name**: `instance-connected event fires when first context of an instance connects`
- **Priority**: P1
- **Type**: integration
- **Setup**: Create `BridgeConnection` (host mode). Subscribe to `instance-connected` event.
- **Steps**:
  1. Connect a mock plugin with `instanceId: 'inst-1'`, `context: 'edit'`.
  2. Check event listener.
- **Expected result**: Event fires with `InstanceInfo` containing `instanceId: 'inst-1'`.
- **Automation**: vitest.

---

- **Test name**: `instance-disconnected event fires when last context of an instance disconnects`
- **Priority**: P1
- **Type**: integration
- **Setup**: Create `BridgeConnection` (host mode). Connect 2 mock plugins with same `instanceId`, different contexts. Subscribe to `instance-disconnected` event.
- **Steps**:
  1. Disconnect both mock plugins.
  2. Check event listener.
- **Expected result**: Event fires once (after the last context disconnects), with the `instanceId`.
- **Automation**: vitest.

---

### 1.3 Pending Request Map

Tests for `src/server/pending-request-map.ts`. New file `src/server/pending-request-map.test.ts`.

- **Test name**: `PendingRequestMap resolves a request on resolveRequest`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Call `map.addRequest('req-001', 5000)` to get a promise.
  2. Call `map.resolveRequest('req-001', { state: 'Edit' })`.
  3. Await the promise.
- **Expected result**: Promise resolves with `{ state: 'Edit' }`.
- **Automation**: vitest.

---

- **Test name**: `PendingRequestMap rejects a request on rejectRequest`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Call `map.addRequest('req-002', 5000)`.
  2. Call `map.rejectRequest('req-002', new Error('Plugin error'))`.
  3. Await the promise.
- **Expected result**: Promise rejects with `Error('Plugin error')`.
- **Automation**: vitest.

---

- **Test name**: `PendingRequestMap rejects on timeout`
- **Priority**: P0
- **Type**: unit
- **Setup**: Use `vi.useFakeTimers()`.
- **Steps**:
  1. Call `map.addRequest('req-003', 100)`.
  2. Advance timers by 100ms.
  3. Await the promise.
- **Expected result**: Promise rejects with a timeout error containing the request ID.
- **Automation**: vitest with fake timers.

---

- **Test name**: `PendingRequestMap cancelAll rejects all pending requests`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Add three requests.
  2. Call `map.cancelAll()`.
  3. Await all three promises.
- **Expected result**: All three reject with a cancellation error.
- **Automation**: vitest.

---

- **Test name**: `PendingRequestMap resolveRequest for unknown ID is a no-op`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Call `map.resolveRequest('nonexistent', {})` with no pending requests.
- **Expected result**: No error thrown. No side effects.
- **Automation**: vitest.

---

- **Test name**: `PendingRequestMap resolveRequest after timeout is a no-op`
- **Priority**: P1
- **Type**: unit
- **Setup**: Use `vi.useFakeTimers()`.
- **Steps**:
  1. Add a request with 100ms timeout.
  2. Advance timers by 100ms (triggers timeout).
  3. Catch the rejection.
  4. Call `resolveRequest` with the same ID.
- **Expected result**: No error thrown on the late resolve. The original rejection stands.
- **Automation**: vitest with fake timers.

---

- **Test name**: `PendingRequestMap handles duplicate request ID by replacing`
- **Priority**: P1
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Add a request with ID `'req-dup'`.
  2. Add a second request with the same ID `'req-dup'`.
  3. Resolve `'req-dup'`.
  4. Verify only the second promise resolves.
- **Expected result**: The first request's promise is rejected (or replaced). The second is resolved.
- **Automation**: vitest.

---

- **Test name**: `PendingRequestMap handles concurrent requests with different IDs`
- **Priority**: P0
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Add `req-a`, `req-b`, `req-c` simultaneously.
  2. Resolve `req-b` first, then `req-a`, then `req-c`.
  3. Verify each promise resolves with its own value.
- **Expected result**: Each promise resolves independently with its corresponding value.
- **Automation**: vitest.

### 1.4 Bridge Host Failover

Tests for `src/bridge/internal/hand-off.ts`, `bridge-host.ts`, and `bridge-client.ts` failover behavior. Full spec: `studio-bridge/plans/tech-specs/08-host-failover.md`.

#### 1.4.1 Hand-off state machine unit tests

- **Test name**: `HandOff state machine transitions from connected to taking-over on host disconnect`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create a `HandOff` instance in `connected` state.
- **Steps**:
  1. Emit `host-disconnected` event.
  2. Check state.
- **Expected result**: State transitions to `taking-over`.
- **Automation**: vitest.

---

- **Test name**: `HandOff state machine transitions from taking-over to promoted on successful port bind`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create a `HandOff` instance in `taking-over` state.
- **Steps**:
  1. Simulate successful port bind.
  2. Check state.
- **Expected result**: State transitions to `promoted`. The instance emits `promoted` event.
- **Automation**: vitest with mocked port bind.

---

- **Test name**: `HandOff state machine transitions from taking-over to reconnected-as-client on failed port bind`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create a `HandOff` instance in `taking-over` state.
- **Steps**:
  1. Simulate failed port bind (EADDRINUSE -- another client won).
  2. Check state.
- **Expected result**: State transitions to `reconnected-as-client`. The instance connects to the new host.
- **Automation**: vitest with mocked port bind.

---

- **Test name**: `HandOff applies random jitter between 0-500ms before attempting port bind`
- **Priority**: P0
- **Type**: unit
- **Setup**: Use `vi.useFakeTimers()`. Create `HandOff` instance.
- **Steps**:
  1. Emit `host-disconnected`.
  2. Check that port bind is NOT attempted immediately.
  3. Advance timers by 500ms.
  4. Check that port bind has been attempted.
- **Expected result**: Bind attempt occurs after the jitter delay, not immediately.
- **Automation**: vitest with fake timers.

---

- **Test name**: `HandOff graceful path: host sends hostTransfer before disconnecting`
- **Priority**: P0
- **Type**: unit
- **Setup**: Mock host connection.
- **Steps**:
  1. Receive `hostTransfer` message from host.
  2. Host WebSocket closes.
  3. Check state transitions.
- **Expected result**: State goes directly to `taking-over` (no jitter on graceful path -- the host explicitly told us to take over).
- **Automation**: vitest.

---

- **Test name**: `HandOff rejects invalid state transitions`
- **Priority**: P1
- **Type**: unit
- **Setup**: None.
- **Steps**:
  1. Attempt to transition from `promoted` to `taking-over`.
  2. Attempt to transition from `connected` to `promoted` (skipping `taking-over`).
- **Expected result**: Both transitions throw or are no-ops. State machine is strictly sequential.
- **Automation**: vitest.

#### 1.4.2 Inflight request handling during failover

- **Test name**: `Inflight action rejects with SessionDisconnectedError when host dies`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start bridge host + bridge client + mock plugin. Use `vi.useFakeTimers()`. Client sends an action through the host.
- **Steps**:
  1. Client calls `session.queryStateAsync()` (action is in-flight, mock plugin does not respond).
  2. Kill the host (close transport server).
  3. Await the action promise.
- **Expected result**: Promise rejects with `SessionDisconnectedError`, NOT `ActionTimeoutError`. The rejection occurs on the next microtask flush after host death detection.
- **Automation**: vitest with `vi.useFakeTimers()`. Restore with `vi.useRealTimers()` in `afterEach`.

---

- **Test name**: `Inflight action rejects with SessionDisconnectedError when plugin disconnects during host death`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start bridge host (process is the host), connect mock plugin, start an action.
- **Steps**:
  1. Call `session.execAsync(...)` (mock plugin delays response).
  2. Close the mock plugin's WebSocket.
  3. Await the action promise.
- **Expected result**: Promise rejects with `SessionDisconnectedError`.
- **Automation**: vitest.

---

- **Test name**: `PendingRequestMap.cancelAll is called on host disconnect, rejecting all inflight requests`
- **Priority**: P0
- **Type**: unit
- **Setup**: Create `PendingRequestMap` with 3 pending requests.
- **Steps**:
  1. Call `cancelAll()`.
  2. Await all 3 promises.
- **Expected result**: All 3 reject with cancellation error. No requests are left pending.
- **Automation**: vitest.

#### 1.4.3 Failover integration tests

- **Test name**: `Graceful shutdown: host disconnects, client takes over`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start bridge host on ephemeral port. Connect bridge client. Connect mock plugin. Use `vi.useFakeTimers()`.
- **Steps**:
  1. Host calls `disconnectAsync()`.
  2. `vi.advanceTimersByTime(2000)` to advance past the takeover window.
  3. Verify client `role === 'host'`.
  4. `vi.advanceTimersByTime(5000)` to advance past plugin reconnection window.
  5. Verify mock plugin reconnects to new host.
  6. Send an action through the new host.
- **Expected result**: Client becomes host after advancing timers. Plugin reconnects. Action succeeds through the new host.
- **Automation**: vitest with `vi.useFakeTimers()` and `vi.advanceTimersByTime()`. Restore with `vi.useRealTimers()` in `afterEach`.

---

- **Test name**: `Hard kill: host dies without notification, client takes over`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start bridge host. Connect bridge client. Connect mock plugin. Use `vi.useFakeTimers()`.
- **Steps**:
  1. Close the host's transport server directly (simulate kill -9).
  2. `vi.advanceTimersByTime(5000)` to advance past the detection + takeover + jitter window.
  3. Verify client `role === 'host'`.
  4. `vi.advanceTimersByTime(5000)` to advance past plugin reconnection window.
  5. Verify mock plugin reconnects.
  6. Send an action through the new host.
- **Expected result**: Client becomes host after advancing timers. Plugin reconnects. Action succeeds.
- **Automation**: vitest with `vi.useFakeTimers()` and `vi.advanceTimersByTime()`. Restore with `vi.useRealTimers()` in `afterEach`.

---

- **Test name**: `Plugin reconnects to new host after graceful failover`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start host. Connect mock plugin. Connect client. Use `vi.useFakeTimers()`.
- **Steps**:
  1. Host calls `disconnectAsync()`.
  2. `vi.advanceTimersByTime(2000)` -- client becomes new host.
  3. `vi.advanceTimersByTime(5000)` -- advance past plugin reconnection window.
  4. Verify mock plugin has sent `register` to new host.
- **Expected result**: Plugin sends `register` to new host after timers are advanced.
- **Automation**: vitest with `vi.useFakeTimers()` and `vi.advanceTimersByTime()`. Restore with `vi.useRealTimers()` in `afterEach`.

---

- **Test name**: `TIME_WAIT recovery: port rebind succeeds with SO_REUSEADDR`
- **Priority**: P0
- **Type**: integration
- **Setup**: Use `vi.useFakeTimers()`.
- **Steps**:
  1. Start a transport server on ephemeral port P with `reuseAddr: true`.
  2. Close the server.
  3. Immediately start a new transport server on the same port P.
  4. `vi.advanceTimersByTime(1000)` to advance past any internal retry delays.
- **Expected result**: Bind succeeds. No `EADDRINUSE` error.
- **Automation**: vitest with `vi.useFakeTimers()`. Restore with `vi.useRealTimers()` in `afterEach`.

---

- **Test name**: `Rapid restart: kill host + new command works after timer advance`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start host. Connect mock plugin. Use `vi.useFakeTimers()`.
- **Steps**:
  1. Close the host.
  2. `vi.advanceTimersByTime(1000)` -- advance past any internal retry delay.
  3. Create a new `BridgeConnection` (which should become the new host).
  4. `vi.advanceTimersByTime(5000)` -- advance past plugin reconnection window.
  5. Verify mock plugin reconnects.
  6. Send an action through the new host.
- **Expected result**: New host accepts connections. Plugin reconnects. Action succeeds.
- **Automation**: vitest with `vi.useFakeTimers()` and `vi.advanceTimersByTime()`. Restore with `vi.useRealTimers()` in `afterEach`.

---

- **Test name**: `Multiple clients: exactly one becomes host, others reconnect as clients`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start host. Connect 3 bridge clients. Connect mock plugin.
- **Steps**:
  1. Kill the host.
  2. Wait for all clients to complete failover.
  3. Count how many clients have `role === 'host'`.
  4. Count how many clients have `role === 'client'`.
- **Expected result**: Exactly 1 host. Exactly 2 clients. All 3 are connected. Plugin reconnects to the host.
- **Automation**: vitest.

---

- **Test name**: `No clients connected: next CLI invocation becomes host, plugin reconnects`
- **Priority**: P1
- **Type**: integration
- **Setup**: Start host. Connect mock plugin. No bridge clients.
- **Steps**:
  1. Stop the host.
  2. Start a new `BridgeConnection`.
  3. Verify it becomes host.
  4. Wait for mock plugin to reconnect.
- **Expected result**: New connection becomes host. Plugin reconnects.
- **Automation**: vitest.

---

- **Test name**: `Jitter prevents thundering herd: bind attempts are spread over 0-500ms`
- **Priority**: P1
- **Type**: integration
- **Setup**: Start host. Connect 5 clients. Use `vi.useFakeTimers()`. Spy on the port-bind function to record when each client attempts to bind.
- **Steps**:
  1. Kill the host.
  2. `vi.advanceTimersByTime(100)` -- verify not all clients have attempted bind yet.
  3. `vi.advanceTimersByTime(500)` -- verify all clients have attempted bind.
  4. Check that bind attempts were spread across different timer ticks (not all at tick 0).
- **Expected result**: Bind attempts are spread across multiple timer advances (indicating jitter is working). No more than 1 client succeeds in binding.
- **Automation**: vitest with `vi.useFakeTimers()` and bind-function spy. Restore with `vi.useRealTimers()` in `afterEach`.

#### 1.4.3.1 Multi-context failover integration tests

- **Test name**: `Multi-context failover: all 3 contexts re-register after host death`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start bridge host on ephemeral port. Connect 3 mock plugins sharing `instanceId: 'inst-1'` with contexts `edit`, `client`, `server`. Connect a bridge client.
- **Steps**:
  1. Kill the host.
  2. Wait for client to become new host.
  3. Wait for all 3 mock plugins to reconnect and re-register with the new host.
  4. Call `listSessions()` on the new host.
- **Expected result**: 3 sessions returned, all with `instanceId: 'inst-1'` and distinct contexts. All sessions are functional (actions can be dispatched to each).
- **Automation**: vitest with ephemeral ports.

---

- **Test name**: `Multi-context failover: partial recovery is visible during reconnection window`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start host. Connect 3 mock plugins (edit/client/server) sharing an instanceId. Connect a client. Configure the `client` context mock plugin with a delayed reconnection (5s extra).
- **Steps**:
  1. Kill the host.
  2. Client becomes new host.
  3. Wait 3 seconds (edit and server reconnect, client has not yet).
  4. Call `listSessions()`.
  5. Wait for client context to reconnect.
  6. Call `listSessions()` again.
- **Expected result**: Step 4 returns 2 sessions (edit, server). Step 6 returns 3 sessions (edit, client, server).
- **Automation**: vitest with configurable reconnection delays.

---

- **Test name**: `Multi-context failover: (instanceId, context) correlation is correct across host death`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start host. Connect 3 mock plugins with `instanceId: 'inst-1'` (edit/client/server) and 1 mock plugin with `instanceId: 'inst-2'` (edit only). Connect a client.
- **Steps**:
  1. Kill the host.
  2. Client becomes new host.
  3. Wait for all 4 plugins to reconnect.
  4. Call `listSessions()`.
- **Expected result**: 4 sessions total. 3 sessions with `instanceId: 'inst-1'` (contexts edit, client, server). 1 session with `instanceId: 'inst-2'` (context edit). No sessions are cross-matched between instances.
- **Automation**: vitest.

#### 1.4.4 Failover observability tests

- **Test name**: `Hand-off state transitions produce debug log messages`
- **Priority**: P1
- **Type**: unit
- **Setup**: Create a `HandOff` instance with a mock logger.
- **Steps**:
  1. Trigger a host disconnect.
  2. Trigger takeover.
  3. Inspect logged messages.
- **Expected result**: Log messages include: component (`bridge:handoff`), state transition (e.g., `connected -> taking-over`), context (port, jitter value, elapsed time).
- **Automation**: vitest with mock logger.

---

- **Test name**: `Health endpoint includes hostUptime and lastFailoverAt fields`
- **Priority**: P1
- **Type**: integration
- **Setup**: Start bridge host. Trigger a failover (kill host, client takes over).
- **Steps**:
  1. Query `/health` on the new host.
  2. Inspect response body.
- **Expected result**: Response includes `hostUptime` (number, milliseconds) and `lastFailoverAt` (ISO 8601 string, not null after failover).
- **Automation**: vitest.

---

- **Test name**: `sessions command during failover prints recovery message`
- **Priority**: P1
- **Type**: unit
- **Setup**: Mock `BridgeConnection` to simulate host-unavailable during recovery.
- **Steps**:
  1. Invoke the sessions command handler.
  2. Capture output.
- **Expected result**: Output contains "Bridge host is recovering. Retry in a few seconds." instead of a generic connection error.
- **Automation**: vitest, capture stdout.

---

- **Test name**: `BridgeConnection.role updates from 'client' to 'host' on promotion`
- **Priority**: P0
- **Type**: integration
- **Setup**: Start host. Connect client.
- **Steps**:
  1. Verify client `role === 'client'`.
  2. Kill the host.
  3. Wait for client to take over.
  4. Verify client `role === 'host'`.
- **Expected result**: Role transitions from `'client'` to `'host'`.
- **Automation**: vitest.

---

## Phase 1 Gate

**Criteria**: All existing tests pass unchanged. v2 protocol fully tested. In-memory session tracking tested. PendingRequestMap tested. Server integrates session tracker. **Bridge host failover tested and passing** -- this is a hard gate because all commands in Phases 2-3 depend on the bridge network recovering from host death.

**Required passing tests**:
1. All existing tests in `web-socket-protocol.test.ts` (unchanged, regression).
2. All existing tests in `web-socket-protocol.smoke.test.ts` (unchanged, regression).
3. All existing tests in `studio-bridge-server.test.ts` (unchanged, regression).
4. All existing tests in `plugin-injector.test.ts` (unchanged, regression).
5. `decodePluginMessage` round-trip for all v2 plugin message types (1.1.1 through 1.1.10).
6. `decodeServerMessage` for all v2 server message types (1.1.11).
7. `encodeMessage` round-trip for all v2 server types (1.1.12).
8. All `PendingRequestMap` tests (1.3).
9. All `SessionTracker` tests (1.2.1).
10. All `BridgeConnection` session tracking tests (1.2.2).
11. In-memory session appears after `startAsync`, is removed after `stopAsync` (2.2 -- see `studio-bridge/plans/execution/validation/02-plugin.md`).
12. v2 handshake via `register` (2.1.1 -- see `studio-bridge/plans/execution/validation/02-plugin.md`).
13. v2 handshake via extended `hello` (2.1.2 -- see `studio-bridge/plans/execution/validation/02-plugin.md`).
14. v1 `hello` still works on v2 server (2.1.3 -- see `studio-bridge/plans/execution/validation/02-plugin.md`).
15. `performActionAsync` sends and resolves (2.1.5 -- see `studio-bridge/plans/execution/validation/02-plugin.md`).
16. `performActionAsync` rejects on timeout (2.1.5 -- see `studio-bridge/plans/execution/validation/02-plugin.md`).
17. `performActionAsync` throws for v1 plugin (2.1.5 -- see `studio-bridge/plans/execution/validation/02-plugin.md`).
18. `performActionAsync` throws for missing capability (2.1.5 -- see `studio-bridge/plans/execution/validation/02-plugin.md`).
19. Concurrent request handling (2.1.6 -- see `studio-bridge/plans/execution/validation/02-plugin.md`).
20. Hand-off state machine transitions -- all unit tests (1.4.1).
21. Inflight request rejection with `SessionDisconnectedError` on host death (1.4.2).
22. Graceful shutdown: client takes over after host disconnect (1.4.3).
23. Hard kill: client takes over after host death (1.4.3).
24. TIME_WAIT recovery: port rebind within 1 second (1.4.3).
25. Rapid restart: kill + new command works after timer advance (1.4.3).
26. Multiple clients: exactly one becomes host (1.4.3).
27. `BridgeConnection.role` updates on promotion (1.4.4).
28. Multi-context session grouping by `(instanceId, context)` (1.2.3).
29. Play mode enter/exit lifecycle -- contexts appear and disappear correctly (1.2.3).
30. Multi-context failover: all 3 contexts re-register after host death (1.4.3.1).
31. Multi-context failover: `(instanceId, context)` correlation correct across host death (1.4.3.1).

32. **Backward compatibility**: v1-only client (sends `hello` without `protocolVersion`) receives a v1-style `welcome` and can `execute` scripts. v2 server does not send any v2-only message types to a v1 session (1.5).
33. **Backward compatibility**: v2 plugin connecting to a future v3 server receives a clamped `protocolVersion: 2` in `welcome` and continues working with v2 features only (3.4 in `01-protocol.md`).
34. **Plugin version warning**: When `pluginVersion` in `hello`/`register` is older than the server's minimum-supported version, the server logs a warning and includes `pluginUpdateAvailable: true` in `welcome`. The handshake still completes (1.5).

**Manual verification**: None required for Phase 1.

**Gate command**:
```bash
cd tools/studio-bridge && npm run test
```
