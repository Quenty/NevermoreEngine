# Phase 1: Foundation

Goal: Extend the protocol, build the bridge host/client module, and wrap `BridgeConnection` in the existing `StudioBridge` export -- without changing any user-visible behavior. All existing tests pass, all existing CLI commands work identically.

References:
- Protocol: `studio-bridge/plans/tech-specs/01-protocol.md`
- Command system: `studio-bridge/plans/tech-specs/02-command-system.md`
- Bridge Network layer: `studio-bridge/plans/tech-specs/07-bridge-network.md`

Base path for all file references: `/workspaces/NevermoreEngine/tools/studio-bridge/`

Cross-references:
- Agent prompts: `studio-bridge/plans/execution/agent-prompts/01-bridge-network.md`
- Validation: `studio-bridge/plans/execution/validation/01-bridge-network.md`
- Failover tasks (1.8-1.10) have been moved to Phase 1b: `01b-failover.md`
- Note: Task 1.7a depends on Phase 0 for output mode utilities (see `00-prerequisites.md`)

---

### Public API Freeze

The following method signatures, type exports, and re-exports from `src/index.ts` MUST remain unchanged throughout Phase 1. Any change to these is a backward-compatibility break:

```typescript
// From StudioBridgeServer (exported as StudioBridge via: export { StudioBridgeServer as StudioBridge }):
constructor(options?: StudioBridgeServerOptions)
startAsync(): Promise<void>
executeAsync(options: ExecuteOptions): Promise<StudioBridgeResult>
stopAsync(): Promise<void>
```

These are consumed by `LocalJobContext` in `/workspaces/NevermoreEngine/tools/nevermore-cli/src/utils/job-context/local-job-context.ts`. New methods and new exports are additive and permitted; changes to the above signatures are not.

---

### Task 1.1: Protocol v2 type definitions

**Description**: Add all v2 message types, capability strings, error codes, and serialization types to the protocol module. Extend the existing `decodePluginMessage` to handle new message types. Add a new `decodeServerMessage` function. Preserve every existing type and function signature unchanged.

**Files to create or modify**:
- Modify: `src/server/web-socket-protocol.ts` -- add base message hierarchy (`BaseMessage`, `RequestMessage extends BaseMessage`, `PushMessage extends BaseMessage`), all v2 `PluginMessage` and `ServerMessage` variants (each extending the appropriate base), `Capability`, `ErrorCode`, `StudioState`, `SerializedValue`, `DataModelInstance` types. `protocolVersion` belongs only in the wire envelope (not in base types). Extend `encodeMessage` to handle v2 types. Extend `decodePluginMessage` switch with new cases. Add `decodeServerMessage`.

**Note on `decodeServerMessage` scope**: This function decodes messages that the *server sends* (welcome, execute, queryState, captureScreenshot, queryDataModel, queryLogs, subscribe, unsubscribe, shutdown, error). It is the counterpart to `decodePluginMessage` (which decodes messages the *plugin sends*). The function is used by test code and by the bridge client (Phase 1, Task 1.3c) to parse messages received from the bridge host. It is NOT used by the server itself (the server creates these messages, it does not parse them).

**Dependencies**: None (first task).

**Complexity**: M

**Acceptance criteria**:
- All existing type exports (`HelloMessage`, `OutputMessage`, `ScriptCompleteMessage`, `WelcomeMessage`, `ExecuteMessage`, `ShutdownMessage`, `PluginMessage`, `ServerMessage`, `OutputLevel`, `encodeMessage`, `decodePluginMessage`) continue to exist with identical signatures.
- New types are exported: `RegisterMessage`, `StateResultMessage`, `ScreenshotResultMessage`, `DataModelResultMessage`, `LogsResultMessage`, `StateChangeMessage`, `HeartbeatMessage`, `SubscribeResultMessage`, `UnsubscribeResultMessage`, `PluginErrorMessage`, `QueryStateMessage`, `CaptureScreenshotMessage`, `QueryDataModelMessage`, `QueryLogsMessage`, `SubscribeMessage`, `UnsubscribeMessage`, `ServerErrorMessage`.
- `decodePluginMessage` returns typed objects for all v2 plugin messages, returns `null` for unknown types.
- `decodeServerMessage` returns typed objects for all v1 and v2 server messages.
- Existing protocol tests in `web-socket-protocol.test.ts` and `web-socket-protocol.smoke.test.ts` pass without modification.
- New unit tests cover every v2 message type encode/decode round-trip.

**V2 message type hierarchy (inlined from tech-spec `01-protocol.md` section 8)**:

The base message hierarchy uses three internal interfaces:

```typescript
interface BaseMessage { type: string; sessionId: string; }
interface RequestMessage extends BaseMessage { requestId: string; }
interface PushMessage extends BaseMessage { /* no requestId */ }
```

`protocolVersion` is a wire envelope field present only on `hello`, `welcome`, and `register` during handshake -- it does NOT belong in the base message types.

**Concrete v2 types to export:**

