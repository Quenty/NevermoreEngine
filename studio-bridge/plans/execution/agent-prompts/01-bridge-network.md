# Phase 1: Foundation (Bridge Network) -- Agent Prompts

**Phase reference**: [studio-bridge/plans/execution/phases/01-bridge-network.md](../phases/01-bridge-network.md)
**Validation**: [studio-bridge/plans/execution/validation/01-bridge-network.md](../validation/01-bridge-network.md)

Base path for all file references: `/workspaces/NevermoreEngine/tools/studio-bridge/`

## How to Use These Prompts

1. Copy the full prompt for a single task into a Claude Code sub-agent session.
2. The agent should read the "Read First" files, then implement the "Requirements" section.
3. The agent should run the acceptance criteria checks before reporting completion.
4. Do not give an agent a task whose dependencies have not been completed yet (see the dependency graph in [studio-bridge/plans/execution/phases/01-bridge-network.md](../phases/01-bridge-network.md)).

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

## Task 1.1: Protocol v2 Type Definitions

**Prerequisites**: None (first task, no prior tasks required).

**Context**: Studio-bridge is a WebSocket-based tool that runs Luau scripts in Roblox Studio. It uses a JSON protocol with typed messages between a Node.js server and a Roblox Studio plugin. This task extends the protocol from 6 message types to 23 message types, adding support for state queries, screenshots, DataModel inspection, log retrieval, subscriptions, heartbeats, and error reporting.

**Objective**: Add all v2 message types, shared types, and codec functions to the existing protocol module without changing any existing type signatures or breaking existing tests.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/web-socket-protocol.ts` (the file you will modify)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/web-socket-protocol.test.ts` (existing tests that must continue to pass)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/index.ts` (existing exports you must not break)

**Files to Modify**:
- `src/server/web-socket-protocol.ts` -- add all new types, extend `encodeMessage`, extend `decodePluginMessage`, add `decodeServerMessage`

**Files to Create**:
- None (but you will add new test cases to the existing test file or create a new `web-socket-protocol-v2.test.ts`)

**Requirements**:

1. Add these shared types as named exports:

```typescript
export type StudioState = 'Edit' | 'Play' | 'Paused' | 'Run' | 'Server' | 'Client';
export type SubscribableEvent = 'stateChange' | 'logPush';

export type Capability =
  | 'execute'
  | 'queryState'
  | 'captureScreenshot'
  | 'queryDataModel'
  | 'queryLogs'
  | 'subscribe'
  | 'heartbeat';

export type ErrorCode =
  | 'UNKNOWN_REQUEST'
  | 'INVALID_PAYLOAD'
  | 'TIMEOUT'
  | 'CAPABILITY_NOT_SUPPORTED'
  | 'INSTANCE_NOT_FOUND'
  | 'PROPERTY_NOT_FOUND'
  | 'SCREENSHOT_FAILED'
  | 'SCRIPT_LOAD_ERROR'
  | 'SCRIPT_RUNTIME_ERROR'
  | 'BUSY'
  | 'SESSION_MISMATCH'
  | 'INTERNAL_ERROR';

export type SerializedValue =
  | string
  | number
  | boolean
  | null
  | { type: 'Vector3'; value: [number, number, number] }
  | { type: 'Vector2'; value: [number, number] }
  | { type: 'CFrame'; value: [number, number, number, number, number, number, number, number, number, number, number, number] }
  | { type: 'Color3'; value: [number, number, number] }
  | { type: 'UDim2'; value: [number, number, number, number] }
  | { type: 'UDim'; value: [number, number] }
  | { type: 'BrickColor'; name: string; value: number }
  | { type: 'EnumItem'; enum: string; name: string; value: number }
  | { type: 'Instance'; className: string; path: string }
  | { type: 'Unsupported'; typeName: string; toString: string };

export interface DataModelInstance {
  name: string;
  className: string;
  path: string;
  properties: Record<string, SerializedValue>;
  attributes: Record<string, SerializedValue>;
  childCount: number;
  children?: DataModelInstance[];
}
```

2. Add a message hierarchy using three base interfaces (not exported -- internal use for extends):

```typescript
// All messages have type and sessionId
interface BaseMessage {
  type: string;
  sessionId: string;
}

// Request/response messages require a requestId for correlation
interface RequestMessage extends BaseMessage {
  requestId: string;
}

