# Protocol Extensions: Technical Specification

This document defines the extended WebSocket protocol for studio-bridge persistent sessions. It covers message versioning, request/response correlation, all new message types, capability negotiation, error handling, and backward compatibility. This is the companion document referenced from `00-overview.md` section 6.

## 1. Design Principles

1. **Additive only** -- New message types and fields are added alongside existing ones. No existing message type is removed or has its semantics changed.
2. **Old plugins keep working** -- A legacy plugin that speaks only `hello`/`output`/`scriptComplete` must work with a new server without modification.
3. **New plugins degrade gracefully** -- A new plugin connecting to an old server must detect the lack of extended capabilities and fall back to basic behavior.
4. **Correlation is typed** -- Request/response messages extend `RequestMessage` (which requires `requestId`), push messages extend `PushMessage` (no `requestId`). The type system enforces which messages carry correlation IDs rather than relying on optional fields. Legacy fire-and-forget messages remain valid.
5. **Typed, not stringly** -- Every message type has a dedicated TypeScript interface. The union types are exhaustive and the compiler enforces correctness. The `BaseMessage` / `RequestMessage` / `PushMessage` hierarchy makes the correlation semantics visible at the type level.

## 2. Message Envelope

### 2.1 Current envelope (preserved)

Every message on the wire is a JSON object with three required fields:

```typescript
{
  type: string;
  sessionId: string;
  payload: object;
}
```

This structure is unchanged. All existing messages continue to use it exactly as they do today.

### 2.2 Extended envelope

New messages may include two additional top-level fields:

```typescript
{
  type: string;
  sessionId: string;
  payload: object;
  requestId?: string;      // present on request/response messages only
  protocolVersion?: number; // present only in handshake messages (hello, welcome, register)
}
```

- **`requestId`** -- A caller-generated unique string (UUIDv4 recommended). Present on request messages and echoed back on the corresponding response or error. Absent on unsolicited push messages (`output`, `stateChange`, `logPush`, `heartbeat`). In the TypeScript type hierarchy, messages that require `requestId` extend `RequestMessage`, which makes it a required field. Messages that never have a `requestId` extend `PushMessage`. A few messages (`execute`, `scriptComplete`, `error`) use `BaseMessage` with an optional `requestId` because they bridge v1 and v2 behavior.
- **`protocolVersion`** -- An integer indicating which protocol revision the sender supports. Present only on `hello`, `welcome`, and `register` messages during handshake. Absent on all other messages (the negotiated version is established once and held for the connection lifetime). This field belongs in the wire envelope, not in the TypeScript base message types.

Legacy messages that omit these fields are valid. A decoder must treat missing `requestId` as `undefined` and missing `protocolVersion` as `1` (the implicit version of the original protocol).

## 3. Protocol Versioning

### 3.1 Version numbering

Versions are positive integers, not semver. Each version is a strict superset of the previous one.

| Version | Capabilities |
|---------|-------------|
| 1 | Original protocol: `hello`, `welcome`, `execute`, `output`, `scriptComplete`, `shutdown` |
| 2 | Adds: `register`, `queryState`, `stateResult`, `captureScreenshot`, `screenshotResult`, `queryDataModel`, `dataModelResult`, `queryLogs`, `logsResult`, `subscribe`, `unsubscribe`, `stateChange`, `logPush`, `heartbeat`, `error`. Adds `requestId` correlation, `protocolVersion` negotiation, `capabilities` in handshake. |

### 3.2 Negotiation during handshake

The plugin sends its maximum supported version in the `hello` (or `register`) message:

```json
{
  "type": "hello",
  "sessionId": "abc-123",
  "protocolVersion": 2,
  "payload": {
    "sessionId": "abc-123",
    "capabilities": ["execute", "queryState", "captureScreenshot", "queryDataModel", "queryLogs", "subscribe"],
    "pluginVersion": "1.0.0"
  }
}
```

The server responds with the effective version -- the minimum of the server's version and the plugin's version:

```json
{
  "type": "welcome",
  "sessionId": "abc-123",
  "protocolVersion": 2,
  "payload": {
    "sessionId": "abc-123",
    "capabilities": ["execute", "queryState", "captureScreenshot", "queryDataModel", "queryLogs", "subscribe"]
  }
}
```

The `capabilities` list in the `welcome` response is the intersection of what the plugin offered and what the server intends to use. The server must not send message types that require capabilities the plugin did not advertise.

### 3.2.1 Plugin version negotiation

The `hello` (or `register`) message includes an optional `pluginVersion` field (semver string, e.g., `"1.0.0"`). The server's `welcome` response includes a `serverVersion` field. The server compares `pluginVersion` to its own minimum-supported plugin version. If the plugin version is older than the minimum, the server still completes the handshake (to maintain backward compatibility), but logs a warning: `"Plugin version {pluginVersion} is older than recommended minimum {minVersion}. Some features may not work. Run 'studio-bridge install-plugin' to update."` The server also includes a `pluginUpdateAvailable: true` field in the `welcome` payload when the plugin is outdated. The CLI can surface this warning to the user on the next interactive command. The minimum-supported plugin version is a constant in the server code, bumped only when a protocol-breaking change is introduced.

### 3.3 Omitted version field

If `protocolVersion` is absent from `hello`, the server treats it as version 1. The server responds with a version 1 `welcome` (no `protocolVersion` field, no `capabilities`). This is exactly today's behavior.

### 3.4 Forward compatibility

If a plugin sends a `protocolVersion` higher than the server supports, the server clamps to its own maximum and responds accordingly. The plugin must handle receiving a lower version than it requested and disable features that require the higher version.

If either side receives an unknown message type, it must ignore the message (not disconnect, not error). This allows future versions to add message types without breaking older peers.

## 4. Request/Response Correlation

### 4.1 Problem

The current protocol is sequential: the server sends `execute`, then waits for `output` messages followed by a single `scriptComplete`. There is no way to have two operations in flight simultaneously, and no way to match a response to a specific request.

### 4.2 Solution

Request messages include a `requestId` field. The corresponding response echoes the same `requestId`. The server can have multiple requests in flight to the same plugin, and the plugin can respond to them in any order.

```
Server → Plugin:  { type: "queryState", sessionId: "...", requestId: "req-001", payload: {} }
Server → Plugin:  { type: "queryLogs",  sessionId: "...", requestId: "req-002", payload: { count: 50 } }

Plugin → Server:  { type: "logsResult",  sessionId: "...", requestId: "req-002", payload: { ... } }
Plugin → Server:  { type: "stateResult", sessionId: "...", requestId: "req-001", payload: { ... } }
```

### 4.3 Rules

- Every request message (server-to-plugin query) must include a `requestId`.
- The corresponding response must echo the exact same `requestId`.
- If a request cannot be fulfilled, the plugin sends an `error` message with that `requestId` (see section 7).
- Unsolicited push messages (`output`, `stateChange`, `logPush`, `heartbeat`) do not have a `requestId`.
- The legacy `execute` message may optionally include a `requestId`. If present, `scriptComplete` echoes it. If absent, the existing sequential behavior applies. This preserves backward compatibility with old servers that send `execute` without a `requestId`.
- The server must time out requests that receive no response. Default timeouts are per-message-type (see the Timeout Defaults table in section 7.4). On timeout, the server resolves with an error locally; it does not send a cancellation to the plugin.

