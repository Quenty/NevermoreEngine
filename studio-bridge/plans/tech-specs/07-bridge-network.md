# Bridge Network: Technical Specification

The Bridge Network is the networking substrate that all of studio-bridge runs on. It is the most critical subsystem in the project: every command, every MCP tool, every terminal dot-command, every library call flows through it. This document is the authoritative reference for its design, public API, internal architecture, protocols, lifecycle, and testing strategy.

This spec consolidates and deepens the networking sections from `00-overview.md` (sections 1, 4, 7), `01-protocol.md` (transport concerns), and `05-split-server.md` (explicit host). Those documents retain their summaries; this document is the single source of truth for implementation.

## 1. Purpose and Design Philosophy

### 1.1 What this layer is

The Bridge Network is the abstraction boundary between "what studio-bridge does" (execute scripts, query state, capture screenshots) and "how messages reach Studio" (WebSockets, ports, host/client roles, session tracking, hand-off). Every consumer of studio-bridge -- CLI commands, terminal dot-commands, MCP tools, the `StudioBridge` library class -- interacts with Studio through exactly two public types: `BridgeConnection` and `BridgeSession`. Everything else is hidden.

### 1.2 Design goals

**Isolated.** No business logic leaks into the networking layer. The Bridge Network knows how to route messages to sessions and deliver responses. It does not know what "execute a script" means, what a screenshot is, or how to format output for a terminal. Conversely, no consumer code knows about WebSocket frames, port binding, or host election.

**Testable.** The entire networking stack can be exercised without Roblox Studio. A mock plugin (a test helper that opens a WebSocket to the bridge host, sends `register`, and responds to actions) is sufficient to validate every code path. Unit tests cover each internal module in isolation; integration tests cover the full stack with mock plugins.

**Abstract.** The consumer invariant: code using `BridgeConnection` and `BridgeSession` cannot tell:
- How many Studios are connected (one or ten)
- Whether this process is the bridge host or a bridge client
- Whether the connection is local or port-forwarded from a devcontainer
- How messages are transported (WebSocket, forwarded through a host, etc.)
- Whether the host was started implicitly or via `studio-bridge serve`

This is not a convenience -- it is a hard architectural constraint. Any change that would require consumer code to be aware of the networking topology is a design violation.

### 1.3 Relationship to other specs

| Spec | Relationship |
|------|-------------|
| `00-overview.md` | Contains summary-level descriptions of bridge host, bridge client, transport, hand-off, and API boundary. This spec is the authoritative deep reference. |
| `01-protocol.md` | Defines the message types and wire format between server and plugin. The Bridge Network transports these messages but does not define them. |
| `02-command-system.md` | Defines `CommandDefinition` handlers that call `BridgeSession` action methods. Consumers of this networking layer. |
| `03-persistent-plugin.md` | Defines the Luau plugin that connects to the bridge host. A peer, not part of this layer. |
| `05-split-server.md` | Describes the `studio-bridge serve` command, which is a thin wrapper around the bridge host. An operational concern built on top of this layer. |
| `06-mcp-server.md` | The MCP server uses `BridgeConnection` to access sessions. A consumer of this layer. |

## 2. Public API Surface

The Bridge Network exports exactly these types from `src/bridge/index.ts`. Nothing else is public. Nothing from `src/bridge/internal/` is re-exported.

### 2.1 BridgeConnection

The single entry point for connecting to the studio-bridge network. Handles host/client role detection transparently. Consumers never create a `BridgeHost`, `BridgeClient`, `TransportServer`, or any other internal type.

```typescript
/**
 * The constructor is private. Use the static factory `connectAsync()` to
 * create instances. This prevents double-connect and ensures the connection
 * is fully established before the caller receives the object.
 */
interface BridgeConnection {
  // ── Lifecycle ──

  /**
   * Static factory: connect to the studio-bridge network and return a
   * ready-to-use BridgeConnection.
   *
   * - If no host is running: binds port 38741, becomes the host.
   * - If a host is running: connects as a client.
   * - If remoteHost is specified: connects directly as a client to that host.
   * - If running inside a devcontainer: auto-detects and connects to host.
   *
   * The caller cannot tell which path was taken. The returned
   * BridgeConnection behaves identically in all cases.
   */
  static connectAsync(options?: BridgeConnectionOptions): Promise<BridgeConnection>;

  /**
   * Disconnect from the bridge network.
   * - If host: triggers the hand-off protocol (transfer to a connected
   *   client, or shut down cleanly).
   * - If client: closes the client connection. Does NOT stop the host
   *   or kill Studio.
   */
  disconnectAsync(): Promise<void>;

  // ── Session access ──

  /** List all currently connected Studio sessions (across all instances and contexts). */
  listSessions(): SessionInfo[];

  /**
   * List unique Studio instances. Each instance groups 1-3 context sessions
   * (edit, client, server) that share the same instanceId.
   */
  listInstances(): InstanceInfo[];

  /** Get a session handle by ID. Returns undefined if not connected. */
  getSession(sessionId: string): BridgeSession | undefined;

  /**
   * Wait for at least one session to connect.
   * Resolves with the first session that connects (or the only session
   * if one is already connected). Rejects after timeout.
   */
  waitForSession(timeout?: number): Promise<BridgeSession>;

  /**
   * Resolve a session for command execution. Instance-aware: groups sessions
   * by instanceId and auto-selects context within an instance.
   *
   * Algorithm:
   * 1. If sessionId is provided → return that specific session.
   * 2. If instanceId is provided → select that instance, then apply context
   *    selection (step 4a-4c below).
   * 3. Collect unique instances (by instanceId).
   * 4. If 0 instances → wait up to timeout for one.
   * 5. If 1 instance:
   *    a. If context is provided → return that context's session
   *       (throws ContextNotFoundError if not connected).
   *    b. If only 1 context (Edit mode) → return it.
   *    c. If multiple contexts (Play mode) → return Edit context (default).
   * 6. If N instances → throw SessionNotFoundError with instance list
   *    (caller must use --session or --instance to disambiguate).
   */
  resolveSession(sessionId?: string, context?: SessionContext, instanceId?: string): Promise<BridgeSession>;

  // ── Events ──

  on(event: 'session-connected', listener: (session: BridgeSession) => void): this;
  on(event: 'session-disconnected', listener: (sessionId: string) => void): this;
  on(event: 'instance-connected', listener: (instance: InstanceInfo) => void): this;
  on(event: 'instance-disconnected', listener: (instanceId: string) => void): this;
  on(event: 'error', listener: (error: Error) => void): this;

  // ── Diagnostics ──

  /** Whether this process ended up as host or client. */
  readonly role: 'host' | 'client';

  /** Whether the connection is currently active. */
  readonly isConnected: boolean;
}
```

### 2.2 BridgeConnectionOptions

```typescript
interface BridgeConnectionOptions {
  /** Port for the bridge host. Default: 38741. */
  port?: number;

  /** Max time to wait for initial connection setup. Default: 30_000ms. */
  timeoutMs?: number;

  /**
   * Keep the host alive even when idle (no clients, no pending commands).
   * Default: false. Used by `studio-bridge serve` and MCP server.
   */
  keepAlive?: boolean;

  /**
   * Skip local port-bind attempt and connect directly as a client
   * to this host address. Used for split-server / devcontainer mode.
   * Example: 'localhost:38741'
   */
  remoteHost?: string;
}
```

### 2.3 BridgeSession

A handle to a single connected Studio instance. Provides all action methods. Works identically whether this process is the bridge host or a client -- the networking layer routes commands transparently.

Consumers get `BridgeSession` instances from `BridgeConnection`. They never construct them directly.