// Push messages have no requestId (unsolicited)
interface PushMessage extends BaseMessage {
  // no requestId
}
```

`protocolVersion` is a wire envelope field (present only on `hello`, `welcome`, `register` during handshake). It does NOT belong in the base message types. Messages that carry it declare it directly on their own interface (e.g., `RegisterMessage` has `protocolVersion: number`).

3. Update existing message interfaces to extend the appropriate base type:
   - `HelloMessage extends PushMessage` -- fire-and-forget handshake initiation
   - `OutputMessage extends PushMessage` -- unsolicited log output
   - `ScriptCompleteMessage extends BaseMessage` -- uses `BaseMessage` (not `RequestMessage`) because `requestId` is optional (present in v2 when the triggering `execute` had one, absent in v1)
   - `WelcomeMessage extends PushMessage` -- handshake response (no requestId)
   - `ExecuteMessage extends BaseMessage` -- uses `BaseMessage` (not `RequestMessage`) because `requestId` is optional (absent in v1, present in v2)
   - `ShutdownMessage extends PushMessage` -- no requestId

   For v2 request/response messages, use `RequestMessage` when `requestId` is always required (e.g., `QueryStateMessage`, `StateResultMessage`, `SubscribeMessage`, etc.). Use `PushMessage` for unsolicited messages (e.g., `HeartbeatMessage`, `StateChangeMessage`). Use `BaseMessage` with `requestId?: string` for messages that bridge v1/v2 (`ScriptCompleteMessage`, `ExecuteMessage`, `PluginErrorMessage`, `ServerErrorMessage`).

4. Add v2 Plugin-to-Server message interfaces (all exported):
   - `RegisterMessage` (type: `'register'`, protocolVersion: number, payload: `{ pluginVersion: string; instanceId: string; placeName: string; placeFile?: string; state: StudioState; pid?: number; capabilities: Capability[] }`)
   - `StateResultMessage` (type: `'stateResult'`, requestId: string, payload: `{ state: StudioState; placeId: number; placeName: string; gameId: number }`)
   - `ScreenshotResultMessage` (type: `'screenshotResult'`, requestId: string, payload: `{ data: string; format: 'png'; width: number; height: number }`)
   - `DataModelResultMessage` (type: `'dataModelResult'`, requestId: string, payload: `{ instance: DataModelInstance }`)
   - `LogsResultMessage` (type: `'logsResult'`, requestId: string, payload: `{ entries: Array<{ level: OutputLevel; body: string; timestamp: number }>; total: number; bufferCapacity: number }`)
   - `StateChangeMessage` (type: `'stateChange'`, payload: `{ previousState: StudioState; newState: StudioState; timestamp: number }`)
   - `HeartbeatMessage` (type: `'heartbeat'`, payload: `{ uptimeMs: number; state: StudioState; pendingRequests: number }`)
   - `SubscribeResultMessage` (type: `'subscribeResult'`, requestId: string, payload: `{ events: SubscribableEvent[] }`)
   - `UnsubscribeResultMessage` (type: `'unsubscribeResult'`, requestId: string, payload: `{ events: SubscribableEvent[] }`)
   - `PluginErrorMessage` (type: `'error'`, payload: `{ code: ErrorCode; message: string; details?: unknown }`)

5. Update the `PluginMessage` union to include all new plugin-to-server types.

6. Add v2 Server-to-Plugin message interfaces (all exported):
   - `QueryStateMessage` (type: `'queryState'`, requestId: string, payload: `{}`)
   - `CaptureScreenshotMessage` (type: `'captureScreenshot'`, requestId: string, payload: `{ format?: 'png' }`)
   - `QueryDataModelMessage` (type: `'queryDataModel'`, requestId: string, payload: `{ path: string; depth?: number; properties?: string[]; includeAttributes?: boolean; find?: { name: string; recursive?: boolean }; listServices?: boolean }`)
   - `QueryLogsMessage` (type: `'queryLogs'`, requestId: string, payload: `{ count?: number; direction?: 'head' | 'tail'; levels?: OutputLevel[]; includeInternal?: boolean }`)
   - `SubscribeMessage` (type: `'subscribe'`, requestId: string, payload: `{ events: SubscribableEvent[] }`)
   - `UnsubscribeMessage` (type: `'unsubscribe'`, requestId: string, payload: `{ events: SubscribableEvent[] }`)
   - `ServerErrorMessage` (type: `'error'`, payload: `{ code: ErrorCode; message: string; details?: unknown }`)

7. Update the `ServerMessage` union to include all new server-to-plugin types.

8. Update `encodeMessage` to handle v2 `ServerMessage` types. Since `encodeMessage` is just `JSON.stringify(msg)`, the implementation does not change, but the type signature must accept the widened union.

9. Extend `decodePluginMessage` with new `case` branches for every v2 plugin message type. Each branch must validate required fields and return `null` for malformed messages. Extract `requestId` and `protocolVersion` from the top-level object when present, pass them through on the returned object. For the `hello` case, also extract optional `capabilities` and `pluginVersion` from the payload.

10. Add a new `decodeServerMessage(raw: string): ServerMessage | null` function. It mirrors `decodePluginMessage` but handles server message types. It validates `type`, `sessionId`, and `payload`, then switches on `type` with cases for all v1 and v2 server messages.

**Code Patterns**:
- Follow the exact pattern of the existing `decodePluginMessage`: parse JSON, validate top-level shape, switch on `type`, validate payload fields, return typed object or `null`.
- Keep the `OutputLevel` type exactly as-is: `'Print' | 'Info' | 'Warning' | 'Error'`.
- The `encodeMessage` function is currently `JSON.stringify`. Keep it that way -- the type widening is what matters.

**Acceptance Criteria**:
- All existing exports (`HelloMessage`, `OutputMessage`, `ScriptCompleteMessage`, `WelcomeMessage`, `ExecuteMessage`, `ShutdownMessage`, `PluginMessage`, `ServerMessage`, `OutputLevel`, `encodeMessage`, `decodePluginMessage`) exist with compatible signatures.
- All new types listed above are exported.
- `decodePluginMessage` correctly decodes all v2 plugin messages and returns `null` for unknown/malformed ones.
- `decodeServerMessage` correctly decodes all v1 and v2 server messages and returns `null` for unknown/malformed ones.
- Run `npx vitest run src/server/web-socket-protocol.test.ts` from `tools/studio-bridge/` -- all existing tests pass.
- Write new tests covering encode/decode round-trips for every v2 message type (at least one test per type).

**Do NOT**:
- Remove or rename any existing type or function.
- Change the shape of any existing message type in a breaking way (adding optional fields is fine).
- Use default exports.
- Forget `.js` extension on local imports.

---

## Task 1.2: Request/Response Correlation Layer

**Prerequisites**: None (independent of other tasks).

**Context**: Studio-bridge is being extended to support concurrent request/response operations over WebSocket. The server needs to track in-flight requests by a unique `requestId`, enforce per-request timeouts, and resolve/reject promises when responses arrive. This utility is standalone -- it has no dependency on WebSocket or the server.

**Objective**: Implement a `PendingRequestMap` class that tracks pending requests by ID with timeout enforcement.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/web-socket-protocol.ts` (for context on how requestIds are used, but you do not import from it)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/studio-bridge-server.ts` (for context on the server patterns, naming conventions, private `_` prefix)

**Files to Create**:
- `src/server/pending-request-map.ts` -- the `PendingRequestMap<T>` class
- `src/server/pending-request-map.test.ts` -- vitest tests

**Requirements**:

1. Implement `PendingRequestMap<T>` with a generic type parameter `T` for the response type:

```typescript
export class PendingRequestMap<T> {
  /**
   * Register a new pending request. Returns a promise that resolves when
   * resolveRequest is called with the same ID, or rejects on timeout.
   */
  addRequestAsync(requestId: string, timeoutMs: number): Promise<T>;

  /**
   * Resolve a pending request with a result. No-op if the ID is not found
   * (e.g., already timed out or resolved).
   */
  resolveRequest(requestId: string, result: T): void;

  /**
   * Reject a pending request with an error. No-op if the ID is not found.
   */
  rejectRequest(requestId: string, error: Error): void;

  /**
   * Reject all pending requests (used during shutdown).
   */
  cancelAll(reason?: string): void;

  /**
   * Number of currently pending requests.
   */
  get pendingCount(): number;