### 4.4 Concurrency limits

The plugin may execute at most one `execute` script at a time (Luau is single-threaded; concurrent `loadstring` calls would interfere). If the server sends a second `execute` while the first is in flight, the plugin must queue it and respond with each `scriptComplete` in order. Queries (`queryState`, `queryLogs`, `queryDataModel`, `captureScreenshot`) are lightweight and can be processed concurrently with a running script.

## 5. Complete Message Type Catalog

### 5.1 Existing messages (version 1, unchanged)

These six message types are defined in the current `web-socket-protocol.ts` and are fully preserved.

**Plugin to Server:**

| Type | Payload | Purpose |
|------|---------|---------|
| `hello` | `{ sessionId: string }` | Initiate handshake |
| `output` | `{ messages: Array<{ level: OutputLevel, body: string }> }` | Batched log output |
| `scriptComplete` | `{ success: boolean, error?: string }` | Script execution finished |

**Server to Plugin:**

| Type | Payload | Purpose |
|------|---------|---------|
| `welcome` | `{ sessionId: string }` | Accept handshake |
| `execute` | `{ script: string }` | Run a Luau script |
| `shutdown` | `{}` | Request disconnect |

### 5.2 New Server to Plugin messages (version 2)

#### `queryState`

Request the current Studio state.

```typescript
{
  type: 'queryState';
  sessionId: string;
  requestId: string;
  payload: {};
}
```

Expected response: `stateResult` or `error`.

#### `captureScreenshot`

Request a viewport capture.

```typescript
{
  type: 'captureScreenshot';
  sessionId: string;
  requestId: string;
  payload: {
    format?: 'png';  // only png supported initially; field reserved for future formats
  };
}
```

Expected response: `screenshotResult` or `error`.

The plugin uses `CaptureService:CaptureScreenshot(callback)` to capture the 3D viewport. CaptureService is confirmed to work in Studio plugins. The callback receives a `contentId` string, which is loaded into an `EditableImage` (via `AssetService:CreateEditableImageAsync(contentId)` or similar). The pixel bytes are read from the `EditableImage` and base64-encoded before transmission. See `04-action-specs.md` section 4 (screenshot plugin handler) for the full call chain.

#### `queryDataModel`

Query the instance tree and/or properties.

```typescript
{
  type: 'queryDataModel';
  sessionId: string;
  requestId: string;
  payload: {
    path: string;            // dot-separated instance path, e.g. "game.Workspace.SpawnLocation"
    depth?: number;          // max child traversal depth (default: 0 = instance only, no children)
    properties?: string[];   // property names to read (default: Name, ClassName, Parent)
    includeAttributes?: boolean;  // include all attributes (default: false)
    find?: {                 // optional: search for instances by name
      name: string;          // instance name to search for
      recursive?: boolean;   // true = FindFirstDescendant, false = FindFirstChild (default: false)
    };
    listServices?: boolean;  // if true, ignores path and returns all loaded services (default: false)
  };
}
```

When `find` is provided, the plugin resolves `path` first, then calls `FindFirstChild(name)` or searches descendants. The result is the found instance (or an error if not found).

When `listServices` is true, the plugin returns a list of all services loaded in the DataModel as the children of `game`. The `path` field is ignored.

Expected response: `dataModelResult` or `error`.

**Path format**: Dot-separated, matching Roblox convention. All paths in the wire protocol start from `game` (the DataModel root). The plugin resolves the path by splitting on `.` and calling `FindFirstChild` at each segment starting from `game`. Examples:
- `game.Workspace` -- the Workspace service
- `game.Workspace.SpawnLocation` -- a named child of Workspace
- `game.Workspace.Part1.Position` -- a property path (the plugin resolves up to the instance, then reads the property)
- `game.ReplicatedStorage.Modules.MyModule` -- nested path
- `game.StarterPlayer.StarterPlayerScripts` -- service child

**Path resolution algorithm** (plugin side):
1. Split the path on `.` to get segments: `["game", "Workspace", "SpawnLocation"]`.
2. Start at `game` (the DataModel root). Skip the first segment (which must be `"game"`).
3. For each subsequent segment, call `current:FindFirstChild(segment)`.
4. If `FindFirstChild` returns `nil` at any point, return an `INSTANCE_NOT_FOUND` error with `resolvedTo` (the dot-path of the last successful instance) and `failedSegment` (the segment that failed).
5. The final resolved instance is the target for property reads, child enumeration, etc.

**Edge case -- instance names containing dots**: Instance names containing literal dots (e.g., a Part named `"my.part"`) are rare in practice. The current path format does not support escaping dots. If an instance name contains a dot, `FindFirstChild` will fail to resolve it because the dot is treated as a path separator. This is a known limitation. Implementers may choose to document this as unsupported, or add escaping support (e.g., backslash-dot `\.`) in a future protocol version.

**CLI path translation**: The CLI accepts user-facing paths without the `game.` prefix (e.g., `studio-bridge query Workspace.SpawnLocation`). The CLI prepends `game.` before sending the `queryDataModel` message. If the user explicitly includes `game.` the CLI does not double-prefix. This keeps the CLI ergonomic while the wire protocol is unambiguous.

#### `queryLogs`

Request buffered log history from the plugin.

```typescript
{
  type: 'queryLogs';
  sessionId: string;
  requestId: string;
  payload: {
    count?: number;            // max entries to return (default: 50)
    direction?: 'head' | 'tail';  // 'head' = oldest first from start, 'tail' = newest first from end (default: 'tail')
    levels?: OutputLevel[];    // filter by level (default: all levels)
    includeInternal?: boolean; // include [StudioBridge] internal messages (default: false)
  };
}
```

Expected response: `logsResult` or `error`.

The plugin maintains a ring buffer of log entries (default capacity: 1000). This query reads from that buffer.

- `direction: 'tail'` (default): Returns the most recent `count` entries, in chronological order. This maps to the CLI's `--tail` flag.
- `direction: 'head'`: Returns the oldest `count` entries from the buffer, in chronological order. This maps to the CLI's `--head` flag.

Internal `[StudioBridge]` messages are filtered out by default (`includeInternal: false`). The CLI's `--all` flag maps to `includeInternal: true`.

#### `subscribe`

Subscribe to push events from the plugin.

```typescript
{
  type: 'subscribe';
  sessionId: string;
  requestId: string;
  payload: {
    events: SubscribableEvent[];
  };
}
```

Where `SubscribableEvent` is one of:
- `'stateChange'` -- receive `stateChange` push messages when Studio transitions between modes. This is the mechanism that backs the CLI's `studio-bridge state --watch` mode. Transport: WebSocket push. The plugin sends `stateChange` messages over its WebSocket connection to the bridge host; the host forwards them to all CLI clients that have an active `stateChange` subscription for that session.
- `'logPush'` -- receive `logPush` push messages as log entries are generated (from `LogService.MessageOut`). This is the mechanism that backs the CLI's `studio-bridge logs --follow` mode. Transport: WebSocket push. The plugin sends `logPush` messages over its WebSocket connection to the bridge host; the host forwards them to all CLI clients that have an active `logPush` subscription for that session. Unlike the `output` message (which is scoped to script execution and batches multiple lines), `logPush` is a continuous stream of individual log entries from all sources, not limited to script output.