```typescript
interface BridgeSession {
  /** Read-only metadata about this session. */
  readonly info: SessionInfo;

  /** Which Studio VM this session represents (edit, client, or server). */
  readonly context: SessionContext;

  /** Whether the session's plugin is still connected. */
  readonly isConnected: boolean;

  // ── Actions ──
  // Each method sends a protocol message to the plugin and waits for
  // the correlated response. Timeouts are per-action-type defaults
  // from 01-protocol.md section 7.4.

  /**
   * Execute a Luau script in this Studio instance.
   *
   * The public API uses `code`; the wire protocol uses `script` (Roblox
   * terminology). The adapter layer translates between the two when
   * constructing the `execute` message.
   */
  execAsync(code: string, timeout?: number): Promise<ExecResult>;

  /** Query Studio's current run mode and place info. */
  queryStateAsync(): Promise<StateResult>;

  /** Capture a viewport screenshot. */
  captureScreenshotAsync(): Promise<ScreenshotResult>;

  /** Retrieve buffered log history. */
  queryLogsAsync(options?: LogOptions): Promise<LogsResult>;

  /** Query the DataModel instance tree. */
  queryDataModelAsync(options: QueryDataModelOptions): Promise<DataModelResult>;

  /** Subscribe to push events. */
  subscribeAsync(events: SubscribableEvent[]): Promise<void>;

  /** Unsubscribe from push events. */
  unsubscribeAsync(events: SubscribableEvent[]): Promise<void>;

  /**
   * Follow log output as an async iterable. Yields log entries
   * as they arrive. Ends when the session disconnects or the
   * iterable is broken out of.
   */
  followLogs(options?: LogFollowOptions): AsyncIterable<LogEntry>;

  // ── Events ──

  on(event: 'state-changed', listener: (state: StudioState) => void): this;
  on(event: 'disconnected', listener: () => void): this;
  on(event: 'log', listener: (entry: LogEntry) => void): this;
}
```

### 2.3.1 SubscribableEvent

```typescript
type SubscribableEvent = 'stateChange' | 'logPush';
```

- `stateChange` -- Studio run state transitions (Edit <-> Play <-> Pause). Delivered as `stateChange` push messages from the plugin.
- `logPush` -- Continuous log entries from LogService (all sources, all levels). Delivered as individual `logPush` push messages, one per log entry. This is distinct from `output` messages (which are batched and scoped to a single `execute` request).

### 2.4 SessionInfo

```typescript
interface SessionInfo {
  /** Unique identifier for this session. */
  sessionId: string;

  /** Name of the place open in this Studio instance. */
  placeName: string;

  /** File path to the place file, if available. */
  placeFile?: string;

  /** Current Studio run mode. */
  state: StudioState;

  /** Version of the plugin running in this session. */
  pluginVersion: string;

  /** Protocol capabilities the plugin supports. */
  capabilities: Capability[];

  /**
   * When the plugin connected to the bridge host.
   * This is a Date object in the public TypeScript API. The wire protocol
   * uses a millisecond timestamp (number); the adapter converts on receipt.
   * CLI/JSON output serializes this as an ISO 8601 string.
   */
  connectedAt: Date;

  /** How this session was established. */
  origin: SessionOrigin;

  /** Which Studio VM context this session represents. */
  context: SessionContext;

  /**
   * Stable identifier for the Studio instance. All context sessions from
   * the same Studio share the same instanceId (e.g., Edit, Client, Server
   * contexts in Play mode all share one instanceId).
   */
  instanceId: string;

  /** The Roblox place ID, or 0 for unsaved places. */
  placeId: number;

  /** The Roblox game (universe) ID, or 0 for unsaved places. */
  gameId: number;
}
```

### 2.4.1 SessionContext

```typescript
/**
 * Identifies which Studio VM a session belongs to.
 *
 * - 'edit'   -- The Edit context. Always present. This is the plugin instance
 *               that runs in the normal Studio editing environment.
 * - 'client' -- The Client context. Present only during Play mode (Play, Play
 *               Here, or Run). Runs in the client-side VM.
 * - 'server' -- The Server context. Present only during Play mode. Runs in
 *               the server-side VM.
 */
type SessionContext = 'edit' | 'client' | 'server';
```

### 2.4.2 InstanceInfo

```typescript
/**
 * Metadata about a Studio instance, grouping all of its context sessions.
 * Returned by BridgeConnection.listInstances().
 */
interface InstanceInfo {
  /** Stable identifier for this Studio instance. */
  instanceId: string;

  /** Name of the place open in this Studio instance. */
  placeName: string;

  /** The Roblox place ID, or 0 for unsaved places. */
  placeId: number;

  /** The Roblox game (universe) ID, or 0 for unsaved places. */
  gameId: number;

  /** Which contexts are currently connected (e.g., ['edit'] or ['edit', 'client', 'server']). */
  contexts: SessionContext[];

  /** How this instance's sessions were established. */
  origin: SessionOrigin;
}
```

### 2.5 SessionOrigin

```typescript
/**
 * 'user'    -- The developer opened Studio manually and the persistent
 *              plugin discovered the bridge host on its own.
 * 'managed' -- studio-bridge launched Studio and injected/waited for the plugin.
 */
type SessionOrigin = 'user' | 'managed';
```

### 2.6 Result types

Result types for each action are defined in `src/bridge/types.ts`:

- `ExecResult` -- wraps `StudioBridgeResult` (success, output, error)
- `StateResult` -- `{ state, placeId, placeName, gameId }`
- `ScreenshotResult` -- `{ data (base64), format, width, height }`
- `LogsResult` -- `{ entries[], total, bufferCapacity }`
- `DataModelResult` -- `{ instance: DataModelInstance }`
- `LogEntry` -- `{ level, body, timestamp }`

These are re-exports of the protocol payload types from `01-protocol.md`, surfaced through the public API so consumers never import from the protocol module directly.

### 2.7 Error types

All errors from the Bridge Network are typed error classes, catchable and inspectable:

```typescript
class SessionNotFoundError extends Error {
  readonly sessionId: string;
}

class HostUnreachableError extends Error {
  readonly host: string;
  readonly port: number;
}

class ActionTimeoutError extends Error {
  readonly action: string;
  readonly timeoutMs: number;
  readonly sessionId: string;
}

class SessionDisconnectedError extends Error {
  readonly sessionId: string;
}

class CapabilityNotSupportedError extends Error {
  readonly capability: string;
  readonly sessionId: string;
}

class ContextNotFoundError extends Error {
  /** The context that was requested but not found. */
  readonly context: SessionContext;
  /** The instanceId the context was looked up on. */
  readonly instanceId: string;
  /** The contexts that ARE available on this instance. */
  readonly availableContexts: SessionContext[];
}

class PortInUseError extends Error {
  readonly port: number;
}

class HandOffFailedError extends Error {
  readonly reason: string;
}
```

No silent failures. Every error path either rejects a promise, throws an exception, or emits an `'error'` event on the connection.

## 3. Internal Architecture

### 3.1 Layer diagram