  /**
   * Whether a request with the given ID is currently pending.
   */
  hasPendingRequest(requestId: string): boolean;
}
```

2. Internally, store a `Map<string, { resolve, reject, timer }>`. When `addRequestAsync` is called, create a promise and store the resolve/reject callbacks along with a `setTimeout` handle.

3. On timeout, reject the promise with an `Error` whose message includes the requestId and timeout duration, and remove the entry from the map.

4. `cancelAll` iterates all entries, rejects each with a cancellation error, clears all timers, and empties the map.

5. If `addRequestAsync` is called with a requestId that is already pending, reject the new promise immediately with a duplicate ID error. Do not disturb the existing pending request.

6. `resolveRequest` and `rejectRequest` for unknown IDs are silent no-ops (do not throw).

**Code Patterns**:
- Use the `Async` suffix on the async method: `addRequestAsync`.
- Use `_` prefix for private fields: `private _pending: Map<...>`.
- Use `clearTimeout` when resolving/rejecting to prevent timer leaks.

**Acceptance Criteria**:
- `addRequestAsync` returns a promise that resolves when `resolveRequest` is called with matching ID.
- `addRequestAsync` returns a promise that rejects when `rejectRequest` is called with matching ID.
- Promise rejects with timeout error after `timeoutMs` if neither resolve nor reject is called.
- `cancelAll` rejects all pending promises and clears the map.
- Calling `resolveRequest` for an unknown ID does not throw.
- Calling `rejectRequest` for an unknown ID does not throw.
- Duplicate `addRequestAsync` with same ID rejects the new one immediately.
- `pendingCount` returns the correct count.
- After resolve/reject/timeout, `hasPendingRequest` returns false.
- Run `npx vitest run src/server/pending-request-map.test.ts` from `tools/studio-bridge/` -- all tests pass.

**Do NOT**:
- Import from any other source file in this project (this is standalone).
- Use default exports.
- Forget to clear timers on resolve/reject/cancel to avoid Node.js timer leaks in tests.

---

## Task 1.3d1: BridgeConnection.connectAsync() and Role Detection

**Prerequisites**: Tasks 1.3a (transport + host), 1.3b (session tracker), and 1.3c (bridge client) must be completed first.

**Context**: Studio-bridge uses a bridge network layer where the first CLI process to start becomes the "host" (binds a port, accepts WebSocket connections from plugins and other CLI processes) and subsequent processes become "clients" (connect to the host via WebSocket). This task builds the core `BridgeConnection` class and the environment detection module that determines which role to take.

**Objective**: Implement `BridgeConnection` with `connectAsync(options?)`, `disconnectAsync()`, role detection, and the environment detection module. This is the foundational class that all other 1.3d subtasks build on.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/internal/transport-server.ts` (host transport from Task 1.3a)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/internal/bridge-host.ts` (bridge host from Task 1.3a)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/internal/bridge-client.ts` (bridge client from Task 1.3c)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/internal/session-tracker.ts` (session tracker from Task 1.3b)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/internal/health-endpoint.ts` (health endpoint from Task 1.3a)
- `/workspaces/NevermoreEngine/studio-bridge/plans/tech-specs/07-bridge-network.md` sections 2.1-2.2 (public API spec)

**Files to Create**:
- `src/bridge/bridge-connection.ts` -- `BridgeConnection` class
- `src/bridge/internal/environment-detection.ts` -- role detection utility
- `src/bridge/bridge-connection.test.ts`
- `src/bridge/internal/environment-detection.test.ts`

**Requirements**:

1. Implement `BridgeConnection` class:

```typescript
export interface BridgeConnectionOptions {
  port?: number;          // Default: 38741
  timeoutMs?: number;     // Default: 30_000
  keepAlive?: boolean;    // Default: false
  remoteHost?: string;    // Skip local bind, connect directly
}

export class BridgeConnection {
  // Private constructor -- use connectAsync()
  private constructor(...);

  static async connectAsync(options?: BridgeConnectionOptions): Promise<BridgeConnection>;
  async disconnectAsync(): Promise<void>;

  get role(): 'host' | 'client';
  get isConnected(): boolean;
}
```

2. Implement `environment-detection.ts`:

```typescript
export type DetectedRole = 'host' | 'client';

/**
 * Detect whether this process should be the bridge host or a client.
 * Algorithm:
 * 1. If remoteHost is specified -> client
 * 2. Try to bind port -> host
 * 3. EADDRINUSE -> check health endpoint
 *    a. Health check succeeds -> client (host is alive)
 *    b. Health check fails -> wait, retry bind (stale host in TIME_WAIT)
 */
export async function detectRoleAsync(options: {
  port: number;
  remoteHost?: string;
}): Promise<{ role: DetectedRole; /* ... */ }>;
```

3. In `connectAsync`:
   - Call `detectRoleAsync` to determine role.
   - If host: create `TransportServer` and `BridgeHost`, start listening.
   - If client: create `TransportClient` and `BridgeClient`, connect to host.
   - Store role and internal components on private fields.
   - Set up idle exit behavior: if `keepAlive` is false, start a 5-second grace timer when no clients and no pending commands.

4. In `disconnectAsync`:
   - If host: trigger hand-off protocol (or clean shutdown if no clients).
   - If client: close WebSocket connection.

**Code Patterns**:
- Private `_` prefix on all private fields.
- `Async` suffix on async methods.
- `.js` extension on all local imports.
- No default exports.

**Acceptance Criteria**:
- `connectAsync()` on unused port: `role === 'host'`, `isConnected === true`.
- Two concurrent `connectAsync()` on same port: first is host, second is client.
- `disconnectAsync()` sets `isConnected === false`.
- Environment detection: `EADDRINUSE` -> client. Bind success -> host. Stale host -> retry bind.
- `remoteHost` option -> always client.
- Unit tests use configurable port (pass `port: 0` or ephemeral port) to avoid conflicts.
- Run `npx vitest run src/bridge/bridge-connection.test.ts` -- all tests pass.
- Run `npx vitest run src/bridge/internal/environment-detection.test.ts` -- all tests pass.

**Do NOT**:
- Add session query methods yet (those are Task 1.3d2).
- Add `resolveSession` yet (Task 1.3d3).
- Add `waitForSession` or events yet (Task 1.3d4).
- Create the barrel export `index.ts` yet (Task 1.3d5).
- Use default exports.
- Forget `.js` extensions on local imports.

---

## Task 1.3d2: BridgeConnection.listSessions() and listInstances()

**Prerequisites**: Task 1.3d1 must be completed first.

**Context**: `BridgeConnection` (from Task 1.3d1) needs session query methods so that CLI commands and other consumers can discover which Studio sessions are connected. As host, these methods query the local `SessionTracker` directly. As client, they send a `listSessions` envelope through the bridge host.