The full subscription flow is:

1. **CLI sends `subscribe`** to the bridge host with the desired events (e.g., `['stateChange']` or `['logPush']`).
2. **Bridge host forwards `subscribe`** to the plugin over the plugin's WebSocket connection.
3. **Plugin confirms** by sending a `subscribeResult` response, then begins pushing the requested event messages (`stateChange` and/or `logPush`).
4. **Bridge host forwards push messages** from the plugin to all CLI clients that are subscribed to that event for that session.
5. **CLI sends `unsubscribe`** to stop receiving push messages. The bridge host forwards the `unsubscribe` to the plugin, which confirms with `unsubscribeResult` and stops pushing.

Subscriptions are maintained as a map on the bridge host: `Map<clientId, Set<SubscribableEvent>>` per session. See `07-bridge-network.md` for the host-side routing details.

The plugin confirms the subscription by sending a `subscribeResult` response, then begins pushing the requested event messages.

```typescript
// Plugin → Server (confirmation)
{
  type: 'subscribeResult';
  sessionId: string;
  requestId: string;
  payload: {
    events: SubscribableEvent[];  // the events actually subscribed (may be subset if some unsupported)
  };
}
```

Subscriptions persist for the lifetime of the WebSocket connection. They do not survive reconnection; the server must resubscribe after the plugin reconnects.

#### `unsubscribe`

Cancel one or more event subscriptions.

```typescript
{
  type: 'unsubscribe';
  sessionId: string;
  requestId: string;
  payload: {
    events: SubscribableEvent[];
  };
}
```

Expected response: `unsubscribeResult` echoing the events that were actually unsubscribed.

```typescript
{
  type: 'unsubscribeResult';
  sessionId: string;
  requestId: string;
  payload: {
    events: SubscribableEvent[];
  };
}
```

### 5.3 New Plugin to Server messages (version 2)

#### `register`

Alternative to `hello` for persistent plugin sessions. The persistent plugin uses `register` instead of `hello` to provide richer metadata about itself.

The plugin generates a UUID (via `HttpService:GenerateGUID()` in Luau) and sends it as the `sessionId` in the `register` message. The server accepts the plugin's ID unless there is a collision with an existing session, in which case the server generates a replacement ID. The server's `welcome` response contains the authoritative `sessionId`. The plugin must use the `sessionId` from the `welcome` response for all subsequent messages (in case the server overrode it).

```typescript
{
  type: 'register';
  sessionId: string;          // plugin-generated UUID (proposed session ID)
  protocolVersion: number;
  payload: {
    pluginVersion: string;    // semver of the installed persistent plugin
    instanceId: string;       // unique ID for this Studio installation (persisted in plugin settings, shared across all contexts of the same Studio)
    context: SessionContext;   // which plugin context is connecting: 'edit', 'client', or 'server'
    placeName: string;        // DataModel.Name
    placeId: number;          // game.PlaceId (0 if unpublished)
    gameId: number;           // game.GameId (0 if unpublished)
    placeFile?: string;       // file path if available (may be nil for published-only places)
    state: StudioState;       // current run mode of THIS context (not the whole Studio)
    pid?: number;             // Studio process ID if detectable
    capabilities: Capability[];
  };
}
```

The server responds with a `welcome` message, identical to the `hello` flow. The `register` message is treated as a superset of `hello` -- it establishes the handshake and provides discovery metadata in a single message. The `welcome` response's `sessionId` is authoritative -- the plugin must adopt it, since the server may have overridden the plugin's proposed ID (e.g., due to a collision).

**Multi-context sessions**: When Studio enters Play mode, 2 new plugin instances (server and client) connect independently, joining the already-connected edit instance. Each sends its own `register` message over its own WebSocket:
- **Edit context** (`context: 'edit'`): Always present. `state` is always `'Edit'`.
- **Play-Server context** (`context: 'server'`): Present during Play/Run. `state` is `'Run'` or `'Paused'`.
- **Play-Client context** (`context: 'client'`): Present during Play. `state` is `'Play'` or `'Paused'`.

All three share the same `instanceId` (identifying the Studio installation) but have different `context` values. The server uses the `(instanceId, context)` pair to uniquely identify each connection. The `state` field in the `register` message reflects the state of that specific context, not the state of the Studio as a whole.

If the server does not recognize `register` (old server, version 1), the plugin falls back to sending `hello` instead.

#### `stateResult`

Response to `queryState`.

```typescript
{
  type: 'stateResult';
  sessionId: string;
  requestId: string;
  payload: {
    state: StudioState;
    placeId: number;        // 0 if unpublished
    placeName: string;
    gameId: number;         // 0 if unpublished
  };
}
```

Where `StudioState` is:

```typescript
type StudioState = 'Edit' | 'Play' | 'Paused' | 'Run' | 'Server' | 'Client';
```

These map to Roblox Studio's run modes and are **per-context**, not per-Studio. Each WebSocket connection (each plugin context) reports its own state independently:

- `Edit` -- normal editing, not playing. The Edit context is always in this state.
- `Play` -- Play solo, client context. The Client context reports this state during active play.
- `Run` -- Run mode (server context, no character). The Server context reports this state during active play.
- `Paused` -- Play or Run, but paused. Whichever context is paused reports this state.
- `Server` -- Team Test server.
- `Client` -- Team Test client.

States are **not mutually exclusive across contexts**. During Play mode, the Server context may report `'Run'` while the Client context simultaneously reports `'Play'`. Each context's state is independent.

#### `screenshotResult`

Response to `captureScreenshot`.

```typescript
{
  type: 'screenshotResult';
  sessionId: string;
  requestId: string;
  payload: {
    data: string;          // base64-encoded image data
    format: 'png';
    width: number;         // pixel dimensions of the captured image
    height: number;
  };
}
```

**Size considerations**: A 1920x1080 PNG screenshot is typically 500KB-2MB, which base64-encodes to 670KB-2.7MB. WebSocket frames can handle this, but the server should set a generous max frame size (at least 10MB) and the implementation should be aware of memory pressure when handling multiple screenshots in flight.

#### `dataModelResult`

Response to `queryDataModel`.

```typescript
{
  type: 'dataModelResult';
  sessionId: string;
  requestId: string;
  payload: {
    instance: DataModelInstance;
  };
}
```

Where `DataModelInstance` is a recursive structure:

```typescript
interface DataModelInstance {
  name: string;
  className: string;
  path: string;                          // full dot-separated path from game
  properties: Record<string, SerializedValue>;
  attributes: Record<string, SerializedValue>;
  childCount: number;
  children?: DataModelInstance[];         // present only if depth > 0 was requested
}
```

And `SerializedValue` handles Roblox types. Primitive types (string, number, boolean) are passed through as bare JSON values without wrapping. Complex Roblox types use a `type` discriminant field and a flat `value` array containing the numeric components:

```typescript
type SerializedValue =
  | string                                                                   // bare primitive
  | number                                                                   // bare primitive
  | boolean                                                                  // bare primitive
  | null
  | { type: 'Vector3'; value: [number, number, number] }                    // [x, y, z]
  | { type: 'Vector2'; value: [number, number] }                            // [x, y]
  | { type: 'CFrame'; value: [number, number, number, number, number, number, number, number, number, number, number, number] }
    // [posX, posY, posZ, r00, r01, r02, r10, r11, r12, r20, r21, r22] -- position xyz + 9 rotation matrix components
  | { type: 'Color3'; value: [number, number, number] }                     // [r, g, b] in 0-1 range
  | { type: 'UDim2'; value: [number, number, number, number] }              // [xScale, xOffset, yScale, yOffset]
  | { type: 'UDim'; value: [number, number] }                               // [scale, offset]
  | { type: 'BrickColor'; name: string; value: number }                     // name + numeric ID
  | { type: 'EnumItem'; enum: string; name: string; value: number }         // enum type name, item name, numeric value
  | { type: 'Instance'; className: string; path: string }                   // reference to another instance via dot-path
  | { type: 'Unsupported'; typeName: string; toString: string };            // fallback for types we cannot serialize
```

**Wire examples**:

```json
// Vector3
{ "type": "Vector3", "value": [1, 2, 3] }

// Vector2
{ "type": "Vector2", "value": [1, 2] }

// CFrame (position xyz + 9 rotation matrix components)
{ "type": "CFrame", "value": [1, 2, 3, 1, 0, 0, 0, 1, 0, 0, 0, 1] }

// Color3
{ "type": "Color3", "value": [0.5, 0.2, 1.0] }

// UDim2
{ "type": "UDim2", "value": [0.5, 100, 0.5, 200] }

// UDim
{ "type": "UDim", "value": [0.5, 100] }

// BrickColor
{ "type": "BrickColor", "name": "Bright red", "value": 21 }

// EnumItem
{ "type": "EnumItem", "enum": "Material", "name": "Plastic", "value": 256 }

// Instance reference (dot-separated path)
{ "type": "Instance", "className": "Part", "path": "game.Workspace.Part1" }

// Primitives are passed as-is without wrapping
"hello"
42
true

// Unsupported type (fallback)
{ "type": "Unsupported", "typeName": "Ray", "toString": "Ray(0, 0, 0, 1, 0, 0)" }
```

The `type` discriminant field allows the receiver to reconstruct or display Roblox-specific types. The flat `value` array format is compact and easy to destructure. Simple types (string, number, boolean) are passed through as JSON primitives without wrapping. The `Unsupported` variant ensures the plugin never fails to serialize a property -- it always produces a string representation as a last resort.

#### `logsResult`

Response to `queryLogs`.

```typescript
{
  type: 'logsResult';
  sessionId: string;
  requestId: string;
  payload: {
    entries: Array<{
      level: OutputLevel;
      body: string;
      timestamp: number;    // milliseconds since plugin connection established (monotonic)
    }>;
    total: number;           // total entries in the ring buffer (before offset/count filtering)
    bufferCapacity: number;  // max entries the ring buffer can hold
  };
}
```

Timestamps are relative to the plugin's connection time rather than wall-clock time, because Roblox's `os.clock()` provides a monotonic timer but `os.time()` is only second-precision and cannot be reliably correlated with the server's clock.

#### `stateChange`

Unsolicited push notification when a plugin context transitions between run modes. Only sent if the server has an active `stateChange` subscription. This message is **per-WebSocket-connection** (per-context), not per-Studio -- each context reports its own state transitions independently over its own WebSocket.

```typescript
{
  type: 'stateChange';
  sessionId: string;
  payload: {
    previousState: StudioState;
    newState: StudioState;
    timestamp: number;         // monotonic ms since connection
  };
}
```

No `requestId` -- this is a push message.

The plugin detects state changes by listening to `RunService` events:
- `RunService:IsEdit()` transitions
- `RunService.Running` / `RunService.Stopped` signals
- `RunService:IsRunMode()`, `RunService:IsClient()`, `RunService:IsServer()` checks

Because each context has its own WebSocket, a single "Play" button press in Studio may produce `stateChange` messages on multiple connections simultaneously (e.g., the Server context transitions to `'Run'` and the Client context transitions to `'Play'`).

#### `logPush`

Unsolicited push notification containing a log entry generated by the plugin context. Only sent if the server has an active `logPush` subscription. This is the continuous log stream that backs `studio-bridge logs --follow`. Unlike the `output` message (which batches log lines produced during script execution), `logPush` streams individual entries from all sources (LogService, print, warn, error) regardless of whether a script is executing.

```typescript
{
  type: 'logPush';
  sessionId: string;
  payload: {
    entry: {
      level: OutputLevel;    // 'Print' | 'Info' | 'Warning' | 'Error'
      body: string;
      timestamp: number;     // monotonic ms since plugin connection
    };
  };
}
```

No `requestId` -- this is a push message.

The plugin generates `logPush` messages by listening to `LogService.MessageOut`. When a `logPush` subscription is active, each log entry is sent individually as it occurs (not batched). Internal `[StudioBridge]` messages are included in the push stream; filtering is the responsibility of the receiving CLI client, which applies the user's `--level` and `--all` flags locally.

#### `heartbeat`

Keep-alive message from the plugin to the server, sent at a regular interval to prevent WebSocket idle timeouts and to allow the server to detect stale connections quickly.

```typescript
{
  type: 'heartbeat';
  sessionId: string;
  payload: {
    uptimeMs: number;           // ms since plugin connected
    state: StudioState;         // current state as a convenience
    pendingRequests: number;    // number of unfinished requests the plugin is processing
  };
}
```

No `requestId` -- this is an unsolicited push message.

### Heartbeat Protocol

- **Plugin → Server**: Every 15 seconds
- **Server stale detection**: 45 seconds (3 missed heartbeats) → mark session as stale
- **Server disconnect**: 60 seconds (4 missed heartbeats) → remove session, emit `session-disconnected`
- **Heartbeat payload**: `{ uptimeMs: number, state: StudioState, pendingRequests: number }`

The server does not respond to heartbeats. Stale detection and disconnect thresholds are based on missed heartbeat intervals as described above.

#### `subscribeResult`

Confirmation of a `subscribe` request. See section 5.2 under `subscribe`.

#### `unsubscribeResult`

Confirmation of an `unsubscribe` request. See section 5.2 under `unsubscribe`.

### 5.4 Error message (bidirectional, version 2)

Either side can send an `error` message, though in practice it is almost always the plugin responding to a server request.

```typescript
{
  type: 'error';
  sessionId: string;
  requestId?: string;    // present if this is a response to a specific request
  payload: {
    code: ErrorCode;
    message: string;     // human-readable description
    details?: unknown;   // optional structured data for debugging
  };
}
```

### 5.5 Extended `hello` and `welcome` (version 2 additions)

When a version 2 plugin sends `hello`, it includes additional optional fields:

```typescript
// Extended hello payload (version 2)
{
  type: 'hello';
  sessionId: string;
  protocolVersion: 2;
  payload: {
    sessionId: string;              // preserved from v1
    capabilities?: Capability[];    // new in v2
    pluginVersion?: string;         // new in v2
  };
}
```

When a version 2 server sends `welcome`, it includes:

```typescript
// Extended welcome payload (version 2)
{
  type: 'welcome';
  sessionId: string;              // authoritative session ID (confirms or overrides the plugin's proposed ID)
  protocolVersion: 2;
  payload: {
    sessionId: string;              // same as envelope sessionId (preserved from v1 for backward compat)
    capabilities?: Capability[];    // new in v2, intersection of plugin + server capabilities
    serverVersion?: string;         // new in v2
  };
}
```