*Plugin-to-Server:*
- `RegisterMessage extends PushMessage` -- `type: 'register'`, `protocolVersion: number`, payload: `{ pluginVersion, instanceId, context: SessionContext, placeName, placeId, gameId, placeFile?, state: StudioState, pid?, capabilities: Capability[] }`
- `StateResultMessage extends RequestMessage` -- `type: 'stateResult'`, payload: `{ state: StudioState, placeId, placeName, gameId }`
- `ScreenshotResultMessage extends RequestMessage` -- `type: 'screenshotResult'`, payload: `{ data: string, format: 'png', width, height }`
- `DataModelResultMessage extends RequestMessage` -- `type: 'dataModelResult'`, payload: `{ instance: DataModelInstance }`
- `LogsResultMessage extends RequestMessage` -- `type: 'logsResult'`, payload: `{ entries: Array<{ level, body, timestamp }>, total, bufferCapacity }`
- `StateChangeMessage extends PushMessage` -- `type: 'stateChange'`, payload: `{ previousState, newState, timestamp }`
- `HeartbeatMessage extends PushMessage` -- `type: 'heartbeat'`, payload: `{ uptimeMs, state, pendingRequests }`
- `SubscribeResultMessage extends RequestMessage` -- `type: 'subscribeResult'`, payload: `{ events: SubscribableEvent[] }`
- `UnsubscribeResultMessage extends RequestMessage` -- `type: 'unsubscribeResult'`, payload: `{ events: SubscribableEvent[] }`
- `PluginErrorMessage extends BaseMessage` -- `type: 'error'`, `requestId?: string`, payload: `{ code: ErrorCode, message, details? }`

*Server-to-Plugin:*
- `QueryStateMessage extends RequestMessage` -- `type: 'queryState'`, payload: `{}`
- `CaptureScreenshotMessage extends RequestMessage` -- `type: 'captureScreenshot'`, payload: `{ format?: 'png' }`
- `QueryDataModelMessage extends RequestMessage` -- `type: 'queryDataModel'`, payload: `{ path, depth?, properties?, includeAttributes?, find?, listServices? }`
- `QueryLogsMessage extends RequestMessage` -- `type: 'queryLogs'`, payload: `{ count?, direction?, levels?, includeInternal? }`
- `SubscribeMessage extends RequestMessage` -- `type: 'subscribe'`, payload: `{ events: SubscribableEvent[] }`
- `UnsubscribeMessage extends RequestMessage` -- `type: 'unsubscribe'`, payload: `{ events: SubscribableEvent[] }`
- `ServerErrorMessage extends BaseMessage` -- `type: 'error'`, `requestId?: string`, payload: `{ code: ErrorCode, message, details? }`

*Shared types:*
- `StudioState = 'Edit' | 'Play' | 'Paused' | 'Run' | 'Server' | 'Client'`
- `SessionContext = 'edit' | 'client' | 'server'`
- `SubscribableEvent = 'stateChange' | 'logPush'`
- `Capability = 'execute' | 'queryState' | 'captureScreenshot' | 'queryDataModel' | 'queryLogs' | 'subscribe' | 'heartbeat'`
- `ErrorCode` -- 12 string literal union (see `01-protocol.md` section 7.1)
- `SerializedValue` -- union of primitives and typed Roblox values
- `DataModelInstance` -- recursive structure with name, className, path, properties, attributes, childCount, children

See `01-protocol.md` section 8 for the full TypeScript definitions.

### Task 1.2: Request/response correlation layer

**Description**: Build a `PendingRequestMap` utility that tracks in-flight requests by `requestId`, enforces timeouts, and resolves/rejects promises when responses arrive. This is a standalone utility with no dependency on the server or WebSocket.

**Files to create**:
- `src/server/pending-request-map.ts` -- `PendingRequestMap` class with `addRequest(requestId, timeoutMs): Promise<T>`, `resolveRequest(requestId, result)`, `rejectRequest(requestId, error)`, `cancelAll()`.
- `src/server/pending-request-map.test.ts`

**Dependencies**: None.

**Complexity**: S

**Acceptance criteria**:
- `addRequest` returns a promise that resolves when `resolveRequest` is called with the same ID.
- `addRequest` returns a promise that rejects when `rejectRequest` is called with the same ID.
- If neither resolve nor reject is called within `timeoutMs`, the promise rejects with a timeout error.
- `cancelAll` rejects all pending promises.
- Calling `resolveRequest` for an unknown ID is a no-op (does not throw).
- Unit tests cover: happy path, timeout, cancel, duplicate ID, resolve after timeout (no-op).

### Task 1.3a: Transport layer and bridge host

**Description**: Create the low-level transport server and the bridge host that accepts plugin and client WebSocket connections. This is the networking foundation that all other bridge sub-tasks build on. Includes the HTTP health check endpoint and port binding with `SO_REUSEADDR`.

**Files to create**:
- `src/bridge/internal/transport-server.ts` -- WebSocket server with path-based routing (`/plugin`, `/client`, `/health`). Binds to a configurable port (default 38741). Sets `reuseAddr: true` on the underlying `net.Server` to allow rapid port rebind after host death (avoids TIME_WAIT). Emits events for new connections by path.
- `src/bridge/internal/bridge-host.ts` -- Accepts plugin connections on `/plugin`, accepts client connections on `/client`. Manages connection lifecycle (connect, disconnect, error). Routes messages between clients and plugins. Exposes methods for listing connected plugins and clients.
- `src/bridge/internal/health-endpoint.ts` -- HTTP health check handler for `GET /health`. Returns `{ status, port, protocolVersion, serverVersion }`. Returns 404 for non-matching paths.
- `src/bridge/internal/bridge-host.test.ts`
- `src/bridge/internal/transport-server.test.ts`

**Dependencies**: Task 1.1 (protocol types).

**Complexity**: M

**Agent-assignable**: yes (well-scoped networking code)