```
┌─────────────────────────────────────────────────────┐
│                    PUBLIC API                         │
│                                                      │
│  BridgeConnection    BridgeSession    SessionInfo    │
│  Result types        Error types      Events         │
│                                                      │
│  (src/bridge/bridge-connection.ts)                   │
│  (src/bridge/bridge-session.ts)                      │
│  (src/bridge/types.ts)                               │
├─────────────────────────────────────────────────────┤
│                   ROLE DETECTION                     │
│                                                      │
│  connectAsync() → try bind port                      │
│    Success → create BridgeHost (become host)         │
│    EADDRINUSE → create BridgeClient (connect)        │
│    remoteHost set → create BridgeClient directly     │
│    Devcontainer → try remote, fall back to local     │
│                                                      │
│  (src/bridge/bridge-connection.ts, internal only)    │
├─────────────────────────────────────────────────────┤
│                   BRIDGE HOST                        │
│                                                      │
│  session-tracker.ts    host-protocol.ts   hand-off.ts│
│                                                      │
│  Manages plugin connections, routes client requests, │
│  tracks sessions, handles host transfer.             │
│                                                      │
│  (src/bridge/internal/bridge-host.ts)                │
│  (src/bridge/internal/session-tracker.ts)            │
│  (src/bridge/internal/host-protocol.ts)              │
│  (src/bridge/internal/hand-off.ts)                   │
├─────────────────────────────────────────────────────┤
│                   BRIDGE CLIENT                      │
│                                                      │
│  Connects to an existing host, forwards action       │
│  requests via host-protocol envelopes, receives      │
│  forwarded responses.                                │
│                                                      │
│  (src/bridge/internal/bridge-client.ts)              │
├─────────────────────────────────────────────────────┤
│                    TRANSPORT                         │
│                                                      │
│  transport-server.ts    transport-client.ts          │
│  transport-handle.ts    health-endpoint.ts           │
│                                                      │
│  Low-level WebSocket server/client. HTTP upgrade,    │
│  connection management, reconnection, backoff.       │
│  No business logic.                                  │
├─────────────────────────────────────────────────────┤
│                 WEBSOCKET (ws library)               │
└─────────────────────────────────────────────────────┘
```

### 3.2 File layout

```
src/bridge/
  index.ts                        PUBLIC: re-exports ONLY BridgeConnection, BridgeSession, types
  bridge-connection.ts            BridgeConnection class (public API, orchestrates role detection)
  bridge-session.ts               BridgeSession class (public API, delegates to transport handles)
  types.ts                        SessionInfo, SessionOrigin, result types, option types, error types

  internal/
    bridge-host.ts                WebSocket server on port 38741, plugin + client management
    bridge-client.ts              WebSocket client connecting to existing host
    transport-server.ts           Low-level WebSocket/HTTP server
    transport-client.ts           Low-level WebSocket client with reconnection
    transport-handle.ts           TransportHandle interface (abstraction over a connection to a plugin)
    health-endpoint.ts            HTTP /health endpoint handler
    session-tracker.ts            In-memory session map with event emission
    host-protocol.ts              Client-to-host envelope messages
    hand-off.ts                   Host transfer logic (graceful + crash recovery)
    environment-detection.ts      isDevcontainer(), getDefaultRemoteHost()
```

### 3.3 Import rules

```
src/bridge/index.ts              Re-exports public API only. No internal/ types leak out.
src/bridge/bridge-connection.ts   May import from internal/ (it orchestrates networking).
src/bridge/bridge-session.ts      May import from internal/ (it delegates to transport handles).
src/bridge/types.ts               No imports from internal/ (pure type definitions).
src/bridge/internal/*.ts          May import from each other. NEVER imported outside src/bridge/.
```

The key rule: **nothing outside `src/bridge/` may import from `src/bridge/internal/`**. If a consumer needs something from the internal layer, the correct fix is to add it to the public API surface in `src/bridge/index.ts`, not to reach into internals.

### 3.4 Internal module responsibilities

#### transport-server.ts

Low-level WebSocket server implementation. Handles:
- HTTP server creation and port binding
- WebSocket upgrade for `/plugin` and `/client` paths
- HTTP GET handler for `/health` (delegates to health-endpoint.ts)
- Connection lifecycle (open, message, close, error)
- WebSocket configuration: `maxPayload: 16MB`, `perMessageDeflate: true`
- WebSocket-level ping/pong every 30 seconds

Does NOT handle: message parsing, session tracking, protocol logic, hand-off. It is a dumb pipe that emits connection and message events.

```typescript
interface TransportServer {
  listenAsync(port: number): Promise<void>;
  close(): void;
  on(event: 'plugin-connection', listener: (ws: WebSocket, req: IncomingMessage) => void): this;
  on(event: 'client-connection', listener: (ws: WebSocket, req: IncomingMessage) => void): this;
  on(event: 'health-request', listener: (req: IncomingMessage, res: ServerResponse) => void): this;
  readonly port: number;
}
```

#### transport-client.ts

Low-level WebSocket client with automatic reconnection. Handles:
- WebSocket connection to a target URL
- Reconnection with exponential backoff (1s, 2s, 4s, 8s, max 30s)
- Connection state tracking (connecting, connected, disconnected, reconnecting)
- Message send/receive

Does NOT handle: message parsing, protocol logic, host-protocol envelopes. It is a dumb pipe.

```typescript
interface TransportClient {
  connectAsync(url: string): Promise<void>;
  disconnect(): void;
  send(data: string): void;
  on(event: 'message', listener: (data: string) => void): this;
  on(event: 'connected', listener: () => void): this;
  on(event: 'disconnected', listener: () => void): this;
  on(event: 'error', listener: (error: Error) => void): this;
  readonly isConnected: boolean;
}
```

#### transport-handle.ts

Abstraction over "I have a connection to a Studio plugin and can send it actions." Both the bridge host (which has a direct WebSocket to the plugin) and the bridge client (which forwards through the host) implement this interface. `BridgeSession` delegates to a `TransportHandle` without knowing which kind it is.

```typescript
interface TransportHandle {
  /** Send a protocol message to the plugin and wait for the response. */
  sendActionAsync<TResponse>(message: ServerMessage, timeoutMs: number): Promise<TResponse>;

  /** Send a one-way message (no response expected). */
  sendMessage(message: ServerMessage): void;

  /** Whether the connection to the plugin is alive. */
  readonly isConnected: boolean;

  on(event: 'message', listener: (msg: PluginMessage) => void): this;
  on(event: 'disconnected', listener: () => void): this;
}
```

**Host-side TransportHandle** (DirectTransportHandle): wraps a WebSocket connection directly to the plugin. `sendActionAsync` writes to the WebSocket, registers a pending request in `PendingRequestMap`, and waits for the correlated response.

**Client-side TransportHandle** (RelayedTransportHandle): wraps a connection to the bridge host. `sendActionAsync` wraps the action in a `HostEnvelope`, sends it to the host, and waits for the host to forward the response back.

#### session-tracker.ts

In-memory map of session ID to session state, with instance-level grouping by `instanceId`. Used exclusively by `bridge-host.ts`. Emits events when sessions are added, removed, or updated, and when instance groups are created or removed.

```typescript
interface SessionTracker {
  addSession(sessionId: string, info: SessionInfo, handle: TransportHandle): void;
  removeSession(sessionId: string): void;
  getSession(sessionId: string): TrackedSession | undefined;
  listSessions(): SessionInfo[];
  updateSessionState(sessionId: string, state: StudioState): void;

  // ── Instance-level access ──

  /**
   * List unique instances. Each instance groups 1-3 context sessions
   * that share the same instanceId.
   */
  listInstances(): InstanceInfo[];

  /**
   * Get all sessions for a given instanceId. Returns sessions for
   * all connected contexts (edit, client, server).
   */
  getSessionsByInstance(instanceId: string): TrackedSession[];

  /**
   * Get a specific context session for an instance.
   * Returns undefined if the context is not connected.
   */
  getSessionByContext(instanceId: string, context: SessionContext): TrackedSession | undefined;

  // ── Events ──

  on(event: 'session-added', listener: (session: TrackedSession) => void): this;
  on(event: 'session-removed', listener: (sessionId: string) => void): this;
  on(event: 'session-updated', listener: (session: TrackedSession) => void): this;
  on(event: 'instance-added', listener: (instance: InstanceInfo) => void): this;
  on(event: 'instance-removed', listener: (instanceId: string) => void): this;
}

interface TrackedSession {
  info: SessionInfo;
  handle: TransportHandle;
  lastHeartbeat: Date;
}
```