The `sessionId` in the `welcome` response is authoritative. If the plugin sent a `register` message with a proposed session ID, the server may accept it as-is or override it (e.g., if it collides with an existing session). The plugin must use the `sessionId` from the `welcome` response for all subsequent messages.

If `capabilities` is omitted from `hello`, the server assumes `['execute']` only (version 1 behavior).

## 6. Capabilities

### 6.1 Capability strings

```typescript
type Capability =
  | 'execute'            // run Luau scripts (required; always present)
  | 'queryState'         // query Studio run mode and place info
  | 'captureScreenshot'  // capture viewport as PNG
  | 'queryDataModel'     // query instance tree and properties
  | 'queryLogs'          // retrieve buffered log history
  | 'subscribe'          // subscribe to push events
  | 'heartbeat';         // send periodic heartbeat
```

### 6.2 Negotiation rules

1. The plugin advertises all capabilities it supports.
2. The server responds with the subset it intends to use (may be all, may be fewer).
3. The server must not send a message type that requires a capability the plugin did not advertise.
4. If the server sends a `queryState` to a plugin that did not advertise `queryState`, the plugin should respond with an `error` of code `CAPABILITY_NOT_SUPPORTED`.
5. The `execute` capability is always implicitly present. Even a version 1 plugin supports it.

### 6.2.1 Capability profiles by plugin type

```typescript
type Capability = 'execute' | 'queryState' | 'captureScreenshot' | 'queryLogs' | 'queryDataModel' | 'subscribe';
```

- Ephemeral (v1) plugins: `['execute']`
- Persistent (v2) plugins: all capabilities

The server checks capabilities before dispatching actions; it returns `UNSUPPORTED_CAPABILITY` if the plugin doesn't advertise the required capability.

### 6.3 Capability requirements by message type

| Message | Required Capability |
|---------|-------------------|
| `execute` | `execute` |
| `queryState` | `queryState` |
| `captureScreenshot` | `captureScreenshot` |
| `queryDataModel` | `queryDataModel` |
| `queryLogs` | `queryLogs` |
| `subscribe` / `unsubscribe` | `subscribe` |
| `heartbeat` | `heartbeat` |
| `shutdown` | (none -- always valid) |

## 7. Error Handling

### 7.1 Error codes

```typescript
type ErrorCode =
  | 'UNKNOWN_REQUEST'              // message type not recognized
  | 'INVALID_PAYLOAD'              // payload failed validation
  | 'TIMEOUT'                      // operation timed out within the plugin
  | 'CAPABILITY_NOT_SUPPORTED'     // plugin does not support the requested capability
  | 'INSTANCE_NOT_FOUND'           // DataModel path did not resolve to an instance
  | 'PROPERTY_NOT_FOUND'           // requested property does not exist on the instance
  | 'SCREENSHOT_FAILED'            // CaptureService call failed
  | 'SCRIPT_LOAD_ERROR'            // loadstring failed (syntax error)
  | 'SCRIPT_RUNTIME_ERROR'         // script threw during execution
  | 'BUSY'                         // plugin is already processing a request of this type
  | 'SESSION_MISMATCH'             // session ID in message does not match connection
  | 'INTERNAL_ERROR';              // unexpected plugin-side error
```

### 7.2 Error response format

```json
{
  "type": "error",
  "sessionId": "abc-123",
  "requestId": "req-001",
  "payload": {
    "code": "INSTANCE_NOT_FOUND",
    "message": "No instance found at path: game.Workspace.NonExistent",
    "details": {
      "resolvedTo": "game.Workspace",
      "failedSegment": "NonExistent"
    }
  }
}
```

### 7.3 Error vs. scriptComplete

For backward compatibility, `execute` failures continue to use `scriptComplete` with `success: false` and an `error` string. The `error` message type is used for query failures and protocol-level errors. This avoids breaking existing consumers that parse `scriptComplete`.

If an `execute` message includes a `requestId` and the script fails, both the `scriptComplete` response (with `requestId`) and the error details in its `error` field carry the failure information. The `error` message type is not sent for script failures; `scriptComplete` is the canonical response.

### Error Retryability

| Error | Retryable | Action |
|-------|-----------|--------|
| `TIMEOUT` | Yes | Retry with same parameters; consider increasing timeout |
| `SESSION_NOT_FOUND` | No | Session does not exist; re-resolve with `resolveSession()` |
| `SESSION_DISCONNECTED` | Yes (after reconnect) | Wait for `session-connected` event, then retry |
| `PLUGIN_ERROR` | Maybe | Plugin-side error; inspect `details` field |
| `INVALID_REQUEST` | No | Malformed request; fix the caller |
| `UNSUPPORTED_CAPABILITY` | No | Plugin does not support this action |
| `HOST_UNREACHABLE` | Yes | Bridge host down; retry with exponential backoff |

### 7.4 Server-side timeout handling

The server maintains a pending request map keyed by `requestId`. When a request times out:

1. The promise associated with the `requestId` is rejected with a timeout error.
2. The `requestId` is removed from the pending map.
3. No message is sent to the plugin. If the plugin eventually responds, the response is ignored (no matching `requestId` in the pending map).

### Timeout Defaults

| Action | Default Timeout | Notes |
|--------|----------------|-------|
| `execute` | 300,000 ms (5 min) | Script execution; overridable per-call |
| `queryState` | 5,000 ms | Fast local operation |
| `captureScreenshot` | 15,000 ms | Rendering + encoding |
| `queryLogs` | 5,000 ms | Read from ring buffer |
| `queryDataModel` | 30,000 ms | Large tree traversal possible |
| `subscribe` | 5,000 ms | Fast registration |
| `unsubscribe` | 5,000 ms | Fast deregistration |
| `register` | 10,000 ms | Handshake + capability negotiation |

This table is the single source of truth for timeout defaults. All implementations must use these values unless the caller explicitly overrides.

## 8. Complete TypeScript Type Definitions

This section provides the full type hierarchy as it would appear in the updated `web-socket-protocol.ts`.