**Acceptance criteria**:
- `TransportServer` binds to the configured port and accepts WebSocket connections on `/plugin` and `/client` paths.
- `TransportServer` sets `reuseAddr: true` on the underlying `net.Server`.
- `BridgeHost` accepts plugin connections and tracks them by session ID.
- `BridgeHost` accepts client connections and routes messages between clients and plugins.
- `GET /health` returns a JSON response with status, port, protocol version, and server version. Non-`/health` HTTP requests return 404.
- Port binding failure (`EADDRINUSE`) is reported cleanly (not swallowed).
- Unit tests use configurable port to avoid conflicts.

### Task 1.3b: Session tracker and bridge session

**Description**: Build the session tracking layer that manages the in-memory session map and the `BridgeSession` class that wraps action dispatch to a plugin. Sessions are uniquely identified by `(instanceId, context)` and grouped by `instanceId` to represent a single Studio instance.

**Files to create**:
- `src/bridge/internal/session-tracker.ts` -- In-memory session map with `(instanceId, context)` grouping. Tracks session lifecycle: add, remove, list, get by ID, list instances (grouped by `instanceId`). Emits session lifecycle events (connect, disconnect, state-change).
- `src/bridge/bridge-session.ts` -- `BridgeSession` class: handle to a single Studio session with action methods (`execAsync`, `queryStateAsync`, `captureScreenshotAsync`, `queryLogsAsync`, `queryDataModelAsync`, `subscribeAsync`, `unsubscribeAsync`). Wraps action dispatch to the plugin via the bridge host.
- `src/bridge/types.ts` -- `SessionInfo`, `SessionContext`, `InstanceInfo`, `SessionOrigin` type definitions. These are the public types that consumers use to understand session metadata.
- `src/bridge/internal/session-tracker.test.ts`
- `src/bridge/bridge-session.test.ts`

**Dependencies**: Task 1.3a (needs bridge host for plugin message routing).

**Complexity**: M

**Agent-assignable**: yes

**Acceptance criteria**:
- `SessionTracker` maintains a map of sessions keyed by session ID.
- Sessions are uniquely identified by `(instanceId, context)`. Adding a session with the same `(instanceId, context)` replaces the previous one.
- `listInstances()` groups sessions by `instanceId` and returns `InstanceInfo` objects with the list of connected contexts.
- `SessionInfo` includes: `sessionId`, `instanceId`, `context` (`'edit'` | `'client'` | `'server'`), `origin` (`'user'` | `'managed'`), `placeId`, `gameId`, `placeName`, `placeFile`, `state`, `pluginVersion`, `capabilities`, `connectedAt`.
- `BridgeSession` action methods send typed protocol messages to the plugin and wait for correlated responses.
- Session lifecycle events fire on connect, disconnect, and state-change.
- A single Studio instance in Play mode contributes up to 3 sessions (edit, client, server contexts), all grouped by `instanceId`.
- `BridgeSession` methods reject with `SessionDisconnectedError` when the underlying transport disconnects. This is basic "connection lost" behavior, not full failover (host takeover and client promotion are in Phase 1b).

### Task 1.3c: Bridge client and host protocol

**Description**: Build the WebSocket client that connects to an existing bridge host, and the client-to-host envelope protocol that enables forwarding commands through the host. This allows multiple CLI processes to share the same bridge host.

**Files to create**:
- `src/bridge/internal/bridge-client.ts` -- WebSocket client connecting to an existing host on port 38741 via `/client`. Sends command requests, receives results and session updates. Implements the same consumer-facing interface as the host path so `BridgeConnection` callers see no difference.
- `src/bridge/internal/host-protocol.ts` -- `HostEnvelope` and `HostResponse` message types for client-to-host forwarding. Message types: `listSessions`, `commandRequest`, `commandResponse`, `hostTransfer`, `hostReady`.
- `src/bridge/internal/transport-client.ts` -- Low-level WebSocket client with automatic reconnection (exponential backoff). Handles connection lifecycle, send/receive, and disconnect detection.
- `src/bridge/internal/bridge-client.test.ts`
- `src/bridge/internal/transport-client.test.ts`

**Dependencies**: Task 1.3a (needs bridge host to connect to).

**Complexity**: M

**Agent-assignable**: yes

**Acceptance criteria**:
- `BridgeClient` connects to an existing bridge host via WebSocket on `/client`.
- `BridgeClient` can list sessions by sending a `listSessions` envelope to the host.
- `BridgeClient` can send commands to sessions by sending `commandRequest` envelopes and receiving `commandResponse` envelopes.
- `TransportClient` implements automatic reconnection with exponential backoff.
- `HostEnvelope`/`HostResponse` types are well-defined for all client-to-host message types.
- Consumer code using `BridgeClient` cannot tell whether it is talking to the host directly or through the forwarding layer.

### Task 1.3d: BridgeConnection and role detection (split into subtasks 1.3d1-1.3d5)

> **ORCHESTRATOR INSTRUCTION**: Task 1.3d has been split into 5 subtasks to reduce the review checkpoint bottleneck. Subtasks 1.3d1-1.3d4 are agent-assignable and should be executed in sequence (each builds on the previous). Subtask 1.3d5 (barrel export and API surface review) is a review checkpoint that a review agent can verify against the tech spec checklist. Do NOT dispatch any tasks that depend on 1.3d (Wave 3.5 and later: Tasks 1.4, 1.7a, 1.7b, 1.10, 2.3, 4.1, 4.2, 4.3, 2.6, 6.5) until 1.3d5 is validated and merged. Other Wave 3 tasks that do NOT depend on 1.3d (0.5.4, 1.6, 1.9, 2.1) may continue executing in parallel while awaiting the review checkpoint.