**Instance grouping logic:**

When `addSession()` is called, the tracker groups the session by its `info.instanceId`. If this is the first session for that `instanceId`, a new instance group is created and the `instance-added` event fires. If sessions already exist for that `instanceId` (e.g., Play mode adding Client/Server contexts), the instance group's `contexts` array is updated.

When `removeSession()` is called, the session is removed from the instance group. If this was the last session for that `instanceId` (all contexts disconnected), the instance group is removed and the `instance-removed` event fires.

Sessions are tracked entirely in-memory. There are no files on disk, no lock files, no PID-based stale session detection. A session exists if and only if its plugin is currently connected to the bridge host.

#### host-protocol.ts

The envelope protocol for client-to-host communication. When a bridge client needs to send an action to session X, it wraps the action in a host-protocol envelope and sends it to the host. The host unwraps the envelope, forwards the action to the plugin, collects the response, wraps it in a response envelope, and sends it back to the client.

```typescript
// Client → Host
interface HostEnvelope {
  type: 'host-envelope';
  requestId: string;        // client-generated, for correlating the host response
  targetSessionId: string;  // which plugin session to route to
  action: ServerMessage;    // the actual protocol message to forward
}

interface ListSessionsRequest {
  type: 'list-sessions';
  requestId: string;
}

interface HostTransferNotice {
  type: 'host-transfer';
  // Sent by the host to all clients when it is shutting down gracefully
}

interface HostReadyNotice {
  type: 'host-ready';
  // Sent by the new host to remaining clients after takeover
}

// Host → Client
interface HostResponse {
  type: 'host-response';
  requestId: string;        // echoes the client's requestId
  result: PluginMessage;    // the plugin's response, unwrapped
}

interface ListSessionsResponse {
  type: 'list-sessions-response';
  requestId: string;
  sessions: SessionInfo[];
}

interface SessionEvent {
  type: 'session-event';
  event: 'connected' | 'disconnected' | 'state-changed';
  session?: SessionInfo;    // present for connected/state-changed (includes context, instanceId)
  sessionId: string;
  context: SessionContext;  // which VM context this event relates to
  instanceId: string;       // which Studio instance this event relates to
}

type HostProtocolMessage =
  | HostEnvelope
  | ListSessionsRequest
  | HostTransferNotice
  | HostReadyNotice
  | HostResponse
  | ListSessionsResponse
  | SessionEvent;
```

#### bridge-host.ts

The bridge host is the "source of truth" for session state. It runs the WebSocket server on port 38741 and manages two classes of connections:

**Plugin connections** (`/plugin` path):
- Plugin connects, sends `register` (or `hello`) with a plugin-generated UUID as `sessionId`, plus `instanceId` and `context`. Host accepts the proposed session ID (or overrides it on collision), creates a session entry in `SessionTracker` (grouped by `instanceId`), and responds with `welcome` containing the authoritative `sessionId`.
- In Play mode, up to 3 plugins from the same Studio connect with the same `instanceId` but different `context` values (edit, client, server)
- Plugin sends heartbeats, host updates `lastHeartbeat`
- Plugin sends responses to actions, host forwards to the appropriate client (or resolves locally if this process initiated the action)
- Plugin disconnects, host removes session after a brief grace period (2 seconds, to handle transient network blips). Instance group is removed only when ALL contexts disconnect.

**Client connections** (`/client` path):
- Client connects, host tracks it in a client list
- Client sends `HostEnvelope`, host unwraps, looks up the target session in `SessionTracker`, forwards the action to the plugin via the session's `TransportHandle`
- Plugin responds, host wraps the response in a `HostResponse` and sends it back to the requesting client
- Client sends `ListSessionsRequest`, host responds with current session list
- Host emits `SessionEvent` to all connected clients when sessions connect/disconnect/change state

Only one bridge host exists per machine (per port). This is enforced by port binding -- two processes cannot bind the same port.

#### bridge-client.ts

A bridge client connects to an existing bridge host on port 38741 (or a configured remote host). From the consumer's perspective, it behaves identically to being the host. The difference is entirely internal: actions are forwarded through the host rather than delivered directly to plugins.

The bridge client:
- Connects to `ws://host:port/client` using `TransportClient`
- Creates `RelayedTransportHandle` instances for each session (which wrap actions in `HostEnvelope` and forward to the host)
- Listens for `SessionEvent` messages from the host to maintain a local mirror of the session list
- On disconnect from the host, enters the hand-off flow (attempt to become the new host)

#### hand-off.ts

Host transfer logic for when the bridge host process exits.

**Graceful exit** (Ctrl+C, normal shutdown, `disconnectAsync()`):
1. Host sends `HostTransferNotice` to all connected clients
2. Clients receive the notice and enter "takeover standby" mode
3. Host closes the WebSocket server, freeing the port
4. First client to successfully bind port 38741 becomes the new host
5. New host sends `HostReadyNotice` to remaining clients
6. Remaining clients reconnect to the new host as clients
7. Plugins detect the WebSocket close, poll `/health`, and reconnect when the new host is ready

**Crash / kill -9** (no graceful message possible):
1. Clients detect WebSocket disconnect (close or error event)
2. Each client waits a random jitter (0-500ms) to avoid thundering herd
3. First client to successfully bind port 38741 becomes the new host
4. Remaining clients retry connecting to port 38741
5. Plugins detect the WebSocket close, poll `/health`, and reconnect

**No clients connected**:
1. Host exits, port is freed
2. Plugins poll `/health`, get connection refused, continue polling with backoff
3. Next CLI process to start binds the port and becomes the new host
4. Plugins discover the new host on the next poll cycle

#### health-endpoint.ts

HTTP GET handler for the `/health` path. Returns a JSON health check response. Used by the persistent plugin for discovery and by diagnostic tools.

```typescript
// GET /health → 200 OK
interface HealthResponse {
  status: 'ok';
  port: number;
  protocolVersion: number;
  serverVersion: string;
  sessions: number;
  uptime: number;  // milliseconds since the host started
}
```

#### environment-detection.ts

Detects whether the process is running inside a devcontainer and provides the default remote host for auto-connection.

```typescript
function isDevcontainer(): boolean {
  return !!(
    process.env.REMOTE_CONTAINERS ||
    process.env.CODESPACES ||
    process.env.CONTAINER ||
    existsSync('/.dockerenv')
  );
}

function getDefaultRemoteHost(): string | null {
  if (isDevcontainer()) {
    return `localhost:${DEFAULT_BRIDGE_PORT}`;
  }
  return null;
}
```

## 4. Role Detection and Startup

When `BridgeConnection.connectAsync()` is called, the following decision flow executes. This is entirely internal -- the consumer sees a promise that resolves with a working connection regardless of which path was taken.

```
connectAsync(options) called
│
├── options.remoteHost is set?
│   YES → connect to host at remoteHost as client via bridge-client.ts
│         ├── success → role = 'client', done
│         └── failure → throw HostUnreachableError
│
├── isDevcontainer() is true?
│   YES → try connecting to localhost:38741 as client
│         ├── success → role = 'client', done
│         └── failure → warn("No bridge host found, falling back to local mode")
│                       continue to local bind attempt below
│
├── Try to bind port (options.port or 38741)
│   ├── success → this process is the HOST
│   │             start bridge-host.ts with TransportServer
│   │             role = 'host', done
│   │
│   ├── EADDRINUSE → port is taken, try connecting as client
│   │   ├── connect to ws://localhost:{port}/client
│   │   │   ├── success → role = 'client', done
│   │   │   └── failure → port is held by a non-bridge process
│   │   │                 OR previous host crashed and OS hasn't released port
│   │   │                 wait 1 second, retry bind
│   │   │                 (up to 3 retries, then throw HostUnreachableError)
│   │
│   └── other error → throw with clear message
│
└── timeout after options.timeoutMs → throw ActionTimeoutError
```