```typescript
// ===========================================================================
// Shared types
// ===========================================================================

export type OutputLevel = 'Print' | 'Info' | 'Warning' | 'Error';

export type StudioState = 'Edit' | 'Play' | 'Paused' | 'Run' | 'Server' | 'Client';

/** Which plugin context this connection represents. */
export type SessionContext = 'edit' | 'client' | 'server';

export type SubscribableEvent = 'stateChange' | 'logPush';

export type SessionOrigin = 'user' | 'managed';

/** Server-side representation of a connected plugin context. */
export interface SessionInfo {
  sessionId: string;
  instanceId: string;          // shared across all contexts of the same Studio installation
  context: SessionContext;     // which plugin context this connection represents
  placeId: number;             // game.PlaceId (0 if unpublished)
  gameId: number;              // game.GameId (0 if unpublished)
  placeName: string;
  state: StudioState;          // current state of THIS context
  pluginVersion: string;
  capabilities: Capability[];
  connectedAt: number;         // server timestamp (ms) when connection was established.
                                // The wire protocol uses a millisecond timestamp (number).
                                // The public TypeScript API converts this to a Date object.
                                // CLI/JSON output serializes as ISO 8601 string.
}

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

// ===========================================================================
// Base message hierarchy
// ===========================================================================
//
// Messages are split into three base types:
//
//   BaseMessage       -- all messages have `type` and `sessionId`
//   RequestMessage    -- request/response messages add a required `requestId`
//   PushMessage       -- unsolicited push messages (no requestId)
//
// Each concrete message extends the appropriate base. `protocolVersion`
// belongs only in the wire envelope (section 2), not in the type hierarchy.
// ===========================================================================

interface BaseMessage {
  type: string;
  sessionId: string;
}

interface RequestMessage extends BaseMessage {
  requestId: string;
}

interface PushMessage extends BaseMessage {
  // no requestId -- unsolicited push messages
}

// ===========================================================================
// Plugin -> Server messages
// ===========================================================================

// --- Version 1 (preserved) ---

export interface HelloMessage extends PushMessage {
  type: 'hello';
  payload: {
    sessionId: string;
    capabilities?: Capability[];
    pluginVersion?: string;
  };
}

export interface OutputMessage extends PushMessage {
  type: 'output';
  payload: {
    messages: Array<{
      level: OutputLevel;
      body: string;
    }>;
  };
}

export interface ScriptCompleteMessage extends BaseMessage {
  type: 'scriptComplete';
  requestId?: string;  // present if the triggering execute had a requestId (v2), absent for v1
  payload: {
    success: boolean;
    error?: string;
  };
}

// --- Version 2 (new) ---

export interface RegisterMessage extends PushMessage {
  type: 'register';
  // sessionId (from PushMessage/BaseMessage) is a plugin-generated UUID.
  // The server accepts it or overrides it; the welcome response is authoritative.
  protocolVersion: number;
  payload: {
    pluginVersion: string;
    instanceId: string;
    context: SessionContext;
    placeName: string;
    placeId: number;
    gameId: number;
    placeFile?: string;
    state: StudioState;
    pid?: number;
    capabilities: Capability[];
  };
}

export interface StateResultMessage extends RequestMessage {
  type: 'stateResult';
  payload: {
    state: StudioState;
    placeId: number;
    placeName: string;
    gameId: number;
  };
}

export interface ScreenshotResultMessage extends RequestMessage {
  type: 'screenshotResult';
  payload: {
    data: string;
    format: 'png';
    width: number;
    height: number;
  };
}

export interface DataModelResultMessage extends RequestMessage {
  type: 'dataModelResult';
  payload: {
    instance: DataModelInstance;
  };
}

export interface LogsResultMessage extends RequestMessage {
  type: 'logsResult';
  payload: {
    entries: Array<{
      level: OutputLevel;
      body: string;
      timestamp: number;
    }>;
    total: number;
    bufferCapacity: number;
  };
}

export interface StateChangeMessage extends PushMessage {
  type: 'stateChange';
  payload: {
    previousState: StudioState;
    newState: StudioState;
    timestamp: number;
  };
}

export interface LogPushMessage extends PushMessage {
  type: 'logPush';
  payload: {
    entry: {
      level: OutputLevel;
      body: string;
      timestamp: number;
    };
  };
}

export interface HeartbeatMessage extends PushMessage {
  type: 'heartbeat';
  payload: {
    uptimeMs: number;
    state: StudioState;
    pendingRequests: number;
  };
}

export interface SubscribeResultMessage extends RequestMessage {
  type: 'subscribeResult';
  payload: {
    events: SubscribableEvent[];
  };
}

export interface UnsubscribeResultMessage extends RequestMessage {
  type: 'unsubscribeResult';
  payload: {
    events: SubscribableEvent[];
  };
}

export interface PluginErrorMessage extends BaseMessage {
  type: 'error';
  requestId?: string;  // present if this is a response to a specific request
  payload: {
    code: ErrorCode;
    message: string;
    details?: unknown;
  };
}

// --- Union type ---

export type PluginMessage =
  // Version 1
  | HelloMessage
  | OutputMessage
  | ScriptCompleteMessage
  // Version 2
  | RegisterMessage
  | StateResultMessage
  | ScreenshotResultMessage
  | DataModelResultMessage
  | LogsResultMessage
  | StateChangeMessage
  | LogPushMessage
  | HeartbeatMessage
  | SubscribeResultMessage
  | UnsubscribeResultMessage
  | PluginErrorMessage;

// ===========================================================================
// Server -> Plugin messages
// ===========================================================================

// --- Version 1 (preserved) ---

export interface WelcomeMessage extends PushMessage {
  type: 'welcome';
  // sessionId (from PushMessage/BaseMessage) is the authoritative session ID.
  // Confirms the plugin's proposed ID, or overrides it if there was a collision.
  payload: {
    sessionId: string;              // same as envelope sessionId (for backward compat)
    capabilities?: Capability[];
    serverVersion?: string;
  };
}

export interface ExecuteMessage extends BaseMessage {
  type: 'execute';
  requestId?: string;  // present in v2 for correlation, absent in v1
  payload: {
    script: string;
  };
}

export interface ShutdownMessage extends PushMessage {
  type: 'shutdown';
  payload: Record<string, never>;
}

// --- Version 2 (new) ---

export interface QueryStateMessage extends RequestMessage {
  type: 'queryState';
  payload: {};
}

export interface CaptureScreenshotMessage extends RequestMessage {
  type: 'captureScreenshot';
  payload: {
    format?: 'png';
  };
}

export interface QueryDataModelMessage extends RequestMessage {
  type: 'queryDataModel';
  payload: {
    path: string;
    depth?: number;
    properties?: string[];
    includeAttributes?: boolean;
    find?: {
      name: string;
      recursive?: boolean;
    };
    listServices?: boolean;
  };
}

export interface QueryLogsMessage extends RequestMessage {
  type: 'queryLogs';
  payload: {
    count?: number;
    direction?: 'head' | 'tail';
    levels?: OutputLevel[];
    includeInternal?: boolean;
  };
}

export interface SubscribeMessage extends RequestMessage {
  type: 'subscribe';
  payload: {
    events: SubscribableEvent[];
  };
}

export interface UnsubscribeMessage extends RequestMessage {
  type: 'unsubscribe';
  payload: {
    events: SubscribableEvent[];
  };
}

export interface ServerErrorMessage extends BaseMessage {
  type: 'error';
  requestId?: string;  // present if this is a response to a specific request
  payload: {
    code: ErrorCode;
    message: string;
    details?: unknown;
  };
}

// --- Union type ---

export type ServerMessage =
  // Version 1
  | WelcomeMessage
  | ExecuteMessage
  | ShutdownMessage
  // Version 2
  | QueryStateMessage
  | CaptureScreenshotMessage
  | QueryDataModelMessage
  | QueryLogsMessage
  | SubscribeMessage
  | UnsubscribeMessage
  | ServerErrorMessage;

// ===========================================================================
// Encode / decode function signatures
// ===========================================================================

/**
 * Encode a server message to a JSON string for transmission.
 * Handles both v1 and v2 message types.
 */
export function encodeMessage(msg: ServerMessage): string;

/**
 * Decode a raw JSON string from the plugin into a typed PluginMessage.
 * Returns null if the message is malformed or has an unrecognized type.
 *
 * Version 2 behavior: unknown message types return null (not an error).
 * The caller decides whether to log or ignore unknown types.
 */
export function decodePluginMessage(raw: string): PluginMessage | null;

/**
 * NEW: Decode a raw JSON string from the server into a typed ServerMessage.
 * Used by test code and by the split-server CLI client.
 * Returns null if the message is malformed.
 */
export function decodeServerMessage(raw: string): ServerMessage | null;
```