**Objective**: Add `listSessions()` and `listInstances()` methods to the existing `BridgeConnection` class.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/bridge-connection.ts` (from Task 1.3d1 -- the file you will modify)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/internal/session-tracker.ts` (session tracker from Task 1.3b)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/internal/bridge-client.ts` (for client-side forwarding)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/types.ts` (SessionInfo, InstanceInfo types from Task 1.3b)
- `/workspaces/NevermoreEngine/studio-bridge/plans/tech-specs/07-bridge-network.md` section 2.1 (API spec)

**Files to Modify**:
- `src/bridge/bridge-connection.ts` -- add `listSessions()` and `listInstances()` methods
- `src/bridge/bridge-connection.test.ts` -- add tests

**Requirements**:

1. Add `listSessions()` to `BridgeConnection`:

```typescript
/** List all currently connected Studio sessions (across all instances and contexts). */
listSessions(): SessionInfo[] {
  if (this._role === 'host') {
    return this._sessionTracker.listSessions();
  }
  // Client path: delegate to bridge client which sends listSessions envelope
  return this._bridgeClient.listSessions();
}
```

2. Add `listInstances()` to `BridgeConnection`:

```typescript
/**
 * List unique Studio instances. Each instance groups 1-3 context sessions
 * (edit, client, server) that share the same instanceId.
 */
listInstances(): InstanceInfo[] {
  if (this._role === 'host') {
    return this._sessionTracker.listInstances();
  }
  return this._bridgeClient.listInstances();
}
```

3. Add `getSession(sessionId)` to return a `BridgeSession` or `undefined`.

**Acceptance Criteria**:
- Host mode: `listSessions()` returns sessions from the local session tracker.
- Host mode: `listInstances()` groups sessions by `instanceId`.
- Client mode: `listSessions()` and `listInstances()` forward through the bridge client and return correct results.
- `getSession(id)` returns `BridgeSession` or `undefined`.
- Run `npx vitest run src/bridge/bridge-connection.test.ts` -- all tests pass.

**Do NOT**:
- Add `resolveSession` (Task 1.3d3).
- Add `waitForSession` or events (Task 1.3d4).
- Create the barrel export (Task 1.3d5).
- Use default exports.
- Forget `.js` extensions on local imports.

---

## Task 1.3d3: BridgeConnection.resolveSession()

**Prerequisites**: Task 1.3d2 must be completed first (provides `listSessions()` and `listInstances()`).

**Context**: CLI commands need to resolve which session to target. The resolution algorithm is instance-aware: it groups sessions by `instanceId`, auto-selects when unambiguous, and throws descriptive errors when disambiguation is needed.

**Objective**: Add `resolveSession()` to the existing `BridgeConnection` class.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/bridge-connection.ts` (from Tasks 1.3d1-1.3d2 -- the file you will modify)
- `/workspaces/NevermoreEngine/studio-bridge/plans/tech-specs/07-bridge-network.md` section 2.1 (resolution algorithm specification)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/types.ts` (SessionContext type)

**Files to Modify**:
- `src/bridge/bridge-connection.ts` -- add `resolveSession()` method
- `src/bridge/bridge-connection.test.ts` -- add tests

**Requirements**:

1. Implement `resolveSession()`:

```typescript
/**
 * Resolve a session for command execution. Instance-aware.
 *
 * Algorithm (full pseudocode -- implement exactly):
 *
 * 1. If sessionId provided:
 *    a. Look up session by sessionId in the session tracker.
 *    b. If found, return it.
 *    c. If not found, throw SessionNotFoundError("Session '<sessionId>' not found").
 *
 * 2. If instanceId provided:
 *    a. Filter sessions to those with matching instanceId.
 *    b. If 0 matches, throw SessionNotFoundError("No sessions for instance '<instanceId>'").
 *    c. If context also provided, filter to matching context.
 *       - If match found, return it.
 *       - If not, throw ContextNotFoundError("Context '<context>' not connected on instance '<instanceId>'").
 *    d. If no context provided:
 *       - If 1 session, return it.
 *       - If N sessions, return Edit context (default for Play mode).
 *
 * 3. Collect unique instances (group sessions by instanceId).
 *
 * 4. If 0 instances:
 *    throw SessionNotFoundError("No sessions connected").
 *
 * 5. If 1 instance:
 *    a. If context provided, return matching context session.
 *       Throw ContextNotFoundError if not found.
 *    b. If 1 context session on the instance, return it.
 *    c. If N context sessions (Play mode: edit + client + server),
 *       return Edit context by default.
 *       Rationale: in Play mode, the Edit context is the most broadly
 *       useful target (it can see the full DataModel including
 *       ReplicatedStorage, ServerStorage, etc.).
 *
 * 6. If N instances:
 *    throw SessionNotFoundError(
 *      "Multiple instances connected: [<list>]. Use --session or --instance to select one."
 *    ).
 *
 * Error types used:
 *   - SessionNotFoundError: no session matches the criteria
 *   - ContextNotFoundError: instance found but requested context is not connected
 *   - ActionTimeoutError: (not used here, but defined for completeness)
 */
async resolveSession(
  sessionId?: string,
  context?: SessionContext,
  instanceId?: string
): Promise<BridgeSession>;
```

2. Error messages must be descriptive:
   - 0 sessions: "No sessions connected"
   - N instances without disambiguation: "Multiple instances connected: [list]. Use --session or --instance to select one."
   - Unknown sessionId: "Session 'abc' not found"
   - Context not found on instance: "Context 'server' not connected on instance 'inst-1'"

**Acceptance Criteria**:
- 0 sessions -> throws with "No sessions connected".
- 1 session -> returns it automatically.
- N sessions from different instances -> throws with instance list.
- Explicit `sessionId` -> returns that session. Unknown -> throws.
- 1 instance with 3 contexts, no context arg -> returns Edit.
- 1 instance with 3 contexts, `context: 'server'` -> returns server.
- `instanceId` + `context` -> returns matching session.
- Run `npx vitest run src/bridge/bridge-connection.test.ts` -- all tests pass.

**Do NOT**:
- Add `waitForSession` or events (Task 1.3d4).
- Create the barrel export (Task 1.3d5).
- Use default exports.
- Forget `.js` extensions on local imports.

---

## Task 1.3d4: BridgeConnection.waitForSession() and Events

**Prerequisites**: Task 1.3d3 must be completed first.