**Description**: Build the public API entry point (`BridgeConnection`) that transparently handles host vs. client role detection, and the barrel export for the bridge module. This is the integration task that wires together the transport, session tracker, bridge host, and bridge client into a single cohesive API. Split into 5 subtasks to allow agent execution and reduce the review bottleneck from "review entire BridgeConnection integration" to "review the export surface."

---

#### Task 1.3d1: `BridgeConnection.connectAsync()` and role detection

**Description**: Implement the core `BridgeConnection` class with `connectAsync(options?)` and `disconnectAsync()`, plus the environment detection module that determines host vs. client role. This is the foundational wiring that all other 1.3d subtasks build on.

**Files to create**:
- `src/bridge/bridge-connection.ts` -- `BridgeConnection` class with `connectAsync(options?)`, `disconnectAsync()`, `role` getter, `isConnected` getter. Internally uses `BridgeHost` or `BridgeClient` based on role detection. Stores `BridgeConnectionOptions`, wires up the transport. Events: `error`.
- `src/bridge/internal/environment-detection.ts` -- Detect host vs client role. Algorithm: try to bind port -> host; port taken (`EADDRINUSE`) -> connect as client; stale (health check fails) -> retry bind after delay.
- `src/bridge/bridge-connection.test.ts` -- role detection tests
- `src/bridge/internal/environment-detection.test.ts`

**Dependencies**: Tasks 1.3a, 1.3b, 1.3c.

**Complexity**: M

**Agent-assignable**: yes (well-scoped role detection and lifecycle wiring)

**Acceptance criteria**:
- `BridgeConnection.connectAsync()` binds port 38741 if no host is running (becomes host), or connects as a client if a host already exists.
- Role detection algorithm: try bind -> host; `EADDRINUSE` -> connect as client; stale host (health check fails) -> retry bind after delay.
- Two concurrent `BridgeConnection.connectAsync()` calls on the same port: the first becomes host, the second becomes client.
- `BridgeConnection.role` returns `'host'` or `'client'`.
- `disconnectAsync()` as host triggers the hand-off protocol. As client, simply disconnects.
- Idle behavior: host started by `exec`/`run` exits after a 5-second grace period when no clients and no pending commands. `keepAlive: true` keeps the host alive indefinitely.
- `isConnected` reflects connection state accurately.
- Unit tests use configurable port to avoid conflicts.

**Test specification**:
- **Test 1**: Start `BridgeConnection.connectAsync()` on an unused port. Verify `role === 'host'` and `isConnected === true`.
- **Test 2**: Start two `BridgeConnection.connectAsync()` calls concurrently on the same port. Verify first becomes host, second becomes client.
- **Test 3**: Start a connection, call `disconnectAsync()`. Verify `isConnected === false`.
- **Test 4**: Environment detection: mock port bind success -> returns `'host'`. Mock `EADDRINUSE` -> returns `'client'`.
- **Test 5**: Environment detection: mock `EADDRINUSE` then health check fails -> retry bind after delay -> returns `'host'` (stale host recovery).

---

#### Task 1.3d2: `BridgeConnection.listSessions()` and `listInstances()`