## 9. Backward Compatibility Matrix

### 9.1 Old plugin (v1) connecting to new server (v2)

| Aspect | Behavior |
|--------|----------|
| Handshake | Plugin sends `hello` without `protocolVersion`. Server detects v1, responds with v1-style `welcome` (no `capabilities`, no `protocolVersion`). |
| Execute | Server sends `execute`, plugin responds with `output` + `scriptComplete`. No `requestId` on any message. Works identically to today. |
| Queries | Server never sends `queryState`, `captureScreenshot`, etc. The server knows the plugin has no extended capabilities. |
| Shutdown | Unchanged. |
| Unknown messages | If the server accidentally sends a v2 message, the plugin's `MessageReceived` handler has a default case that ignores unknown types. No crash. |

### 9.2 New plugin (v2) connecting to old server (v1)

| Aspect | Behavior |
|--------|----------|
| Handshake | Plugin sends `hello` with `protocolVersion: 2` and `capabilities`. Old server ignores the extra fields (they are in `payload`, which the server does not validate beyond `sessionId`). Server responds with v1 `welcome`. |
| Detecting v1 server | Plugin checks the `welcome` response for `protocolVersion`. If absent, plugin knows it is v1 and disables extended features. |
| Execute | Plugin handles `execute` as before, responds with `output` + `scriptComplete`. |
| Heartbeat | Plugin may still send `heartbeat` messages. Old server's `decodePluginMessage` returns `null` for unknown types and ignores them. No crash. |
| Register | If plugin initially sends `register` (persistent mode, with a plugin-generated UUID as `sessionId`) and gets no response within 3 seconds, it falls back to `hello`. |

### 9.3 Mixed version flow

```
New Plugin                        Old Server (v1)
    |                                   |
    |-- register (v2, plugin-generated  |
    |   sessionId) -------------------->|
    |                                   | (decodePluginMessage returns null, ignored)
    |         (3 second timeout)        |
    |-- hello (v1 fallback) ----------->|
    |                                   |
    |<-------------- welcome (v1) ------|
    |                                   |
    | (plugin detects v1, disables      |
    |  extended features, uses          |
    |  welcome.sessionId going forward) |
```

```
Old Plugin (v1)                   New Server (v2)
    |                                   |
    |-- hello (no version) ------------>|
    |                                   | (server detects v1)
    |<-------------- welcome (v1) ------|
    |                                   |
    | (server marks connection as v1,   |
    |  only sends execute/shutdown)     |
```

## 10. Wire Protocol Examples

### 10.1 Full v2 session lifecycle

```
Plugin → Server (plugin generates UUID "a1b2c3" as proposed sessionId):
{
  "type": "register",
  "sessionId": "a1b2c3",
  "protocolVersion": 2,
  "payload": {
    "pluginVersion": "1.0.0",
    "instanceId": "inst-xyz",
    "context": "edit",
    "placeName": "TestPlace",
    "placeId": 1234567890,
    "gameId": 9876543210,
    "placeFile": "/Users/dev/game/TestPlace.rbxl",
    "state": "Edit",
    "pid": 12345,
    "capabilities": ["execute", "queryState", "captureScreenshot", "queryDataModel", "queryLogs", "subscribe", "heartbeat"]
  }
}

Server → Plugin (server accepts "a1b2c3" -- no collision):
{
  "type": "welcome",
  "sessionId": "a1b2c3",
  "protocolVersion": 2,
  "payload": {
    "sessionId": "a1b2c3",
    "capabilities": ["execute", "queryState", "captureScreenshot", "queryDataModel", "queryLogs", "subscribe"],
    "serverVersion": "0.5.0"
  }
}

Server → Plugin:
{
  "type": "subscribe",
  "sessionId": "a1b2c3",
  "requestId": "sub-001",
  "payload": { "events": ["stateChange", "logPush"] }
}

Plugin → Server:
{
  "type": "subscribeResult",
  "sessionId": "a1b2c3",
  "requestId": "sub-001",
  "payload": { "events": ["stateChange", "logPush"] }
}

Server → Plugin:
{
  "type": "queryState",
  "sessionId": "a1b2c3",
  "requestId": "req-001",
  "payload": {}
}

Plugin → Server:
{
  "type": "stateResult",
  "sessionId": "a1b2c3",
  "requestId": "req-001",
  "payload": {
    "state": "Edit",
    "placeId": 1234567890,
    "placeName": "TestPlace",
    "gameId": 9876543210
  }
}

Server → Plugin:
{
  "type": "execute",
  "sessionId": "a1b2c3",
  "requestId": "req-002",
  "payload": { "script": "print('Hello from persistent session')" }
}

Plugin → Server:
{
  "type": "output",
  "sessionId": "a1b2c3",
  "payload": {
    "messages": [{ "level": "Print", "body": "Hello from persistent session" }]
  }
}

Plugin → Server:
{
  "type": "scriptComplete",
  "sessionId": "a1b2c3",
  "requestId": "req-002",
  "payload": { "success": true }
}

Plugin → Server:
{
  "type": "heartbeat",
  "sessionId": "a1b2c3",
  "payload": { "uptimeMs": 45000, "state": "Edit", "pendingRequests": 0 }
}

Plugin → Server:
{
  "type": "stateChange",
  "sessionId": "a1b2c3",
  "payload": { "previousState": "Edit", "newState": "Play", "timestamp": 47230 }
}

Server → Plugin:
{
  "type": "queryDataModel",
  "sessionId": "a1b2c3",
  "requestId": "req-003",
  "payload": {
    "path": "game.Workspace.SpawnLocation",
    "depth": 0,
    "properties": ["Position", "Anchored", "Size"],
    "includeAttributes": false
  }
}

Plugin → Server:
{
  "type": "dataModelResult",
  "sessionId": "a1b2c3",
  "requestId": "req-003",
  "payload": {
    "instance": {
      "name": "SpawnLocation",
      "className": "SpawnLocation",
      "path": "game.Workspace.SpawnLocation",
      "properties": {
        "Position": { "type": "Vector3", "value": [0, 4, 0] },
        "Anchored": true,
        "Size": { "type": "Vector3", "value": [8, 1, 8] }
      },
      "attributes": {},
      "childCount": 0
    }
  }
}

Server → Plugin:
{
  "type": "captureScreenshot",
  "sessionId": "a1b2c3",
  "requestId": "req-004",
  "payload": {}
}

Plugin → Server:
{
  "type": "screenshotResult",
  "sessionId": "a1b2c3",
  "requestId": "req-004",
  "payload": {
    "data": "iVBORw0KGgoAAAANSUhEUgAA...",
    "format": "png",
    "width": 1920,
    "height": 1080
  }
}

Server → Plugin:
{
  "type": "shutdown",
  "sessionId": "a1b2c3",
  "payload": {}
}
```

### 10.2 Error response example