**Context**: Commands like `exec` and `run` need to wait for a Studio plugin to connect before executing. The `waitForSession` method provides an async wait with timeout. Session lifecycle events allow consumers to react to sessions connecting and disconnecting.

**Objective**: Add `waitForSession()` and session lifecycle events to the existing `BridgeConnection` class.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/bridge-connection.ts` (from Tasks 1.3d1-1.3d3 -- the file you will modify)
- `/workspaces/NevermoreEngine/studio-bridge/plans/tech-specs/07-bridge-network.md` section 2.1 (event interface specification)

**Files to Modify**:
- `src/bridge/bridge-connection.ts` -- add `waitForSession()`, wire events
- `src/bridge/bridge-connection.test.ts` -- add tests

**Requirements**:

1. Add `waitForSession()`:

```typescript
/**
 * Wait for at least one session to connect.
 * Resolves with the first session that connects (or the first session
 * if one is already connected). Rejects after timeout.
 */
async waitForSession(timeout?: number): Promise<BridgeSession>;
```

2. Wire session lifecycle events on `BridgeConnection` (extends `EventEmitter` or uses a typed event pattern):

```typescript
on(event: 'session-connected', listener: (session: BridgeSession) => void): this;
on(event: 'session-disconnected', listener: (sessionId: string) => void): this;
on(event: 'instance-connected', listener: (instance: InstanceInfo) => void): this;
on(event: 'instance-disconnected', listener: (instanceId: string) => void): this;
on(event: 'error', listener: (error: Error) => void): this;
```

3. Implementation of `waitForSession`:
   - Check if any sessions are already connected. If so, resolve immediately.
   - Otherwise, listen for the `session-connected` event and resolve when it fires.
   - Set a timeout that rejects with a descriptive error if no session connects in time.
   - Clean up event listeners on resolve or reject.

**Acceptance Criteria**:
- `waitForSession()` called before plugin connects -> resolves when plugin connects.
- `waitForSession()` called when sessions exist -> resolves immediately.
- `waitForSession(500)` with no plugin -> rejects after ~500ms with timeout error.
- `session-connected` event fires when a plugin registers.
- `session-disconnected` event fires when a plugin disconnects.
- `instance-connected` event fires when the first context of a new instance connects.
- `instance-disconnected` event fires when the last context of an instance disconnects.
- Run `npx vitest run src/bridge/bridge-connection.test.ts` -- all tests pass.

**Do NOT**:
- Create the barrel export (Task 1.3d5).
- Use default exports.
- Forget `.js` extensions on local imports.

---

## Task 1.3: In-Memory Session Tracking via BridgeConnection

> **SUPERSEDED**: This task has been decomposed into Tasks 1.3a (transport + host), 1.3b (session tracker), 1.3c (bridge client), and 1.3d1-1.3d5 (BridgeConnection integration). Do NOT implement this task directly -- implement the subtasks instead. The subtask prompts above (1.3d1, 1.3d2, 1.3d3, 1.3d4) contain the authoritative requirements. This section is retained only for historical context.

---

## Task 1.4: Integrate Session Tracking into StudioBridgeServer

**Prerequisites**: Task 1.3d5 (barrel export and API surface review) must be completed first.

**Context**: Studio-bridge's `StudioBridgeServer` class manages the WebSocket server lifecycle. This task adds in-memory session tracking so that connected plugins are discoverable by CLI processes via the bridge host.

**Objective**: Modify `StudioBridgeServer` to track sessions in-memory when plugins connect and untrack them when plugins disconnect.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/studio-bridge-server.ts` (the file you will modify)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/bridge-connection.ts` (the BridgeConnection with in-memory session tracking -- must be completed first)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/registry/types.ts` (SessionInfo types)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/index.ts` (exports to update)

**Files to Modify**:
- `src/server/studio-bridge-server.ts` -- add session tracking via BridgeConnection when plugins connect/disconnect
- `src/index.ts` -- add exports for BridgeConnection and registry types

**Requirements**:

1. Import `BridgeConnection` from `./bridge-connection.js` and `SessionInfo` from `../registry/index.js`.

2. When a plugin connects and sends a `register` message, create a `SessionInfo` entry in the bridge host's in-memory session map:

```typescript
const sessionInfo: SessionInfo = {
  sessionId: this._sessionId,
  placeName: registerPayload.placeName,
  placeFile: registerPayload.placeFile,
  state: 'starting',
  pluginVersion: registerPayload.pluginVersion,
  capabilities: registerPayload.capabilities,
  connectedAt: new Date().toISOString(),
  origin: this._origin ?? 'user',
};
this._bridgeConnection.addSession(sessionInfo);
```

3. Update the session state at key lifecycle points:
   - After handshake completes: update session state to `'ready'`
   - When executing: update session state to `'executing'`
   - After execution: update session state to `'ready'`

4. When the plugin's WebSocket closes, remove the session from the in-memory map. Sessions exist only while plugins are connected; no stale detection needed.

5. In `src/index.ts`, add:

```typescript
export { BridgeConnection } from './server/bridge-connection.js';
export type { SessionInfo, SessionEvent, SessionOrigin, Disposable } from './registry/index.js';
```

**Acceptance Criteria**:
- After a plugin connects and registers, `listSessionsAsync()` includes the session.
- After a plugin disconnects, `listSessionsAsync()` no longer includes the session.
- Session state is updated at lifecycle transitions.
- `SessionInfo` includes the `origin` field (`'user' | 'managed'`).
- Existing tests in `studio-bridge-server.test.ts` (if any) pass without modification.
- The `index.ts` exports `BridgeConnection` and registry types.

**Do NOT**:
- Use any file-based session tracking (no session files, no lock files, no PID files).
- Change any existing method signatures on `StudioBridgeServer`.
- Change the constructor signature (no new required options).
- Use default exports.
- Forget `.js` extensions on local imports.

---

## Task 1.5: v2 Handshake Support in StudioBridgeServer

**Prerequisites**: Task 1.1 (protocol v2 type definitions) must be completed first.

**Context**: Studio-bridge's WebSocket server currently handles only v1 `hello`/`welcome` handshakes. The persistent plugin will use v2 handshakes with `protocolVersion`, `capabilities`, and optionally `register` messages. The server must detect the protocol version and negotiate capabilities while keeping v1 plugins working unchanged.

**Objective**: Update the server's handshake handler to support v2 plugins via `hello` with `protocolVersion`/`capabilities` and `register` messages, while preserving v1 behavior.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/studio-bridge-server.ts` (the file you will modify -- focus on `_waitForHandshakeAsync`)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/web-socket-protocol.ts` (must already contain v2 types from Task 1.1)

**Files to Modify**:
- `src/server/studio-bridge-server.ts` -- update `_waitForHandshakeAsync` method, add private fields for connection metadata

**Requirements**:

1. Add private fields to `StudioBridgeServer`:

```typescript
private _negotiatedProtocolVersion: number = 1;
private _negotiatedCapabilities: Capability[] = ['execute'];
private _lastHeartbeatTimestamp: number | undefined;
```

2. Import the new types: `Capability`, `RegisterMessage`, `HeartbeatMessage` (and others needed) from `./web-socket-protocol.js`.

3. In `_waitForHandshakeAsync`, update the `onMessage` handler to accept both `hello` and `register` messages:
   - If `msg.type === 'hello'`:
     - Check for `msg.protocolVersion`. If present and >= 2, this is a v2 hello.
     - Extract `capabilities` from `msg.payload.capabilities` (default to `['execute']` if absent).
     - Negotiate: `_negotiatedProtocolVersion = Math.min(msg.protocolVersion ?? 1, 2)`.
     - Negotiate capabilities: `_negotiatedCapabilities` = intersection of plugin's capabilities and server's supported set (`['execute', 'queryState', 'captureScreenshot', 'queryDataModel', 'queryLogs', 'subscribe']`).
     - Send welcome: if v2, include `protocolVersion` and `capabilities` in the welcome. If v1, send the existing v1 welcome (no protocolVersion, no capabilities).
   - If `msg.type === 'register'`:
     - This is always v2. Extract all fields from the register payload.
     - Negotiate protocol version and capabilities same as above.
     - Send a v2 welcome with protocolVersion and capabilities.
     - Store the extra metadata (pluginVersion, instanceId, placeName, etc.) on private fields if useful for logging.

4. After handshake, set up a listener for `heartbeat` messages on the connected WebSocket:
   - When a `heartbeat` message is received, update `_lastHeartbeatTimestamp = Date.now()`.
   - Do not send a response to heartbeats (the server is silent).
   - Log heartbeat receipt at verbose level.

5. Add public getters:

```typescript
get protocolVersion(): number { return this._negotiatedProtocolVersion; }
get capabilities(): readonly Capability[] { return this._negotiatedCapabilities; }
```

**Acceptance Criteria**:
- A v1 plugin sending `hello` without `protocolVersion` receives a v1-style `welcome` (no `protocolVersion`, no `capabilities` in payload).
- A v2 plugin sending `hello` with `protocolVersion: 2` and `capabilities: [...]` receives a v2-style `welcome` with `protocolVersion: 2` and the negotiated capabilities.
- A v2 plugin sending `register` with full metadata receives a v2-style `welcome`.
- `protocolVersion` getter returns the negotiated version after handshake.
- `capabilities` getter returns the negotiated capabilities after handshake.
- Heartbeat messages are accepted silently (no error, no response).
- Existing v1 handshake behavior is unchanged.

**Do NOT**:
- Change the `startAsync`, `executeAsync`, or `stopAsync` method signatures.
- Remove or rename any existing public API.
- Use default exports.
- Forget `.js` extensions on local imports.

---

## Task 1.6: Action Dispatch on the Server

**Prerequisites**: Tasks 1.1 (protocol v2 types), 1.2 (PendingRequestMap), and 1.5 (v2 handshake support) must be completed first.

**Context**: Studio-bridge's server needs to send typed request messages to the plugin and wait for correlated responses. The `PendingRequestMap` (Task 1.2) handles timeout/correlation mechanics. This task builds the dispatch layer that connects the WebSocket message flow to the pending request map.

**Objective**: Add an `ActionDispatcher` class and wire it into `StudioBridgeServer` so the server can perform v2 actions (queryState, captureScreenshot, etc.) and receive typed responses.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/studio-bridge-server.ts` (the server you will modify)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/pending-request-map.ts` (the correlation utility from Task 1.2)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/web-socket-protocol.ts` (v2 types from Task 1.1)