**Description**: Add session query methods to `BridgeConnection` that delegate to the session tracker (from Task 1.3b). As host, queries the local session tracker directly. As client, sends a `listSessions` envelope through the host (via Task 1.3c's bridge client).

**Files to modify**:
- `src/bridge/bridge-connection.ts` -- add `listSessions(): SessionInfo[]` and `listInstances(): InstanceInfo[]` methods.

**Dependencies**: Task 1.3d1.

**Complexity**: S

**Agent-assignable**: yes (delegation to existing session tracker)

**Acceptance criteria**:
- `listSessions()` returns all currently connected plugins with full `SessionInfo` metadata.
- `listInstances()` groups sessions by `instanceId` and returns `InstanceInfo` objects.
- Works correctly in both host mode (direct session tracker query) and client mode (forwarded through host).

**Test specification**:
- **Test 1**: Create a `BridgeConnection` (host mode), connect a mock plugin that sends `register`. Call `listSessions()`. Verify session appears in list with correct metadata.
- **Test 2**: Create a `BridgeConnection` (host mode), connect 3 mock plugins sharing `instanceId` with different contexts. Call `listInstances()`. Verify one instance with 3 contexts.
- **Test 3**: Create host + client connections. Connect a mock plugin to the host. Call `listSessions()` on the client. Verify session is visible through the client.

---

#### Task 1.3d3: `BridgeConnection.resolveSession()`

**Description**: Implement the instance-aware session resolution algorithm on `BridgeConnection`. This is the logic that CLI commands use to determine which session to target based on `--session`, `--instance`, and `--context` flags.

**Files to modify**:
- `src/bridge/bridge-connection.ts` -- add `resolveSession(sessionId?, context?, instanceId?): Promise<BridgeSession>`.

**Dependencies**: Task 1.3d2.

**Complexity**: S

**Agent-assignable**: yes (well-specified algorithm from tech-spec section 2.1)

**Acceptance criteria**:
- `resolveSession()` implements the following instance-aware session resolution algorithm (from `07-bridge-network.md` section 6.7):

```
resolveSession(sessionId?, context?, instanceId?):
  1. If sessionId is provided:
     -> Look up the session by ID.
     -> If found, return it. If not found, throw SessionNotFoundError.

  2. If instanceId is provided:
     -> Look up the instance by instanceId.
     -> If not found, throw SessionNotFoundError.
     -> If found, apply context selection (step 5a-5c below) within that instance.

  3. Collect unique instances from SessionTracker.listInstances().

  4. If 0 instances:
     -> Wait up to timeoutMs for an instance to connect.
     -> If timeout expires, throw ActionTimeoutError.
     -> When an instance connects, continue to step 5.

  5. If 1 instance:
     a. If context is provided:
        -> Look up that context's session within the instance.
        -> If found, return it.
        -> If not found (e.g., --context server but Studio is in Edit mode):
          throw ContextNotFoundError { context, instanceId, availableContexts }
     b. If instance has only 1 context (Edit mode):
        -> Return the Edit session.
     c. If instance has multiple contexts (Play mode):
        -> Return the Edit context session (default).

  6. If N instances (N > 1):
     -> Throw SessionNotFoundError with the instance list, e.g.:
       "Multiple Studio instances connected. Use --session <id> or --instance <id>."
       List each instance with instanceId, placeName, and connected contexts.
```

  **Why Edit is the default in Play mode:** Most CLI operations (exec, query, run) target the Edit context because it represents the authoritative editing environment. Server and Client contexts are transient (destroyed when Play stops). Consumers who want Server or Client must explicitly pass `context: 'server'` or `context: 'client'`.

- `getSession(id)` returns a `BridgeSession` or `undefined`.

**Test specification**:
- **Test 1**: 0 sessions connected -> `resolveSession()` throws an error (or times out waiting).
- **Test 2**: 1 session connected, no args -> `resolveSession()` returns that session.
- **Test 3**: N sessions from different instances, no args -> `resolveSession()` throws with a list of instances for disambiguation.
- **Test 4**: Explicit `sessionId` -> returns that session. Unknown `sessionId` -> throws.
- **Test 5**: 1 instance with 3 contexts (edit, client, server), no context arg -> returns Edit context.
- **Test 6**: 1 instance with 3 contexts, `context: 'server'` -> returns the server context.
- **Test 7**: `instanceId` filter with `context` -> returns matching session.

---

#### Task 1.3d4: `BridgeConnection.waitForSession()`

**Description**: Implement the async wait method that resolves when at least one plugin session connects, or rejects on timeout. Used by `exec` and `run` commands to wait for Studio to connect after launch.

**Files to modify**:
- `src/bridge/bridge-connection.ts` -- add `waitForSession(timeout?): Promise<BridgeSession>`. Wire session-connected events: `session-connected`, `session-disconnected`, `instance-connected`, `instance-disconnected`.

**Dependencies**: Task 1.3d3.

**Complexity**: S

**Agent-assignable**: yes (event-driven promise resolution)

**Acceptance criteria**:
- `waitForSession(timeoutMs)` resolves when at least one plugin connects, or rejects on timeout.
- If a session is already connected when `waitForSession` is called, resolves immediately.
- Session lifecycle events fire correctly: `session-connected`, `session-disconnected`, `instance-connected`, `instance-disconnected`.

**Test specification**:
- **Test 1**: Call `waitForSession()` before any plugin connects. Connect a mock plugin. Verify the promise resolves with the session.
- **Test 2**: Connect a mock plugin first, then call `waitForSession()`. Verify it resolves immediately.
- **Test 3**: Call `waitForSession(500)` with no plugin. Verify it rejects after ~500ms with a timeout error.
- **Test 4**: Subscribe to `session-connected` event. Connect a mock plugin. Verify the event fires with the session.
- **Test 5**: Subscribe to `session-disconnected` event. Connect then disconnect a mock plugin. Verify the event fires with the session ID.

---

#### Task 1.3d5: Barrel export and public API surface review -- REVIEW CHECKPOINT

> **ORCHESTRATOR INSTRUCTION**: This is the only review checkpoint in the 1.3d subtask chain. After subtasks 1.3d1-1.3d4 are complete, the orchestrator dispatches this task to a review agent (or performs the checklist verification itself). Do NOT dispatch any tasks that depend on 1.3d (Wave 3.5 and later) until 1.3d5 is validated and merged.

**Description**: Create the barrel export file for the bridge module and review the public API surface to ensure it matches the specification in `07-bridge-network.md` section 2.1. This is a lightweight review task (~30 minutes) rather than a multi-hour integration review.

**Files to create**:
- `src/bridge/index.ts` -- Barrel export of public API only: `BridgeConnection`, `BridgeConnectionOptions`, `BridgeSession`, `SessionInfo`, `SessionContext`, `InstanceInfo`, `SessionOrigin`. Nothing from `src/bridge/internal/` is re-exported.

**Dependencies**: Tasks 1.3d1, 1.3d2, 1.3d3, 1.3d4.

**Complexity**: XS

**Agent-assignable**: **yes** (review agent verifies that exports match tech spec `07-bridge-network.md` section 2.1 -- the checklist items are concrete and automatable)

**Acceptance criteria**:
- Barrel export exposes only public types; nothing from `internal/` is re-exported.
- Exported types match `07-bridge-network.md` section 2.1 exactly: `BridgeConnection`, `BridgeConnectionOptions`, `BridgeSession`, `SessionInfo`, `SessionContext`, `InstanceInfo`, `SessionOrigin`.
- All public methods on `BridgeConnection` match the spec: `connectAsync`, `disconnectAsync`, `listSessions`, `listInstances`, `getSession`, `waitForSession`, `resolveSession`, `role`, `isConnected`, and the event interface.
- No internal types (`TransportServer`, `BridgeHost`, `BridgeClient`, `SessionTracker`, etc.) leak through the barrel export.

**Review agent verifies**:
- [ ] `BridgeConnection` public API matches tech spec `07-bridge-network.md` section 2.1 signature exactly (every method, property, and event listed in the spec exists with the correct types)
- [ ] No `any` casts outside constructor boundaries (review `bridge-connection.ts`, `bridge-session.ts`, `types.ts` for unnecessary `as any`)
- [ ] All existing tests still pass (`cd tools/studio-bridge && npm run test`)
- [ ] New integration test covers connect -> execute -> disconnect lifecycle (verify in `bridge-connection.test.ts`)
- [ ] `StudioBridge` wrapper delegates without duplicating logic (no copy-pasted session resolution, action dispatch, or lifecycle management that already exists in `BridgeConnection`)

### Task 1.4: Integrate BridgeConnection into StudioBridge class

**Description**: Wrap `BridgeConnection` inside the existing `StudioBridge` export so that library consumers (e.g. `LocalJobContext` in nevermore-cli) see no API change. `StudioBridge.startAsync()` calls `BridgeConnection.connectAsync()` internally, `StudioBridge.executeAsync()` delegates to `BridgeSession.execAsync()`, and `StudioBridge.stopAsync()` calls `BridgeConnection.disconnectAsync()`.

**Files to modify**:
- `src/index.ts` -- replace internal `StudioBridgeServer` usage with `BridgeConnection` and `BridgeSession`. Preserve the public `StudioBridge` class signature (`startAsync`, `executeAsync`, `stopAsync`).

**Dependencies**: Task 1.3d5.

**Complexity**: S

**Acceptance criteria**:
- `new StudioBridge()` / `startAsync()` / `executeAsync()` / `stopAsync()` work identically from the caller's perspective.
- Internally, `startAsync` creates a `BridgeConnection` (with `keepAlive: true`) and waits for a session.
- `executeAsync` delegates to `BridgeSession.execAsync()` on the connected session.
- `stopAsync` calls `disconnectAsync` on the `BridgeConnection`.
- Existing `studio-bridge-server.test.ts` tests pass without modification.
- `index.ts` exports `BridgeConnection`, `BridgeSession`, `BridgeConnectionOptions`, `SessionInfo` from `src/bridge/`.

### Task 1.5: v2 handshake support in StudioBridgeServer

**Description**: Update the server's handshake handler to detect v2 plugins (via `protocolVersion` or `register` message), negotiate capabilities, and store the negotiated protocol version and capability set on the connection. Legacy v1 plugins continue to work unchanged.

**Files to modify**:
- `src/server/studio-bridge-server.ts` -- update `_waitForHandshakeAsync` to handle `register` messages, extract capabilities, respond with appropriate `welcome` (v1 or v2 style).

**Dependencies**: Task 1.1.

**Complexity**: S

**Acceptance criteria**:
- A v1 plugin sending `hello` without `protocolVersion` receives a v1-style `welcome` (no capabilities, no protocolVersion).
- A v2 plugin sending `hello` with `protocolVersion: 2` and `capabilities` receives a v2-style `welcome` with `protocolVersion: 2` and the negotiated `capabilities`.
- A v2 plugin sending `register` receives a v2-style `welcome`.
- The server stores the negotiated protocol version and capabilities on the connection for later use.
- If `pluginVersion` is present and older than the server's minimum-supported plugin version, the server logs a warning and includes `pluginUpdateAvailable: true` in the `welcome` payload. The handshake still completes (backward compatible).
- Heartbeat messages from the plugin are accepted and tracked (last heartbeat timestamp stored).

### Task 1.6: Action dispatch on the server

**Description**: Add a `performActionAsync` method to `StudioBridgeServer` that sends a typed request message to the plugin and waits for the correlated response. Uses `PendingRequestMap` internally. This is the server-side counterpart to the plugin's action handler.

**Files to create or modify**:
- Create: `src/server/action-dispatcher.ts` -- orchestrates sending a request message and waiting for the matching response via `PendingRequestMap`.
- Modify: `src/server/studio-bridge-server.ts` -- add `performActionAsync<T>(message: ServerMessage): Promise<T>`, wire the message listener to route responses through the dispatcher.

**Dependencies**: Tasks 1.1, 1.2, 1.5.

**Complexity**: M

**Acceptance criteria**:
- `performActionAsync` sends a v2 message with a generated `requestId` and returns a promise.
- The promise resolves when the plugin sends a matching response (same `requestId`).
- The promise rejects on timeout (per-message-type defaults from the protocol spec).
- The promise rejects with a structured error if the plugin sends an `error` message with the same `requestId`.
- If called when the negotiated protocol version is 1, `performActionAsync` throws immediately with a clear error ("Plugin does not support v2 actions").
- If called with an action type not in the negotiated capabilities, throws with "Plugin does not support capability: X".
- Existing `executeAsync` continues to work unchanged (it uses the v1 path).

### Task 1.7a: Shared CLI utilities

**Description**: Create the shared CLI utility modules that all commands will use: instance-aware session resolution, output mode formatting, and the minimal handler type. These utilities are the foundation that Task 1.7b's reference command and all Phase 3 commands build on.

**Files to create**:
- `src/cli/resolve-session.ts` -- Instance-aware session resolution with `--session`, `--instance`, `--context` flags. Implements the resolution algorithm: explicit ID lookup, auto-select single instance, context selection within an instance, error on multiple instances.
- `src/cli/format-output.ts` -- Output mode selection (table/JSON/text) using `@quenty/cli-output-helpers/output-modes`.
- `src/cli/types.ts` -- Minimal handler type: `type CommandHandler = (connection: BridgeConnection, options: Record<string, unknown>) => Promise<CommandResult>`.
- `src/cli/resolve-session.test.ts`

**Dependencies**: Task 1.3d5 (needs `BridgeConnection` for session resolution), Phase 0 (output mode utilities).

**Complexity**: S

**Agent-assignable**: yes

**Acceptance criteria**:
- `resolveSession` implements the full resolution algorithm: explicit ID lookup, auto-select single instance, context selection within an instance, error on multiple instances.
- `formatOutput` selects the correct output mode (table/JSON/text) based on CLI flags.
- `CommandHandler` type is exported and matches the pattern: `(connection, options) => Promise<CommandResult>`.
- ~80 LOC total across the three files.
- Unit tests cover: resolve with 0, 1, N sessions; explicit ID; missing ID; context selection.

### Task 1.7b: Reference `sessions` command + barrel export pattern

**Description**: Implement the `sessions` command as the reference pattern that all future commands copy, and establish the barrel export pattern in `src/commands/index.ts` that eliminates per-command modifications to `cli.ts`. This is a merge-conflict mitigation measure: because 7+ tasks need to register commands, having each task modify `cli.ts` directly would cause merge conflicts when tasks run in parallel worktrees. Instead, `cli.ts` imports `allCommands` from the barrel file and registers them in a loop. Each subsequent task only adds an export line to the barrel file (append-only, auto-mergeable).

**Files to create**:
- `src/commands/sessions.ts` -- The reference command handler. Calls `BridgeConnection.listSessions()` to get live session data. Formats the result as a table (summary) and structured JSON (data).
- `src/commands/index.ts` -- Barrel file that re-exports all command handlers and exposes an `allCommands` array. The `sessions` command is the first entry. All surfaces (CLI, terminal, MCP) import from this single barrel file.
- `src/cli/commands/sessions-command.ts` -- CLI wiring (yargs) for the sessions command.

**Files to modify**:
- `src/cli/cli.ts` -- replace per-command `.command()` registration with a loop over `allCommands` from `src/commands/index.ts`. This is the LAST time `cli.ts` is modified for command registration. All future commands are registered by adding an export to the barrel file only.

**Dependencies**: Task 1.7a.

**Complexity**: S

**Agent-assignable**: yes

**Acceptance criteria**:
- The handler is defined in `src/commands/sessions.ts` and wired via `src/cli/commands/sessions-command.ts`.
- `src/commands/index.ts` exports `sessionsCommand` and an `allCommands` array containing it.
- `src/cli/cli.ts` registers commands via `for (const cmd of allCommands) { cli.command(createCliCommand(cmd)); }` -- it does NOT import individual command modules.
- Lists all sessions with columns: Session ID, Instance, Context, Place, State, Origin, Connected duration.
- `--json` flag outputs a JSON array.
- When no bridge host is running, prints: "No bridge host running. Start one with `studio-bridge terminal` or `studio-bridge exec`."
- When the host is running but no plugins are connected, prints: "No active sessions. Is Studio running with the studio-bridge plugin?"
- ~60 LOC total across handler and CLI wiring files (barrel file is additional).
- Establishes the concrete pattern that all future commands copy: create handler file in `src/commands/`, add export to `src/commands/index.ts`. No other files need to change when adding a command.

### Parallelization within Phase 1

Tasks 1.1, 1.2, and 1.3a have no dependencies on each other and can be done in parallel. Task 1.3a (transport and host) should start early as the first step of the bridge module. Tasks 1.3b (sessions) and 1.3c (client) depend on 1.3a but are independent of each other and can run in parallel. Task 1.3d has been split into 5 subtasks: 1.3d1 (role detection) depends on 1.3a, 1.3b, and 1.3c; subtasks 1.3d2-1.3d4 are sequential (each builds on the previous); 1.3d5 (barrel export, review checkpoint) depends on 1.3d4. Tasks 1.4 and 1.5 both depend on earlier tasks but are independent of each other. Task 1.6 depends on 1.1, 1.2, and 1.5. Task 1.7a depends on 1.3d5 (for session resolution) and Phase 0 (for output mode utilities), but can proceed in parallel with 1.4, 1.5, and 1.6. Task 1.7b depends on 1.7a.

Failover tasks (1.8, 1.9, 1.10) have been moved to Phase 1b (`01b-failover.md`). Phase 1b runs in parallel with Phases 2-3 and is NOT a gate for them. Basic `SessionDisconnectedError` handling (rejecting pending actions when the transport disconnects) is part of Phase 1 core (Task 1.3b).

```
Phase 0 (output modes, runs in parallel with Phase 1):
0.1-0.3 (table, json, watch) --> 0.4 (barrel)
                                    |
Phase 1:                            |
1.1 (protocol v2)  ----------+     |
                              +---> 1.5 (v2 handshake) --> 1.6 (action dispatch)
1.2 (pending requests) ------+                              ^
                                                            |
1.3a (transport + host) --+--> 1.3b (sessions) --+          |
                          |                       |          |
                          +--> 1.3c (client) -----+          |
                                                  |          |
                          1.3d1 (role detection) -+          |
                          1.3d2 (listSessions) ---+          |
                          1.3d3 (resolveSession) -+          |
                          1.3d4 (waitForSession) -+          |
                          1.3d5 (barrel export) --+ [REVIEW] |
                                                  |          |
1.3d5 --> 1.4 (StudioBridge wrapper)              |          |
       --+                                        |          |
         +---> 1.7a (shared CLI utils) --> 1.7b (sessions)   |
0.4 (barrel) --+                                             |
                                                             |
1.2 -------------------------------------------------------->+
```

---

## Testing Strategy (Phase 1)

**Unit tests** (run before proceeding to Phase 2):
- Protocol encode/decode for every v2 message type, including malformed input.
- `PendingRequestMap` timeout, resolve, reject, cancel.
- `TransportServer` port binding and WebSocket path routing (Task 1.3a).
- `BridgeHost` plugin and client connection management (Task 1.3a).
- `SessionTracker` session map with `(instanceId, context)` grouping (Task 1.3b).
- `BridgeSession` action dispatch and `SessionDisconnectedError` on transport disconnect (Task 1.3b).
- `BridgeClient` command forwarding through host (Task 1.3c).
- `TransportClient` reconnection with backoff (Task 1.3c).
- `BridgeConnection` host/client role detection (bind port = host, EADDRINUSE = client) (Task 1.3d1).
- Environment detection: host vs client role (Task 1.3d1).
- `BridgeConnection.listSessions()` and `listInstances()` delegation (Task 1.3d2).
- `BridgeConnection.resolveSession()` algorithm: 0, 1, N instances (Task 1.3d3).
- `BridgeConnection.waitForSession()` async wait and timeout (Task 1.3d4).
- Session resolution: 0, 1, N sessions; explicit ID; missing ID; context selection (Task 1.7a).
- Sessions command output formatting (Task 1.7b).

**Integration tests**:
- Start a `BridgeConnection` (becomes host), simulate plugin connecting via `/plugin`, verify `listSessions()` returns the session.
- Start two `BridgeConnection` instances on the same port -- first becomes host, second becomes client (Task 1.3d1).
- Simulate a v2 plugin client connecting via WebSocket, performing handshake with capabilities.
- `SessionTracker` correctly groups multi-context sessions from the same `instanceId`.

**Regression**:
- All existing tests in `web-socket-protocol.test.ts`, `web-socket-protocol.smoke.test.ts`, `studio-bridge-server.test.ts`, `plugin-injector.test.ts` pass unchanged.

Note: Failover tests (graceful shutdown, crash recovery, inflight requests, TIME_WAIT, multi-client takeover) are in Phase 1b (`01b-failover.md`).

---

## Failure Modes

Default policy: **escalate integration issues to review agent, self-fix isolated issues.**

| Task | Likely Failure | Recovery Action |
|------|---------------|-----------------|
| 1.1 (protocol v2 types) | New type definitions break existing `decodePluginMessage` for v1 messages | Self-fix: existing tests catch this. Fix the decode switch to preserve v1 behavior. |
| 1.1 (protocol v2 types) | `BaseMessage`/`RequestMessage` hierarchy conflicts with existing message shapes | Self-fix: adjust hierarchy to make existing types extend correctly. Do not break existing type exports. |
| 1.2 (pending request map) | Timer leaks in tests cause vitest to hang | Self-fix: ensure `afterEach` calls `cancelAll()`. Use `vi.useFakeTimers()` for timeout tests. |
| 1.3a (transport + host) | Port binding race conditions in tests | Self-fix: use ephemeral ports (`port: 0`) in all tests. |
| 1.3a (transport + host) | `SO_REUSEADDR` not supported on all platforms identically | Self-fix: wrap in try/catch, log warning if unsupported. The feature is critical for failover but not for basic operation. |
| 1.3b (session tracker) | `(instanceId, context)` key design does not match how plugins actually register | Escalate: this is a protocol contract issue. Review the register message spec with Phase 0.5/Phase 2 task owners. |
| 1.3c (bridge client) | Client-to-host envelope protocol has version mismatch with host | Self-fix: add version field to `HostEnvelope`, validate on receipt. |
| 1.3d1 (role detection) | Stale host detection (health check after EADDRINUSE) has timing issues | Self-fix: add configurable retry delay and max retries. Test with mock health endpoint. |
| 1.3d3 (resolveSession) | Resolution algorithm does not handle edge case of instance with only client+server contexts (no edit) | Self-fix: adjust default context selection to fall back to first available context if edit is not present. |
| 1.3d5 (barrel export) | Internal types leak through re-exports | Escalate: this is an API surface issue. Human must review the barrel file. |
| 1.4 (StudioBridge wrapper) | Existing `StudioBridge` consumers rely on internal behavior that changes with `BridgeConnection` wrapping | Self-fix if existing tests catch it. Escalate if the breakage is in downstream consumers (nevermore-cli) that are not tested here. |
| 1.5 (v2 handshake) | Capability negotiation produces empty intersection, breaking all actions | Self-fix: ensure server advertises all capabilities it supports. Log a warning if negotiated set is empty. |
| 1.6 (action dispatch) | `performActionAsync` timeout too short for some actions in slow Studio environments | Self-fix: make timeouts configurable per-call with generous defaults. |
| 1.7a (shared CLI utils) | `resolveSession` algorithm does not match the spec in `07-bridge-network.md` | Self-fix: write tests from the spec's resolution table first, then implement to pass. |
| 1.7b (sessions command) | Barrel export `allCommands` pattern does not work with yargs `CommandModule` type system | Escalate: this is a foundational pattern issue. If the barrel pattern is broken, all Phase 2-3 command tasks are blocked. Fix before proceeding. |