```
Server → Plugin:
{
  "type": "queryDataModel",
  "sessionId": "a1b2c3",
  "requestId": "req-005",
  "payload": {
    "path": "game.Workspace.NonExistentPart",
    "depth": 0,
    "properties": ["Position"]
  }
}

Plugin → Server:
{
  "type": "error",
  "sessionId": "a1b2c3",
  "requestId": "req-005",
  "payload": {
    "code": "INSTANCE_NOT_FOUND",
    "message": "No instance found at path: game.Workspace.NonExistentPart",
    "details": {
      "resolvedTo": "game.Workspace",
      "failedSegment": "NonExistentPart"
    }
  }
}
```

### 10.3 Concurrent requests example

```
Server → Plugin:  (queryState, req-010)
Server → Plugin:  (execute, req-011)
Server → Plugin:  (queryLogs, req-012)

Plugin → Server:  (stateResult, req-010)     // fast query returns first
Plugin → Server:  (logsResult, req-012)       // buffer read returns second
Plugin → Server:  (output, no requestId)      // script output streams
Plugin → Server:  (output, no requestId)      // more output
Plugin → Server:  (scriptComplete, req-011)   // script finishes last
```

### 10.4 Multi-context Play mode example

When the user presses Play in Studio, 2 new plugin instances (server and client) connect independently, joining the already-connected edit instance. All share the same `instanceId` but report different `context` and `state` values.

```
Edit context plugin → Server (already connected):
{
  "type": "register",
  "sessionId": "edit-001",
  "protocolVersion": 2,
  "payload": {
    "pluginVersion": "1.0.0",
    "instanceId": "inst-xyz",
    "context": "edit",
    "placeName": "TestPlace",
    "placeId": 1234567890,
    "gameId": 9876543210,
    "placeFile": "/Users/dev/game/TestPlace.rbxl",
    "state": "Edit",
    "pid": 12345,
    "capabilities": ["execute", "queryState", "queryDataModel", "queryLogs", "subscribe", "heartbeat"]
  }
}

Server context plugin → Server (new connection on Play):
{
  "type": "register",
  "sessionId": "server-001",
  "protocolVersion": 2,
  "payload": {
    "pluginVersion": "1.0.0",
    "instanceId": "inst-xyz",
    "context": "server",
    "placeName": "TestPlace",
    "placeId": 1234567890,
    "gameId": 9876543210,
    "state": "Run",
    "pid": 12345,
    "capabilities": ["execute", "queryState", "queryDataModel", "queryLogs", "subscribe", "heartbeat"]
  }
}

Client context plugin → Server (new connection on Play):
{
  "type": "register",
  "sessionId": "client-001",
  "protocolVersion": 2,
  "payload": {
    "pluginVersion": "1.0.0",
    "instanceId": "inst-xyz",
    "context": "client",
    "placeName": "TestPlace",
    "placeId": 1234567890,
    "gameId": 9876543210,
    "state": "Play",
    "pid": 12345,
    "capabilities": ["execute", "queryState", "captureScreenshot", "queryDataModel", "queryLogs", "subscribe", "heartbeat"]
  }
}
```

The server responds with a `welcome` to each, confirming (or overriding) the plugin-generated `sessionId`. Note:
- Each plugin context generates its own UUID as the proposed `sessionId` (e.g., `"edit-001"`, `"server-001"`, `"client-001"`). The server accepts these unless there is a collision, in which case it overrides with a new UUID in the `welcome` response.
- All three share `instanceId: "inst-xyz"` -- the server uses this to group them as belonging to the same Studio.
- Each has a different `sessionId` and `context`.
- The Edit context remains in `state: "Edit"`. The Server context is `state: "Run"`. The Client context is `state: "Play"`.
- The Client context may advertise `captureScreenshot` since it has the 3D viewport.

When the user stops Play mode, the Server and Client contexts disconnect (their WebSockets close). The Edit context remains connected and may send a `stateChange` if its state is affected.

## 11. Decoder Implementation Notes

### 11.1 Updating `decodePluginMessage`

The existing `decodePluginMessage` function uses a `switch` on `type` and returns `null` for unknown types. This is already forward-compatible -- unknown v2 message types sent to a v1 server are safely ignored.

For the v2 server, the switch gains new cases:

```typescript
case 'register':
  // validate payload.pluginVersion, payload.instanceId, payload.context, payload.placeId, payload.gameId, payload.capabilities, etc.
  return { type: 'register', sessionId, protocolVersion, requestId, payload: { ... } };

case 'stateResult':
  // validate requestId present, payload.state is valid StudioState, etc.
  return { type: 'stateResult', sessionId, requestId, payload: { ... } };

// ... additional cases for each new PluginMessage type
```

### 11.2 Validation strategy

Each message type validates its own payload fields strictly. If a required field is missing or has the wrong type, `decodePluginMessage` returns `null`. This matches the existing behavior and prevents malformed messages from propagating.

Optional fields (`requestId`, `protocolVersion`, new optional payload fields) are extracted if present and omitted if absent. The TypeScript types use `?` to reflect this.

### 11.3 `decodeServerMessage` (new)

A symmetric function for decoding server messages, used by:
- Test code that simulates a plugin client
- The split-server CLI client that receives forwarded server messages
- Any future tooling that needs to parse server-side messages

The implementation mirrors `decodePluginMessage` with a switch over server message types.

## 12. Relationship to Action System

The `00-overview.md` tech spec describes a generic action envelope (`ActionRequest` / `ActionResponse`) as an alternative framing for the protocol extensions. This document takes a different approach: each operation has its own named message type (`queryState` / `stateResult`, `captureScreenshot` / `screenshotResult`, etc.).

The rationale: named message types are more explicit, produce better TypeScript unions (discriminated on `type`), and are easier to validate per-message. The generic action envelope is useful as a conceptual model but adds a level of indirection that complicates the type system without providing meaningful extensibility benefits -- adding a new operation requires defining types either way.

If a future extension needs a truly generic action dispatch (e.g., user-defined plugin actions), it can be added as a single new message type (`customAction` / `customActionResult`) without retrofitting the existing named types.

## 13. WebSocket Configuration

### 13.1 Frame size limits

The server must configure the WebSocket to accept frames up to 16MB to accommodate screenshot payloads. The `ws` library's `maxPayload` option:

```typescript
new WebSocketServer({ port: 0, path: `/${sessionId}`, maxPayload: 16 * 1024 * 1024 });
```

### 13.2 Compression

WebSocket per-message compression (`permessage-deflate`) should be enabled for connections that negotiate v2, as screenshot and DataModel payloads benefit significantly. The `ws` library supports this natively:

```typescript
new WebSocketServer({
  port: 0,
  path: `/${sessionId}`,
  maxPayload: 16 * 1024 * 1024,
  perMessageDeflate: true,
});
```

This is negotiated at the WebSocket level and is transparent to the JSON protocol.

### 13.3 Heartbeat and idle timeout

The server should configure a WebSocket-level ping/pong alongside the application-level heartbeat:

- WebSocket ping: every 30 seconds (handled by `ws` library)
- Application heartbeat: every 15 seconds (sent by plugin)
- Stale detection: 45 seconds (3 missed heartbeats) with no heartbeat → mark session as stale
- Disconnect: 60 seconds (4 missed heartbeats) → remove session, emit `session-disconnected`

See the Heartbeat Protocol section in 5.3 for the full specification. The application heartbeat carries state information that WebSocket pings do not, which is why both are needed.