**Files to Create**:
- `src/server/action-dispatcher.ts` -- `ActionDispatcher` class
- `src/server/action-dispatcher.test.ts` -- tests

**Files to Modify**:
- `src/server/studio-bridge-server.ts` -- add `performActionAsync` method, wire incoming messages to the dispatcher

**Requirements**:

1. Implement `ActionDispatcher` in `src/server/action-dispatcher.ts`:

```typescript
import { randomUUID } from 'crypto';
import { PendingRequestMap } from './pending-request-map.js';
import type { ServerMessage, PluginMessage } from './web-socket-protocol.js';

/** Default timeouts per action type (milliseconds) */
const ACTION_TIMEOUTS: Record<string, number> = {
  queryState: 5_000,
  captureScreenshot: 15_000,
  queryDataModel: 10_000,
  queryLogs: 10_000,
  execute: 120_000,
  subscribe: 5_000,
  unsubscribe: 5_000,
};

export class ActionDispatcher {
  private _pendingRequests = new PendingRequestMap<PluginMessage>();

  /**
   * Generate a requestId and register the pending request.
   * Returns { requestId, promise } where promise resolves with the response message.
   */
  createRequestAsync(
    actionType: string,
    timeoutMs?: number
  ): { requestId: string; responsePromise: Promise<PluginMessage> };

  /**
   * Route an incoming plugin message to the correct pending request.
   * Returns true if the message was consumed (matched a pending requestId).
   */
  handleResponse(message: PluginMessage): boolean;

  /** Cancel all pending requests (called on shutdown/disconnect) */
  cancelAll(reason?: string): void;

  /** Number of in-flight requests */
  get pendingCount(): number;
}
```

2. `createRequestAsync` implementation:
   - Generate a `requestId` using `randomUUID()`.
   - Look up timeout from `ACTION_TIMEOUTS[actionType]`, override with `timeoutMs` if provided.
   - Call `this._pendingRequests.addRequestAsync(requestId, timeout)` to get the response promise.
   - Return `{ requestId, responsePromise }`.

3. `handleResponse` implementation:
   - Check if `message.requestId` exists and is a string.
   - If so, check if `_pendingRequests.hasPendingRequest(message.requestId)`.
   - If message type is `'error'`, call `rejectRequest` with an error constructed from the error payload.
   - Otherwise, call `resolveRequest` with the message.
   - Return `true` if consumed, `false` if no matching pending request.