### 4.1 Stale port detection

If port 38741 is bound but the process holding it is not a bridge host (or is a crashed host whose OS hasn't released the socket), the client connection attempt will fail with a connection refused or handshake error. In this case, the connection logic waits briefly (1 second) and retries the bind, up to 3 times. If all retries fail, it throws `HostUnreachableError` with a message explaining that the port is held by another process.

### 4.2 Multiple processes starting simultaneously

If two CLI processes start at nearly the same time and both attempt to bind the port, exactly one will succeed (OS guarantees atomic port binding). The other will get `EADDRINUSE` and connect as a client. This is correct behavior with no race condition.

## 5. Host-Client Protocol

When a bridge client needs to reach a plugin session, the action is forwarded through the bridge host. This section describes the forwarding protocol in detail.

### 5.1 Request flow

```
Consumer                  BridgeSession            Bridge Client           Bridge Host              Plugin
   │                           │                        │                       │                      │
   │  session.execAsync(code)  │                        │                       │                      │
   │ ─────────────────────────>│                        │                       │                      │
   │                           │                        │                       │                      │
   │                           │  sendActionAsync()     │                       │                      │
   │                           │  (RelayedTransport     │                       │                      │
   │                           │   Handle)              │                       │                      │
   │                           │ ──────────────────────>│                       │                      │
   │                           │                        │                       │                      │
   │                           │                        │  HostEnvelope {       │                      │
   │                           │                        │    target: sessionId  │                      │
   │                           │                        │    action: execute    │                      │
   │                           │                        │    requestId: "r-01"  │                      │
   │                           │                        │  }                    │                      │
   │                           │                        │ ─────────────────────>│                      │
   │                           │                        │                       │                      │
   │                           │                        │                       │  execute {            │
   │                           │                        │                       │    script: code       │
   │                           │                        │                       │    requestId: "r-01"  │
   │                           │                        │                       │  }                    │
   │                           │                        │                       │ ────────────────────> │
   │                           │                        │                       │                      │
   │                           │                        │                       │  scriptComplete {     │
   │                           │                        │                       │    requestId: "r-01"  │
   │                           │                        │                       │    success: true      │
   │                           │                        │                       │  }                    │
   │                           │                        │                       │ <──────────────────── │
   │                           │                        │                       │                      │
   │                           │                        │  HostResponse {       │                      │
   │                           │                        │    requestId: "r-01"  │                      │
   │                           │                        │    result: script-    │                      │
   │                           │                        │      Complete         │                      │
   │                           │                        │  }                    │                      │
   │                           │                        │ <─────────────────────│                      │
   │                           │                        │                       │                      │
   │                           │  resolve(result)       │                       │                      │
   │                           │ <──────────────────────│                       │                      │
   │                           │                        │                       │                      │
   │  ExecResult               │                        │                       │                      │
   │ <─────────────────────────│                        │                       │                      │
```

### 5.2 Direct host flow

When the consumer's process IS the bridge host, the flow is shorter -- no forwarding envelope is needed:

```
Consumer                  BridgeSession            Bridge Host              Plugin
   │                           │                        │                      │
   │  session.execAsync(code)  │                        │                      │
   │ ─────────────────────────>│                        │                      │
   │                           │                        │                      │
   │                           │  sendActionAsync()     │                      │
   │                           │  (DirectTransport      │                      │
   │                           │   Handle)              │                      │
   │                           │ ──────────────────────>│                      │
   │                           │                        │                      │
   │                           │                        │  execute {            │
   │                           │                        │    requestId: "r-01"  │
   │                           │                        │  }                    │
   │                           │                        │ ────────────────────> │
   │                           │                        │                      │
   │                           │                        │  scriptComplete {     │
   │                           │                        │    requestId: "r-01"  │
   │                           │                        │  }                    │
   │                           │                        │ <──────────────────── │
   │                           │                        │                      │
   │                           │  resolve(result)       │                      │
   │                           │ <──────────────────────│                      │
   │                           │                        │                      │
   │  ExecResult               │                        │                      │
   │ <─────────────────────────│                        │                      │
```

The key insight: `BridgeSession` delegates to a `TransportHandle`. Whether that handle is a `DirectTransportHandle` (host) or a `RelayedTransportHandle` (client) is invisible to `BridgeSession` and therefore invisible to the consumer. The `TransportHandle` interface is the abstraction boundary.

### 5.3 Push message forwarding (subscription routing)

Push messages from the plugin (`stateChange`, `logPush`, `heartbeat`) are forwarded by the bridge host to subscribed clients using **WebSocket push**. This is the transport mechanism for `--watch` (state) and `--follow` (logs) features. The host maintains a per-session subscription map that tracks which clients are subscribed to which event types.

#### Subscription data flow

The full subscription lifecycle is a 5-step WebSocket push flow:

```
CLI/Client                      Bridge Host                      Plugin
    │                               │                               │
    │  1. subscribe {               │                               │
    │     events: ['stateChange']   │                               │
    │  }                            │                               │
    │ ─────────────────────────────>│                               │
    │                               │  2. subscribe {               │
    │                               │     events: ['stateChange']   │
    │                               │  }                            │
    │                               │ ─────────────────────────────>│
    │                               │                               │
    │                               │  3. subscribeResult {         │
    │                               │     events: ['stateChange']   │
    │                               │  }                            │
    │                               │ <─────────────────────────────│
    │  subscribeResult              │                               │
    │ <─────────────────────────────│                               │
    │                               │                               │
    │                               │  4. stateChange {             │
    │                               │     previousState, newState   │
    │                               │  }                            │
    │                               │ <─────────────────────────────│
    │                               │                               │
    │  stateChange (forwarded)      │  (host checks subscription   │
    │ <─────────────────────────────│   map, forwards to all        │
    │                               │   subscribed clients)         │
    │                               │                               │
    │  5. unsubscribe {             │                               │
    │     events: ['stateChange']   │                               │
    │  }                            │                               │
    │ ─────────────────────────────>│                               │
    │                               │  unsubscribe (forwarded)      │
    │                               │ ─────────────────────────────>│
    │                               │                               │
    │  unsubscribeResult            │  unsubscribeResult            │
    │ <─────────────────────────────│ <─────────────────────────────│
```

#### Host subscription map

The bridge host maintains an in-memory subscription map per session:

```typescript
// Internal to bridge-host.ts
type SubscriptionMap = Map<
  string,                           // sessionId
  Map<string, Set<SubscribableEvent>>  // clientId -> subscribed events
>;
```

When a client sends a `subscribe` message (wrapped in a `HostEnvelope`):
1. The host records the client's subscription in the map: `subscriptions.get(sessionId).get(clientId).add(event)`.
2. The host forwards the `subscribe` message to the plugin (so the plugin knows to start pushing events).
3. The plugin responds with `subscribeResult`, which the host forwards back to the client.

When a push message arrives from a plugin (`stateChange` or `logPush`):
1. The host looks up the session's subscription map.
2. For each client that has subscribed to the event type matching the push message, the host forwards the push message to that client (wrapped in a `HostResponse` with a synthetic envelope).
3. Clients that are NOT subscribed to that event type do NOT receive the push message.

When a client sends an `unsubscribe` message:
1. The host removes the event from the client's subscription set.
2. The host forwards the `unsubscribe` to the plugin.
3. If no clients remain subscribed to a given event type for that session, the host may optionally forward an `unsubscribe` to the plugin to stop the push stream (optimization, not required for correctness).

When a client disconnects:
1. The host removes all of that client's subscriptions from the map.
2. If no clients remain subscribed to a given event type, the host may send `unsubscribe` to the plugin.

When a plugin disconnects:
1. The host removes the session's entire subscription map entry.
2. Any clients that were subscribed to that session's events stop receiving pushes (the session no longer exists).

#### Direct host flow (host process is also the consumer)

When the consumer's process IS the bridge host (no client forwarding needed), subscriptions are handled locally:
1. `BridgeSession.subscribeAsync()` sends `subscribe` directly to the plugin via the `DirectTransportHandle`.
2. Push messages from the plugin arrive on the `TransportHandle`'s `message` event.
3. `BridgeSession` dispatches them to the appropriate event listeners (`'state-changed'`, `'log'`).
4. No subscription map is needed -- the host process receives all messages from its directly-connected plugins.

#### Heartbeat messages

`heartbeat` messages are NOT subscription-gated. The host always receives heartbeats from connected plugins (for session liveness tracking). Heartbeat messages are NOT forwarded to clients -- they are consumed internally by the host's session tracker.

### 5.4 Session event broadcasting

When a session connects or disconnects, the host broadcasts a `SessionEvent` to ALL connected clients (not just those subscribed to that session). This is how clients maintain their session list in sync with the host.

## 6. Session Lifecycle

### 6.1 Plugin connection (session creation)

1. Plugin opens a WebSocket to `ws://localhost:38741/plugin`
2. Plugin sends `register` message (v2) or `hello` message (v1) with session metadata (including a plugin-generated UUID as `sessionId`, plus `instanceId`, `context`, `placeId`, `gameId`)
3. Bridge host validates the message, accepts the plugin's proposed session ID (or overrides it if there is a collision with an existing session), creates a `TrackedSession` in `SessionTracker` (grouped by `instanceId`)
4. Bridge host responds with `welcome` containing the authoritative `sessionId` (which confirms or overrides the plugin's proposed ID) and negotiated capabilities (for v2). The plugin must use this `sessionId` for all subsequent messages.
5. Bridge host emits `session-added` event on `SessionTracker`. If this is the first session for the `instanceId`, `instance-added` also fires.
6. All connected clients receive a `SessionEvent { event: 'connected', session: SessionInfo }` (includes `context` and `instanceId`)
7. `BridgeConnection` emits `'session-connected'` to consumer code. If the instance is new, `'instance-connected'` also fires.

### 6.2 Plugin heartbeat

- Plugin sends `heartbeat` every 15 seconds with current state and uptime
- Bridge host updates `lastHeartbeat` timestamp on the `TrackedSession`
- If no heartbeat is received for 45 seconds (3 missed heartbeats), the host marks the session as stale
- If no heartbeat is received for 60 seconds (4 missed heartbeats), the host removes the session and emits `session-disconnected`

### 6.3 Plugin disconnection (session removal)

1. Plugin's WebSocket closes (Studio closed, crash, network drop, or explicit `shutdown`)
2. Bridge host starts a 2-second grace period (to handle transient network blips)
3. If the plugin reconnects within the grace period (same `instanceId` AND same `context`), the session is updated, not duplicated
4. If the grace period expires without reconnection, the session is removed from `SessionTracker`
5. Bridge host emits `session-removed` event. If this was the last session for the `instanceId`, `instance-removed` also fires.
6. All connected clients receive a `SessionEvent { event: 'disconnected', sessionId }` (includes `context` and `instanceId`)
7. `BridgeConnection` emits `'session-disconnected'` to consumer code. If the instance group was removed, `'instance-disconnected'` also fires.

### 6.4 Plugin reconnection (same instance + context)

When a persistent plugin reconnects after a temporary disconnect (e.g., the bridge host restarted):
1. Plugin sends `register` with the same `instanceId` AND `context` it used before
2. Bridge host checks `SessionTracker` for an existing session with that `instanceId` AND `context` pair (not just `instanceId` alone -- this is important in Play mode where 3 contexts share one `instanceId`)
3. If found (within the grace period): update the session's WebSocket handle, reset heartbeat timer. No `session-connected` event (the session never truly disconnected from the consumer's perspective)
4. If not found (grace period expired): create a new session as in 6.1

### Session Reconnection Lifecycle

When a plugin disconnects and reconnects with the same `(instanceId, context)`:

1. Plugin WebSocket closes -> bridge host removes the session from its tracker
2. `BridgeConnection` emits `'session-disconnected'` with the old `sessionId`
3. Old `BridgeSession` handle becomes stale -- `isConnected` returns `false`, action methods reject with `SessionDisconnectedError`
4. Plugin reconnects -> sends `register` -> bridge host creates a **new** session with a new `sessionId`
5. `BridgeConnection` emits `'session-connected'` with a new `BridgeSession`
6. Consumers must re-resolve to get the new handle: `session = await conn.resolveSession()`

**Key invariant**: `BridgeSession` objects are NOT reused across reconnections. Each connection produces a new handle. Consumers should listen for `'session-disconnected'` and re-resolve.

### 6.5 Play mode transitions (multi-context lifecycle)

When Studio enters Play mode, 2 new plugin instances (server and client) connect, joining the already-connected edit instance. The bridge host handles this as follows:

**Entering Play mode:**
1. Studio starts Play mode. The Edit context's plugin remains connected (its session already exists).
2. The Server VM loads a new plugin instance. It connects to the bridge host and sends `register` with the same `instanceId` as the Edit session but `context: 'server'`.
3. The Client VM loads a new plugin instance. It connects and sends `register` with the same `instanceId` and `context: 'client'`.
4. The bridge host now has 3 sessions grouped under one `instanceId`. The `InstanceInfo.contexts` array is `['edit', 'server', 'client']`.
5. Consumers calling `resolveSession()` continue to get the Edit context by default (no disruption to in-flight work).

**Leaving Play mode (Stop button):**
1. Studio stops the Play session. The Client and Server VMs are destroyed.
2. The Client and Server plugins' WebSocket connections close.
3. The bridge host removes those two sessions from the `SessionTracker`. The instance group remains (Edit context is still connected).
4. The `InstanceInfo.contexts` array returns to `['edit']`.
5. `session-disconnected` events fire for the Client and Server sessions, but `instance-disconnected` does NOT fire (the Edit context keeps the instance alive).

**Plugin reconnection during Play mode:**
When matching a reconnecting plugin to an existing session, the bridge host uses the `(instanceId, context)` pair as the key -- not `instanceId` alone. This prevents a reconnecting Server context from accidentally matching an Edit context session (or vice versa).

### 6.6 Idle shutdown

When the bridge host has no active CLI commands and no connected clients:
- If `keepAlive: true` (set by `studio-bridge serve` or MCP server): host stays alive indefinitely
- If `keepAlive: false` (default, set by `exec`/`run` commands): host enters idle mode
  - If any `user`-origin sessions are connected: host stays alive (it would be wrong to kill a manually-opened Studio's connection)
  - If only `managed`-origin sessions or no sessions: host exits after a 5-second grace period
  - The grace period allows rapid re-invocation (e.g., running `studio-bridge exec` twice in a row) without losing the session

### 6.7 resolveSession() algorithm (instance-aware resolution)

The `resolveSession(sessionId?, context?, instanceId?)` method is the primary way consumers target a session. It is instance-aware: it groups sessions by `instanceId` and selects a context within the matched instance. This algorithm is shared between the CLI (via `--session`, `--instance`, and `--context` flags), the MCP server (via `sessionId`, `instanceId`, and `context` tool parameters), and the terminal (via `.connect` dot-command).

```
resolveSession(sessionId?, context?, instanceId?) {
  1. If sessionId is provided:
     → Look up the session by ID.
     → If found, return it.
     → If not found, throw SessionNotFoundError.

  2. If instanceId is provided:
     → Look up the instance by instanceId.
     → If not found, throw SessionNotFoundError.
     → If found, apply context selection (step 5a-5c below) within that instance.

  3. Collect unique instances from SessionTracker.listInstances().

  4. If 0 instances:
     → Wait up to timeoutMs for an instance to connect.
     → If timeout expires, throw ActionTimeoutError.
     → When an instance connects, continue to step 5.

  5. If 1 instance:
     a. If context is provided:
        → Look up that context's session within the instance.
        → If found, return it.
        → If not found (e.g., --context server but Studio is in Edit mode):
          throw ContextNotFoundError {
            context,
            instanceId,
            availableContexts: instance.contexts
          }
     b. If instance has only 1 context (Edit mode):
        → Return the Edit session.
     c. If instance has multiple contexts (Play mode):
        → Return the Edit context session (default).

  6. If N instances (N > 1):
     → Throw SessionNotFoundError with the instance list, e.g.:
       "Multiple Studio instances connected. Use --session <id> or --instance <id> to select one."
       List each instance with its instanceId, placeName, and connected contexts.
}
```

**Why Edit is the default in Play mode:** Most CLI operations (exec, query, run) target the Edit context because it represents the authoritative editing environment. Server and Client contexts are transient (destroyed when Play stops) and primarily useful for inspecting runtime state. Consumers who want to target the Server or Client context must explicitly pass `context: 'server'` or `context: 'client'`.

## 7. Connection Types on Port 38741

The WebSocket server on port 38741 distinguishes connections by HTTP upgrade path:

| Path | Source | Purpose |
|------|--------|---------|
| `/plugin` | Studio plugin (Luau) | Plugin upstream connection. Plugin sends `register`/`hello`, receives actions, sends responses and push messages. |
| `/client` | CLI process / MCP server | CLI downstream connection. Client sends host-protocol envelopes (`HostEnvelope`, `ListSessionsRequest`), receives `HostResponse` and `SessionEvent`. |
| `/health` | HTTP GET (any) | Health check endpoint. Returns JSON with host status, session count, uptime. Used by plugins for discovery. |

All other HTTP paths return 404. The WebSocket upgrade is rejected for paths other than `/plugin` and `/client`.

## 8. Testing Strategy

The networking layer MUST be testable without Roblox Studio. This section describes the testing approach at each level.

### 8.1 Mock plugin helper

The foundation of all Bridge Network tests is a mock plugin: a test utility that simulates a Studio plugin connecting to the bridge host and responding to actions.

```typescript
/**
 * Test helper: simulates a Studio plugin connecting to the bridge host.
 *
 * Usage in tests:
 *   const host = await createBridgeHost({ port: 0 }); // ephemeral port
 *   const plugin = await createMockPlugin({ port: host.port });
 *   await plugin.waitForWelcome();
 *   // Now the host has one session
 *
 *   // Configure responses
 *   plugin.onAction('queryState', () => ({
 *     type: 'stateResult',
 *     payload: { state: 'Edit', placeId: 0, placeName: 'Test', gameId: 0 }
 *   }));
 *
 *   // Test consumer code
 *   const connection = await BridgeConnection.connectAsync({ port: host.port });
 *   const session = await connection.waitForSession();
 *   const state = await session.queryStateAsync();
 *   expect(state.state).toBe('Edit');
 */
interface MockPlugin {
  /** Connect to the bridge host on the specified port. */
  connectAsync(port: number): Promise<void>;

  /** Wait for the welcome message from the host. */
  waitForWelcome(): Promise<WelcomeMessage>;

  /** Register a response handler for a specific action type. */
  onAction(type: string, handler: (payload: unknown) => PluginMessage): void;

  /** Send a push message (heartbeat, stateChange, logPush, output). */
  sendPush(message: PluginMessage): void;

  /** Disconnect from the host. */
  disconnect(): void;

  /** The authoritative session ID (from the host's welcome response -- confirms or overrides the plugin-proposed ID). */
  readonly sessionId: string;
}

function createMockPlugin(options?: MockPluginOptions): MockPlugin;

interface MockPluginOptions {
  port?: number;
  instanceId?: string;
  context?: SessionContext;    // default: 'edit'
  placeName?: string;
  placeId?: number;
  gameId?: number;
  capabilities?: Capability[];
  protocolVersion?: number;
}
```

This mock plugin is essential for testing everything above the transport layer. It lives in `src/test/helpers/mock-plugin-client.ts` and is used by both unit and integration tests.

### 8.2 Unit tests

Each internal module is tested in isolation with mocked dependencies.

| Module | Test strategy |
|--------|--------------|
| `transport-server.ts` | Create server on ephemeral port, connect raw WebSocket, verify upgrade paths, verify health endpoint |
| `transport-client.ts` | Create a local WebSocket server, connect client, verify reconnection with backoff after disconnect |
| `transport-handle.ts` | Mock WebSocket, verify `sendActionAsync` registers pending request and resolves on response |
| `session-tracker.ts` | Pure in-memory. Add/remove/update sessions, verify events, verify stale detection |
| `host-protocol.ts` | Verify envelope wrapping/unwrapping, request ID correlation |
| `hand-off.ts` | Simulate host shutdown, verify client takeover sequence. Test crash recovery with jitter |
| `health-endpoint.ts` | Verify JSON response format |
| `environment-detection.ts` | Mock `process.env` and `existsSync`, verify detection logic |

### 8.3 Integration tests

Full-stack tests using the mock plugin, exercising the complete request/response path.

**Single session scenarios:**
- Connect mock plugin, create `BridgeConnection`, resolve session, execute action, verify response
- Plugin disconnects, verify `session-disconnected` event fires
- Plugin reconnects (same instanceId), verify session is restored without duplication

**Multiple session scenarios:**
- Connect two mock plugins with different `instanceId`s, verify both appear in `listSessions()` and `listInstances()`
- Target a specific session by ID, verify action reaches the correct plugin
- `resolveSession()` with no ID throws when multiple instances exist
- Connect three mock plugins with the same `instanceId` but different contexts (edit, client, server), verify they group into one instance
- `resolveSession()` with one instance in Play mode returns Edit context by default
- `resolveSession(undefined, 'server')` returns the Server context session
- `resolveSession(undefined, 'server')` throws `ContextNotFoundError` when only Edit context exists
- Disconnect Client and Server contexts, verify instance remains with only Edit context
- Disconnect all contexts for an instance, verify `instance-disconnected` event fires

**Host/client scenarios:**
- Start two `BridgeConnection` instances on the same port, verify first is host, second is client
- Client sends action, verify it is forwarded through host to plugin
- Client receives session events when plugins connect/disconnect

**Host crash + client takeover:**
- Start host, connect client and mock plugin
- Kill the host (close its transport server)
- Verify client detects disconnect and attempts to become new host
- Verify mock plugin reconnects to the new host
- Verify actions continue to work through the new host

**Reconnection:**
- Start host, connect mock plugin
- Temporarily disconnect the plugin's WebSocket
- Verify the plugin's session survives the grace period if it reconnects in time
- Verify the session is removed if the grace period expires

**Timeout:**
- Send action to a mock plugin that does not respond
- Verify the action rejects with `ActionTimeoutError` after the configured timeout

**Concurrent actions:**
- Send multiple actions to the same session simultaneously
- Verify all resolve with correct responses (request ID correlation)

### 8.4 Test infrastructure

- All tests use ephemeral ports (`port: 0`) to avoid conflicts with other tests or running instances
- Tests clean up all connections and servers in `afterEach` to prevent resource leaks
- The mock plugin helper supports configurable delays, errors, and partial responses for edge case testing
- Integration tests use a `TestHarness` that manages bridge host, clients, and mock plugins with a single `teardown()` call

## 9. Configuration

### 9.1 Port

| Setting | Value |
|---------|-------|
| Default port | 38741 |
| Override via CLI | `--port <number>` |
| Override via env | `STUDIO_BRIDGE_PORT` |
| Override via options | `BridgeConnectionOptions.port` |

### 9.2 Health endpoint

```
GET /health HTTP/1.1
Host: localhost:38741

HTTP/1.1 200 OK
Content-Type: application/json

{
  "status": "ok",
  "port": 38741,
  "protocolVersion": 2,
  "serverVersion": "0.5.0",
  "sessions": 2,
  "uptime": 45230
}
```

### 9.3 Timing constants

| Constant | Value | Description |
|----------|-------|-------------|
| Heartbeat interval | 15 seconds | Plugin sends heartbeat to host |
| Heartbeat stale | 45 seconds | 3 missed heartbeats = mark session stale |
| Heartbeat disconnect | 60 seconds | 4 missed heartbeats = remove session |
| Session grace period | 2 seconds | Time before a disconnected session is removed |
| Idle shutdown delay | 5 seconds | Host waits before exiting when idle |
| Reconnection backoff | 1s, 2s, 4s, 8s, max 30s | Client and plugin reconnection |
| Stale port retry | 1 second, 3 retries | When port is bound but not a bridge host |
| Hand-off jitter | 0-500ms random | Prevents thundering herd on crash |
| WebSocket ping | 30 seconds | Low-level keep-alive (ws library) |

### 9.4 WebSocket configuration

| Setting | Value |
|---------|-------|
| Max frame size | 16 MB (`maxPayload: 16 * 1024 * 1024`) |
| Compression | Enabled (`perMessageDeflate: true`) |
| Ping interval | 30 seconds |

### 9.5 Resource limits

The bridge host enforces hard limits to prevent runaway resource usage. These are not configurable -- they are safe defaults that no legitimate workload should hit.

| Resource | Limit | Behavior on exceed |
|----------|-------|--------------------|
| Max concurrent sessions | 20 | Reject new `register` with `SERVER_FULL` error |
| Max connected CLI clients | 50 | Reject new WebSocket upgrade with HTTP 503 |
| Max pending requests per session | 10 | Reject new `performActionAsync` with `TOO_MANY_REQUESTS` error |
| WebSocket max payload | 16 MB (`maxPayload: 16 * 1024 * 1024`) | Connection closed by ws library |
| Health endpoint response timeout | 500 ms | Returns 503 if internal state collection takes too long |

These limits exist primarily to catch bugs (e.g., a leaked request loop) and to keep the host responsive under unexpected load. In normal usage, a single developer has 1-3 sessions (one Studio instance in Play mode) and 1-2 CLI clients.

## 10. Error Handling

### 10.1 Error surfacing principle

Every error path in the Bridge Network either:
1. Rejects a promise with a typed error (e.g., `ActionTimeoutError`)
2. Emits an `'error'` event on `BridgeConnection`
3. Throws synchronously (for programming errors like calling methods after disconnect)

There are no silent failures. No swallowed exceptions. No errors that disappear into a log without also being reported to the consumer.

### 10.2 Error scenarios and their handling

| Scenario | Error type | Where surfaced |
|----------|-----------|---------------|
| Port 38741 held by non-bridge process | `HostUnreachableError` | `connectAsync()` rejects |
| No plugin connects within timeout | `ActionTimeoutError` | `waitForSession()` rejects |
| Session ID not found | `SessionNotFoundError` | `getSession()` returns undefined; `resolveSession()` rejects |
| Requested context not connected | `ContextNotFoundError` | `resolveSession(undefined, 'server')` rejects when Studio is in Edit mode (Server context not available) |
| Multiple instances, no disambiguation | `SessionNotFoundError` | `resolveSession()` rejects with instance list when N > 1 instances and no `sessionId` provided |
| Plugin does not respond to action | `ActionTimeoutError` | `session.execAsync()` (or other action) rejects |
| Plugin responds with error | Protocol-specific error mapped to typed error | Action method rejects |
| Plugin disconnects mid-action | `SessionDisconnectedError` | In-flight action rejects |
| Plugin lacks required capability | `CapabilityNotSupportedError` | Action method rejects |
| Host crashes while client has in-flight action | `SessionDisconnectedError` | In-flight action rejects; then client attempts takeover |
| `serve` command and port already in use | `PortInUseError` | `connectAsync()` rejects (serve does not fall back to client) |
| Hand-off fails (no client can bind) | `HandOffFailedError` | Emitted on `'error'` event |

### 10.3 Error recovery

The Bridge Network attempts automatic recovery where possible:
- **Plugin disconnect**: grace period allows reconnection without consumer impact
- **Host crash**: clients automatically attempt takeover; plugins automatically reconnect
- **Transient network errors**: transport client reconnects with exponential backoff

When automatic recovery fails, errors are surfaced to the consumer so they can decide how to respond (retry, abort, prompt the user, etc.).

## 11. Security Model

### 11.1 All connections are localhost

The bridge host binds to `localhost` only (not `0.0.0.0`). No external network access is introduced. In split-server mode, the connection between container and host goes through secure port forwarding (SSH tunnel, VS Code forwarding), which is also effectively localhost on both ends.

### 11.2 Plugin authentication

Plugin connections are validated by the `register`/`hello` handshake. The bridge host verifies the message format before accepting the connection. Session IDs are UUIDv4 (128 bits of entropy), making them unguessable by other processes.

### 11.3 Client authentication

In the initial implementation, bridge client connections on `/client` are unauthenticated. This is acceptable because:
- All connections are localhost (or port-forwarded localhost through a secure tunnel)
- The threat model is preventing accidental cross-user access, not sandboxing within a single user session
- Any process running as the same user could already inspect the port and connect

If a future requirement demands stricter isolation, a bearer token mechanism can be added to the bridge host's client connection handler without changing the public API. `BridgeConnectionOptions` would gain an `authToken?: string` field; the token would be passed in the WebSocket upgrade headers.

## 12. Topology Summary

```
Studio A (Edit) ────────────┐
                             │  /plugin WebSocket
Studio B (Edit) ────────────┤
Studio B (Server) ──────────┼──────────> Bridge Host (:38741)
Studio B (Client) ──────────┤                │
                             │                │  instanceId groups:
Studio C (Edit) ────────────┘                │    A: [edit]
                                              │    B: [edit, server, client]
                                              │    C: [edit]
                                              │
                                              │  /client WebSocket
                              ┌───────────────┤
                              │               │
                        CLI (client)    MCP server (client)
                        (exec, run,     (studio_exec,
                         terminal)       studio_state, ...)
                              │               │
                              v               v
                        BridgeConnection  BridgeConnection
                        BridgeSession     BridgeSession
                              │               │
                              └───────┬───────┘
                                      │
                               Consumer code
                            (identical in all cases)
```

Studio B is in Play mode: it has 3 plugin connections (Edit, Server, Client) all sharing one `instanceId`. The bridge host groups them into a single `InstanceInfo`. Studios A and C are in Edit mode with one connection each.

The bridge host may be:
- **Implicit**: the first CLI process that happened to bind the port (most common for local development)
- **Explicit**: a dedicated `studio-bridge serve` process (for devcontainer/remote workflows)
- **Terminal**: a `studio-bridge terminal --keep-alive` process (explicit host with a REPL attached)

In all cases, the consumer API is identical. `BridgeConnection.connectAsync()` resolves to a working connection regardless of the host's origin.