4. In `StudioBridgeServer`, add:
   - A private `_actionDispatcher = new ActionDispatcher()` field.
   - A public `performActionAsync<T extends PluginMessage>(message: Omit<ServerMessage, 'requestId'>, timeoutMs?: number): Promise<T>` method:
     - Throws if `_negotiatedProtocolVersion < 2` with message "Plugin does not support v2 actions".
     - Throws if the action type requires a capability not in `_negotiatedCapabilities` with message "Plugin does not support capability: X".
     - Calls `_actionDispatcher.createRequestAsync(message.type, timeoutMs)`.
     - Sends the message with the generated `requestId` via `encodeMessage` and `ws.send`.
     - Returns the response promise cast to `T`.
   - In the connected WebSocket's message handler (after handshake), route received messages through `_actionDispatcher.handleResponse(msg)` before any other handling.
   - In `_cleanupResourcesAsync`, call `_actionDispatcher.cancelAll()`.

5. The existing `executeAsync` method continues to work unchanged via the v1 path. It does not use the action dispatcher.

**Acceptance Criteria**:
- `performActionAsync` sends a v2 message with a `requestId` and resolves when the plugin responds.
- `performActionAsync` rejects on timeout.
- `performActionAsync` rejects with structured error if plugin sends an `error` message with matching `requestId`.
- `performActionAsync` throws immediately if `protocolVersion < 2`.
- `performActionAsync` throws immediately if the required capability is not negotiated.
- `cancelAll` rejects all pending requests.
- Existing `executeAsync` works unchanged.
- Unit tests for `ActionDispatcher` cover: happy path, timeout, error response, cancel, unknown message.

**Do NOT**:
- Modify the existing `executeAsync` method to use the action dispatcher (keep the v1 path).
- Change any existing public API signatures.
- Use default exports.
- Forget `.js` extensions on local imports.

---

## Task 1.7a: Shared CLI Utilities

**Prerequisites**: Tasks 1.3d5 (BridgeConnection barrel export) and Phase 0 Task 0.4 (output mode selector) must be completed first.

**Context**: Every CLI command in studio-bridge needs to resolve which session to target, format output for different modes (text, JSON, CI), and follow a consistent handler pattern. This task creates the shared utilities that all commands will import.

**Objective**: Create three small utility modules that establish the shared patterns for CLI commands: session resolution, output formatting, and the command handler type.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/bridge-connection.ts` (the `BridgeConnection` API with session resolution)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/commands/exec-command.ts` (existing CLI command pattern)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/args/global-args.ts` (global args interface)

**Files to Create**:
- `src/cli/resolve-session.ts` -- instance-aware session resolution
- `src/cli/format-output.ts` -- output mode selection
- `src/cli/types.ts` -- minimal handler type

**Requirements**:

1. Implement `src/cli/resolve-session.ts`:

```typescript
import type { BridgeConnection } from '../server/bridge-connection.js';
import type { SessionInfo } from '../registry/types.js';

export interface ResolveSessionOptions {
  sessionId?: string;
  instanceId?: string;
  context?: string;
}

/**
 * Resolve which session to target based on CLI args.
 * - If sessionId is provided, look it up directly.
 * - If instanceId is provided, find sessions for that instance, optionally filtered by context.
 * - If nothing is provided, use the sole session or throw if ambiguous.
 */
export async function resolveSessionAsync(
  connection: BridgeConnection,
  options: ResolveSessionOptions
): Promise<SessionInfo> {
  // Implementation:
  // 1. If options.sessionId, call connection.getSession(sessionId). Throw if not found.
  // 2. Otherwise, call connection.listSessionsAsync().
  // 3. If options.instanceId, filter by instanceId. If options.context, further filter.
  // 4. If exactly one result, return it.
  // 5. If zero results, throw with "No matching sessions found".
  // 6. If multiple results, throw with "Multiple sessions found, use --session or --instance to disambiguate".
}
```

2. Implement `src/cli/format-output.ts`:

```typescript
import { resolveOutputMode, formatTable, formatJson } from '@quenty/cli-output-helpers/output-modes';

export interface FormatOptions {
  json?: boolean;
}

/**
 * Format data for output based on the resolved output mode.
 * If --json is set, outputs JSON. Otherwise outputs a formatted table.
 */
export function formatOutput(data: unknown, options: FormatOptions): string {
  const mode = resolveOutputMode(options);
  if (mode === 'json') {
    return formatJson(data);
  }
  return formatTable(data);
}
```

Note: If `@quenty/cli-output-helpers/output-modes` does not exist yet (it is a Phase 0 deliverable), create a minimal placeholder that:
- `resolveOutputMode` returns `'json'` if `options.json` is true, `'text'` otherwise
- `formatJson` returns `JSON.stringify(data, null, 2)`
- `formatTable` returns a simple columnar string representation

3. Implement `src/cli/types.ts`:

```typescript
import type { BridgeConnection } from '../server/bridge-connection.js';

export interface CommandResult {
  data: unknown;
  summary: string;
}

export type CommandHandler = (
  connection: BridgeConnection,
  options: Record<string, unknown>
) => Promise<CommandResult>;
```

**Acceptance Criteria**:
- `resolveSessionAsync` resolves a session by ID when provided.
- `resolveSessionAsync` returns the sole session when no filters are provided and exactly one session exists.
- `resolveSessionAsync` throws a descriptive error when no sessions match.
- `resolveSessionAsync` throws a descriptive error when multiple sessions match without disambiguation.
- `formatOutput` returns JSON when `json: true` is set.
- `formatOutput` returns a text table when `json` is not set.
- The `CommandHandler` type compiles correctly.
- Total across all three files is approximately 80 LOC.

**Do NOT**:
- Add any npm dependencies beyond workspace packages.
- Use default exports.
- Forget `.js` extensions on local imports.

---

## Task 1.7b: Reference `sessions` Command + Barrel Export Pattern

**Prerequisites**: Task 1.7a (shared CLI utilities) must be completed first.

**Context**: The `sessions` command is the simplest command in studio-bridge and serves as THE reference pattern that all future commands will copy. Getting this pattern right is critical because Tasks 3.1-3.5 all replicate it.

This task also establishes the **barrel export pattern** for command registration. Seven tasks (1.7b, 2.4, 2.6, 3.1, 3.2, 3.3, 3.4) all need to register commands. If each task modifies `cli.ts` directly, parallel worktrees will produce merge conflicts at the same lines. Instead, `cli.ts` imports `allCommands` from `src/commands/index.ts` and registers them in a loop. Each subsequent task only adds an export line to the barrel file (append-only, auto-mergeable). `cli.ts` never changes again for command registration.

**Objective**: Implement the `sessions` command as a handler + CLI wiring pair using the shared utilities from Task 1.7a, create the `src/commands/index.ts` barrel file with the `allCommands` array, and update `cli.ts` to register commands via a loop over `allCommands`.

**Dependencies**: Task 1.3 (BridgeConnection with session tracking), Task 1.7a (shared CLI utilities).

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/resolve-session.ts` (from Task 1.7a)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/format-output.ts` (from Task 1.7a)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/types.ts` (from Task 1.7a)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/bridge-connection.ts` (session listing API)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/registry/types.ts` (SessionInfo type)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/commands/exec-command.ts` (yargs pattern reference)
- `/workspaces/NevermoreEngine/studio-bridge/plans/tech-specs/02-command-system.md` sections 3.1-3.4 (barrel export pattern design)

**Files to Create**:
- `src/commands/sessions.ts` -- the command handler (pure logic, no CLI framework)
- `src/commands/index.ts` -- barrel file exporting all commands and the `allCommands` array
- `src/cli/commands/sessions-command.ts` -- yargs CLI wiring

**Files to Modify**:
- `src/cli/cli.ts` -- replace per-command `.command()` registration with a loop over `allCommands`. This is the LAST time `cli.ts` is modified for command registration.

**Requirements**:

1. Implement `src/commands/sessions.ts` (the handler):

```typescript
import type { BridgeConnection } from '../server/bridge-connection.js';
import type { SessionInfo } from '../registry/types.js';
import type { CommandResult } from '../cli/types.js';

export interface SessionsOptions {
  json?: boolean;
  watch?: boolean;
}

export async function listSessionsAsync(
  connection: BridgeConnection,
  options: SessionsOptions = {}
): Promise<CommandResult> {
  const sessions = await connection.listSessionsAsync();

  if (sessions.length === 0) {
    return {
      data: [],
      summary: 'No active sessions. Is Studio running with the studio-bridge plugin?',
    };
  }

  return {
    data: sessions,
    summary: `${sessions.length} session(s) connected.`,
  };
}
```

2. Create `src/commands/index.ts` (the barrel file and command registry):

```typescript
// src/commands/index.ts -- THE command registry
// Every command is imported and re-exported here.
// This is the single source of truth for all available commands.
//
// Adding a command = adding one export line here + one file in this directory.
// cli.ts, terminal-mode.ts, and mcp-server.ts all loop over allCommands.
// They NEVER import individual command files. They NEVER change when commands
// are added.

export { sessionsCommand } from './sessions.js';

// Future commands will be added here as they are implemented:
// export { stateCommand } from './state.js';
// export { screenshotCommand } from './screenshot.js';
// export { logsCommand } from './logs.js';
// export { queryCommand } from './query.js';
// export { execCommand } from './exec.js';
// export { runCommand } from './run.js';
// etc.

import { sessionsCommand } from './sessions.js';

export const allCommands: CommandDefinition<any, any>[] = [
  sessionsCommand,
];
```

3. Implement `src/cli/commands/sessions-command.ts` (the CLI wiring):

```typescript
import type { CommandModule } from 'yargs';
import type { StudioBridgeGlobalArgs } from '../args/global-args.js';
import { listSessionsAsync } from '../../commands/sessions.js';
import { formatOutput } from '../format-output.js';

export interface SessionsArgs extends StudioBridgeGlobalArgs {
  json?: boolean;
  watch?: boolean;
}

export class SessionsCommand implements CommandModule<StudioBridgeGlobalArgs, SessionsArgs> {
  command = 'sessions';
  describe = 'List active studio-bridge sessions';

  builder(yargs) {
    return yargs
      .option('json', { type: 'boolean', default: false, describe: 'Output as JSON' })
      .option('watch', { alias: 'w', type: 'boolean', default: false, describe: 'Watch for session changes' });
  }

  async handler(args: SessionsArgs) {
    // 1. Get or create a BridgeConnection
    // 2. Call listSessionsAsync(connection, { json: args.json, watch: args.watch })
    // 3. Print formatOutput(result.data, { json: args.json })
    // 4. If result.summary, print it
    // 5. If --watch, subscribe to session events and re-render on changes
  }
}
```

4. Update `cli.ts` to use the barrel pattern:

```typescript
import { allCommands } from '../commands/index.js';
import { createCliCommand } from './adapters/cli-adapter.js';

// Register ALL commands from the barrel file in a single loop.
// New commands are registered by adding them to src/commands/index.ts.
// This file does NOT change when commands are added.
for (const command of allCommands) {
  cli.command(createCliCommand(command));
}

// Legacy commands kept as-is during migration
cli.command(new TerminalCommand() as any);
```

5. The handler/wiring split is the key pattern: `src/commands/sessions.ts` contains the pure logic (testable without yargs), and `src/cli/commands/sessions-command.ts` is the thin CLI adapter. The barrel file in `src/commands/index.ts` is the single registration point.

**Acceptance Criteria**:
- `studio-bridge sessions` lists sessions with formatted columns.
- `--json` outputs a JSON array.
- `--watch` continuously updates (or prints "watch not yet supported" if subscription is not available).
- When no sessions exist, shows a helpful message.
- `src/commands/index.ts` exists with `sessionsCommand` exported and included in `allCommands`.
- `src/cli/cli.ts` registers commands via `for (const cmd of allCommands)` loop -- it does NOT import individual command modules.
- Total across handler and CLI wiring files is approximately 60 LOC (barrel file is additional).
- The pattern is clean enough that adding a new command requires only: (a) create `src/commands/<name>.ts`, (b) add one export + one array entry in `src/commands/index.ts`. No other files change.

**Do NOT**:
- Add any npm dependencies for table formatting (use simple string padding or `formatOutput`).
- Add per-command `.command()` calls to `cli.ts` -- use the `allCommands` loop.
- Use default exports.
- Forget `.js` extensions on local imports.

---

## Cross-References

- Phase plan: [studio-bridge/plans/execution/phases/01-bridge-network.md](../phases/01-bridge-network.md)
- Validation: [studio-bridge/plans/execution/validation/01-bridge-network.md](../validation/01-bridge-network.md)
- Failover tasks (1.8-1.10): [01b-failover.md](01b-failover.md)
- Tech specs: `studio-bridge/plans/tech-specs/01-protocol.md`, `studio-bridge/plans/tech-specs/02-command-system.md`
