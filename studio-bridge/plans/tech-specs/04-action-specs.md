# Action Specifications

This document specifies each studio-bridge action end-to-end: CLI surface, terminal dot-command, MCP tool, wire protocol, server handler, plugin handler, error cases, and timeout. It is the companion to `01-protocol.md` (which defines the message types) and `00-overview.md` (which defines the architecture).

References:
- PRD: `../prd/main.md` (features F1-F7)
- Tech spec: `00-overview.md` (component map, server modes)
- Protocol: `01-protocol.md` (message types, error codes, timeouts)

---

## 1. sessions -- List running sessions

**Summary**: Enumerate all Studio sessions that have a connected (or recently connected) persistent plugin.

### CLI

**Command**: `studio-bridge sessions`

| Flag | Alias | Type | Default | Description |
|------|-------|------|---------|-------------|
| `--json` | | boolean | `false` | Output as JSON array |
| `--watch` | | boolean | `false` | Continuously update the session list |

**Example** (single Studio instance in Edit mode):

```
$ studio-bridge sessions
  SESSION ID                             PLACE              CONTEXT  STATE    PLACE ID      ORIGIN     CONNECTED
  a1b2c3d4-e5f6-7890-abcd-ef1234567890  TestPlace.rbxl     Edit     Edit     1234567890    user       2m 30s

1 session connected.
```

**Example** (single Studio instance in Play mode -- 3 sessions, grouped by instance):

```
$ studio-bridge sessions
  Instance: TestPlace.rbxl (inst-001)

  SESSION ID                             PLACE              CONTEXT  STATE    PLACE ID      ORIGIN     CONNECTED
  a1b2c3d4-e5f6-7890-abcd-ef1234567890  TestPlace.rbxl     Edit     Play     1234567890    user       15m 42s
  b2c3d4e5-f6a7-8901-bcde-f12345678901  TestPlace.rbxl     Server   Play     1234567890    user       15m 40s
  c3d4e5f6-a7b8-9012-cdef-123456789012  TestPlace.rbxl     Client   Play     1234567890    user       15m 40s

3 sessions connected (1 instance).
```

**Example** (multiple Studio instances):

```
$ studio-bridge sessions
  Instance: TestPlace.rbxl (inst-001)

  SESSION ID                             PLACE              CONTEXT  STATE    PLACE ID      ORIGIN     CONNECTED
  a1b2c3d4-e5f6-7890-abcd-ef1234567890  TestPlace.rbxl     Edit     Edit     1234567890    user       2m 30s

  Instance: MyGame.rbxl (inst-002)

  SESSION ID                             PLACE              CONTEXT  STATE    PLACE ID      ORIGIN     CONNECTED
  f9e8d7c6-b5a4-3210-fedc-ba0987654321  MyGame.rbxl        Edit     Play     9876543210    managed    15m 42s
  e8d7c6b5-a432-10fe-dcba-098765432101  MyGame.rbxl        Server   Play     9876543210    managed    15m 40s
  d7c6b5a4-3210-fedc-ba09-876543210123  MyGame.rbxl        Client   Play     9876543210    managed    15m 40s

4 sessions connected (2 instances).
```

```
$ studio-bridge sessions --json
[
  {
    "sessionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "placeName": "TestPlace.rbxl",
    "context": "Edit",
    "state": "Edit",
    "instanceId": "inst-001",
    "placeId": 1234567890,
    "gameId": 9876543210,
    "origin": "user",
    "uptimeMs": 150000
  }
]
```

When no sessions exist:
```
$ studio-bridge sessions
No active sessions. Is Studio running with the studio-bridge plugin installed?
```

### Terminal

**Dot-command**: `.sessions`

No arguments. Prints the same table as the CLI (minus the `--json` and `--watch` flags).

### MCP

**Tool name**: `studio_sessions`

**Input schema**:
```typescript
{} // no parameters
```

**Output schema**:
```typescript
type SessionContext = 'edit' | 'client' | 'server';

interface SessionsResult {
  sessions: Array<{
    sessionId: string;
    placeName: string;
    placeFile?: string;
    context: SessionContext;
    state: StudioState;
    instanceId: string;
    placeId: number;
    gameId: number;
    origin: SessionOrigin;
    uptimeMs: number;
  }>;
}
```

### Protocol

No wire protocol message. The session list is read from the bridge host's in-memory session tracking. The server does not need to ask the plugin for this information.

### Server handler

Calls `BridgeConnection.listSessionsAsync()`. Formats the result for the requested output mode (table, JSON, or MCP response).

### Plugin handler

None. The plugin does not participate in session listing -- session tracking is bridge host state.

### Error cases

| Condition | Message |
|-----------|---------|
| No bridge host running | `No bridge host running. Start one with 'studio-bridge terminal' or 'studio-bridge exec'.` |
| Bridge host running but no plugins connected | `No active sessions. Is Studio running with the studio-bridge plugin installed?` |

### Timeout

Not applicable (in-memory lookup).

### Return type

```typescript
type SessionContext = 'edit' | 'client' | 'server';

interface SessionInfo {
  sessionId: string;
  placeFile?: string;
  placeName: string;
  context: SessionContext;
  instanceId: string;
  placeId: number;
  gameId: number;
  origin: SessionOrigin;  // 'user' | 'managed'
  connectedAt: string;    // ISO 8601 -- serialized from the Date in the public API.
                          // The wire protocol carries this as a millisecond timestamp (number);
                          // the server converts to Date, and CLI/JSON output serializes as ISO 8601.
  state: string;
}
```

A single Studio instance produces 1-3 sessions that share the same `instanceId`. In Edit mode, there is one session with `context: 'edit'`. When the user enters Play mode, the instance produces up to two additional sessions: `context: 'server'` and `context: 'client'`. All sessions from the same instance share the same `instanceId`, `placeId`, and `gameId`.

---

## 2. connect -- Connect to existing session

**Summary**: Attach an interactive terminal REPL to a running Studio session. This is an alias for `studio-bridge terminal --session <id>` with intent-clarifying semantics.

### CLI

**Command**: `studio-bridge connect <session-id>`

| Positional | Type | Required | Description |
|------------|------|----------|-------------|
| `session-id` | string | yes | Session ID to connect to |

No additional flags beyond the global args (`--verbose`, `--timeout`). Once connected, the user enters terminal mode with all dot-commands available.

**Example**:

```
$ studio-bridge connect a1b2c3d4-e5f6-7890-abcd-ef1234567890
Connected to TestPlace.rbxl (Edit mode)
Type .help for commands, .exit to disconnect.

>
```

### Terminal

**Dot-command**: `.connect <session-id>`

Switches the current terminal session to a different Studio session. The previous session is disconnected (not killed).

```
> .connect f9e8d7c6-b5a4-3210-fedc-ba0987654321
Disconnected from TestPlace.rbxl
Connected to MyGame.rbxl (Play mode)
```

### MCP

No dedicated MCP tool. Session targeting is handled by the `sessionId` parameter on each individual tool.

### Protocol

No new protocol message. Connection uses the existing WebSocket handshake (`hello`/`welcome` or `register`/`welcome`).

### Server handler

Looks up the session by ID via `BridgeConnection.getSession(sessionId)`. If found, enters terminal mode attached to that session.

### Plugin handler

None beyond the standard handshake. The plugin is already connected to the server; the CLI is connecting to the server, not directly to the plugin.

### Error cases

| Condition | Message |
|-----------|---------|
| Session ID not found | `Session not found: {sessionId}. Run 'studio-bridge sessions' to see available sessions.` |
| Session exists but plugin is disconnected | `Session {sessionId} exists but the plugin is not connected. Studio may have been closed.` |
| WebSocket connection refused | `Cannot connect to session {sessionId}. The bridge host may have crashed.` |

### Timeout

Inherits the global `--timeout` (default: 30000ms) for the initial WebSocket handshake.

### Return type

No structured return. Enters interactive mode.

---

## 3. state -- Query Studio state

**Summary**: Get the current run mode, place name, place ID, and game ID of a Studio session.

### CLI

**Command**: `studio-bridge state [session-id]`

| Flag | Alias | Type | Default | Description |
|------|-------|------|---------|-------------|
| `--session` | `-s` | string | (auto) | Target session ID |
| `--json` | | boolean | `false` | Output as JSON |
| `--watch` | | boolean | `false` | Subscribe to state changes and print updates |

**Example**:

```
$ studio-bridge state
Place:    TestPlace
PlaceId:  1234567890
GameId:   9876543210
Mode:     Edit
```

```
$ studio-bridge state --json
{
  "state": "Edit",
  "placeName": "TestPlace",
  "placeId": 1234567890,
  "gameId": 9876543210
}
```

```
$ studio-bridge state --watch
[14:30:22] Mode: Edit
[14:30:45] Mode: Play
[14:31:02] Mode: Paused
^C
```

### Terminal

**Dot-command**: `.state`

No arguments. Prints the state in the same format as the CLI default (human-readable).

```
> .state
Place:    TestPlace
PlaceId:  1234567890
GameId:   9876543210
Mode:     Edit
```

### MCP

**Tool name**: `studio_state`

**Input schema**:
```typescript
interface StudioStateInput {
  sessionId?: string;
}
```

**Output schema**:
```typescript
interface StudioStateOutput {
  state: StudioState;    // 'Edit' | 'Play' | 'Paused' | 'Run' | 'Server' | 'Client'
  placeName: string;
  placeId: number;       // 0 if unpublished
  gameId: number;        // 0 if unpublished
}
```

### Protocol

**Request**: `queryState` (server to plugin)
```json
{ "type": "queryState", "sessionId": "...", "requestId": "req-001", "payload": {} }
```

**Response**: `stateResult` (plugin to server)
```json
{
  "type": "stateResult", "sessionId": "...", "requestId": "req-001",
  "payload": { "state": "Edit", "placeId": 1234567890, "placeName": "TestPlace", "gameId": 9876543210 }
}
```

For `--watch` mode, the server sends a `subscribe { events: ['stateChange'] }` message to the plugin via WebSocket push. The plugin confirms with `subscribeResult` and then pushes `stateChange` messages on each Studio state transition (Edit <-> Play <-> Pause). These push messages are forwarded by the bridge host to all subscribed clients. When the user interrupts (Ctrl+C), the server sends `unsubscribe { events: ['stateChange'] }` to stop the push stream. See `01-protocol.md` section 5.2 for the full subscribe/unsubscribe protocol and `07-bridge-network.md` section 5.3 for the host subscription routing mechanism.

### Server handler

File: `src/server/actions/query-state.ts`

1. Calls `performActionAsync` with a `queryState` message.
2. Awaits the `stateResult` response.
3. Formats the payload for the requested output mode.
4. For `--watch`: sends `subscribe { events: ['stateChange'] }` to the plugin via WebSocket push. The plugin confirms with `subscribeResult`, then pushes `stateChange` messages on each Studio state transition. These are forwarded by the bridge host to the subscribed client (see `07-bridge-network.md` section 5.3). The CLI prints each transition until the user interrupts with Ctrl+C, at which point it sends `unsubscribe { events: ['stateChange'] }`.

### Plugin handler

File: `templates/studio-bridge-plugin/src/Actions/StateAction.lua`

1. Reads `RunService:IsEdit()`, `RunService:IsRunMode()`, `RunService:IsClient()`, `RunService:IsServer()`, `RunService:IsRunning()` to determine `StudioState`.
2. Reads `game.PlaceId`, `game.Name`, `game.GameId`.
3. Sends `stateResult` with the gathered data.

### Error cases

| Condition | Error code | Message |
|-----------|-----------|---------|
| Plugin does not support `queryState` | `CAPABILITY_NOT_SUPPORTED` | `This Studio session does not support state queries. Update the studio-bridge plugin.` |
| Plugin did not respond in time | `TIMEOUT` | `State query timed out after 5 seconds.` |
| No sessions available | (CLI-level) | `No active sessions. Is Studio running with the studio-bridge plugin installed?` |

### Timeout

5 seconds (per 01-protocol.md).

### Retry safety

**Safe to retry.** `queryState` is a read-only query with no side effects. Retrying after a timeout or transient error is always safe.

### Return type

```typescript
interface StateResult {
  state: StudioState;
  placeName: string;
  placeId: number;
  gameId: number;
}
```

---

## 4. screenshot -- Capture viewport

**Summary**: Capture a PNG screenshot of the Studio 3D viewport.

### CLI

**Command**: `studio-bridge screenshot [session-id]`

| Flag | Alias | Type | Default | Description |
|------|-------|------|---------|-------------|
| `--session` | `-s` | string | (auto) | Target session ID |
| `--output` | `-o` | string | (temp dir) | Output file path |
| `--open` | | boolean | `false` | Open the image in the default viewer after capture |
| `--base64` | | boolean | `false` | Print base64-encoded PNG to stdout instead of writing a file |

**Example**:

```
$ studio-bridge screenshot
Screenshot saved to /tmp/studio-bridge/screenshot-2026-02-20-143022.png
```

```
$ studio-bridge screenshot -o ./capture.png
Screenshot saved to ./capture.png
```

```
$ studio-bridge screenshot --base64
iVBORw0KGgoAAAANSUhEUgAA...
```

### Terminal

**Dot-command**: `.screenshot [path]`

Optional path argument. If omitted, writes to the temp directory and prints the path.

```
> .screenshot
Screenshot saved to /tmp/studio-bridge/screenshot-2026-02-20-143055.png

> .screenshot ./my-capture.png
Screenshot saved to ./my-capture.png
```

### MCP

**Tool name**: `studio_screenshot`

**Input schema**:
```typescript
interface StudioScreenshotInput {
  sessionId?: string;
}
```

**Output schema**:
```typescript
interface StudioScreenshotOutput {
  data: string;      // base64-encoded PNG
  format: 'png';
  width: number;
  height: number;
}
```

MCP always returns base64 data inline (not a file path) so agents can process the image directly.

### Protocol

**Request**: `captureScreenshot` (server to plugin)
```json
{ "type": "captureScreenshot", "sessionId": "...", "requestId": "req-002", "payload": {} }
```

**Response**: `screenshotResult` (plugin to server)
```json
{
  "type": "screenshotResult", "sessionId": "...", "requestId": "req-002",
  "payload": { "data": "iVBORw0KGgoAAAANSUhEUgAA...", "format": "png", "width": 1920, "height": 1080 }
}
```

### Server handler

File: `src/server/actions/capture-screenshot.ts`

1. Calls `performActionAsync` with a `captureScreenshot` message.
2. Awaits the `screenshotResult` response.
3. For CLI default mode: decodes the base64 data, writes to a temp file (`/tmp/studio-bridge/screenshot-{timestamp}.png`), prints the path.
4. For `--output`: writes to the specified path.
5. For `--base64`: prints raw base64 to stdout.
6. For `--open`: after writing the file, spawns `open` (macOS) or `xdg-open` (Linux) with the file path.
7. For MCP: returns the raw `screenshotResult` payload.

### Plugin handler

File: `templates/studio-bridge-plugin/src/Actions/ScreenshotAction.lua`

The confirmed API call chain for capturing a screenshot and extracting image bytes:

1. Call `CaptureService:CaptureScreenshot(function(contentId) ... end)`. The callback receives a `contentId` string (a temporary content URL pointing to the captured image).
2. Inside the callback, load the `contentId` into an `EditableImage` via `AssetService:CreateEditableImageAsync(contentId)` (or equivalent `EditableImage` constructor that accepts a content ID). **Note for implementer**: verify the exact method name against the Roblox API at implementation time, as the `EditableImage` API may use a different constructor or factory method.
3. Read the raw pixel bytes from the `EditableImage` (e.g., `editableImage:ReadPixels(Vector2.new(0, 0), editableImage.Size)`). **Note for implementer**: verify the exact method name (`ReadPixels`, `GetPixels`, or similar) and return type against the Roblox API at implementation time.
4. Base64-encode the pixel/image bytes.
5. Read the image dimensions from `editableImage.Size` (a `Vector2` with width and height).
6. Send the `screenshotResult` message over the WebSocket with the base64-encoded data, format, width, and height.

### Error cases

| Condition | Error code | Message |
|-----------|-----------|---------|
| `CaptureService:CaptureScreenshot()` call fails | `SCREENSHOT_FAILED` | `Screenshot capture failed: {error detail}` |
| `EditableImage` creation or pixel read fails | `SCREENSHOT_FAILED` | `Screenshot capture failed: could not read image data: {error detail}` |
| Viewport not available (Studio minimized) | `SCREENSHOT_FAILED` | `Cannot capture screenshot: viewport is not available. Is Studio minimized?` |
| Plugin does not support screenshots | `CAPABILITY_NOT_SUPPORTED` | `This Studio session does not support screenshots. Update the studio-bridge plugin.` |
| Timeout | `TIMEOUT` | `Screenshot capture timed out after 15 seconds.` |
| Output path not writable | (CLI-level) | `Cannot write screenshot to {path}: {os error}` |

### Timeout

15 seconds (per 01-protocol.md).

### Retry safety

**Safe to retry.** `captureScreenshot` is a read-only capture with no side effects. Retrying after a timeout or transient error is always safe, though the viewport contents may differ between attempts.

### Return type

```typescript
interface ScreenshotResult {
  data: string;      // base64-encoded PNG
  format: 'png';
  width: number;
  height: number;
}
```

---

## 5. logs -- Retrieve/follow output logs

**Summary**: Retrieve buffered output log lines from a Studio session, or stream new lines in real time.

### CLI

**Command**: `studio-bridge logs [session-id]`

| Flag | Alias | Type | Default | Description |
|------|-------|------|---------|-------------|
| `--session` | `-s` | string | (auto) | Target session ID |
| `--tail` | | number | `50` | Show last N lines |
| `--head` | | number | | Show first N lines since plugin connected |
| `--follow` | `-f` | boolean | `false` | Stream new output in real time |
| `--level` | | string | (all) | Comma-separated level filter: `Print`, `Info`, `Warning`, `Error` |
| `--all` | | boolean | `false` | Include internal `[StudioBridge]` messages |
| `--json` | | boolean | `false` | Output each line as a JSON object |

`--tail` and `--head` are mutually exclusive. If neither is provided, `--tail 50` is the default. `--follow` can be combined with `--level` and `--all` but not with `--head` or `--tail`.

**Example**:

```
$ studio-bridge logs
14:30:01 [Print]   Hello from script
14:30:01 [Print]   Player count: 0
14:30:02 [Warning] Infinite yield possible on 'Players:WaitForChild("LocalPlayer")'
```

```
$ studio-bridge logs --tail 100 --level Error,Warning
14:30:02 [Warning] Infinite yield possible on 'Players:WaitForChild("LocalPlayer")'
14:31:15 [Error]   Script 'Workspace.Script': attempt to index nil with 'Name'
```

```
$ studio-bridge logs --follow
(streaming, Ctrl+C to stop)
14:30:01 [Print]   Hello from script
14:30:05 [Print]   Tick
14:30:06 [Print]   Tick
^C
```

```
$ studio-bridge logs --json --tail 2
[
  { "timestamp": 12340, "level": "Print", "body": "Hello from script" },
  { "timestamp": 12341, "level": "Print", "body": "Player count: 0" }
]
```

### Terminal

**Dot-command**: `.logs [--tail N | --head N | --follow]`

Accepts the same flags as the CLI in a simplified form.

```
> .logs
(last 50 lines)

> .logs --tail 10
(last 10 lines)

> .logs --follow
(streaming, press Enter to stop)
```

### MCP

**Tool name**: `studio_logs`

**Input schema**:
```typescript
interface StudioLogsInput {
  sessionId?: string;
  count?: number;           // default: 50
  direction?: 'head' | 'tail';  // default: 'tail'
  levels?: string[];        // e.g. ['Error', 'Warning']
  includeInternal?: boolean; // default: false
}
```

**Output schema**:
```typescript
interface StudioLogsOutput {
  entries: Array<{
    level: OutputLevel;
    body: string;
    timestamp: number;
  }>;
  total: number;
  bufferCapacity: number;
}
```

MCP does not support follow mode. It returns a snapshot of the log buffer per invocation.

### Protocol

**Request**: `queryLogs` (server to plugin)
```json
{
  "type": "queryLogs", "sessionId": "...", "requestId": "req-003",
  "payload": { "count": 50, "direction": "tail", "levels": ["Print", "Warning", "Error"], "includeInternal": false }
}
```

**Response**: `logsResult` (plugin to server)
```json
{
  "type": "logsResult", "sessionId": "...", "requestId": "req-003",
  "payload": {
    "entries": [
      { "level": "Print", "body": "Hello from script", "timestamp": 12340 },
      { "level": "Warning", "body": "Infinite yield possible", "timestamp": 12345 }
    ],
    "total": 847,
    "bufferCapacity": 1000
  }
}
```

For `--follow` mode: the server sends `subscribe { events: ['logPush'] }` to the plugin via WebSocket push. The plugin confirms with `subscribeResult` and then pushes individual `logPush` messages for each new LogService entry as it occurs. Each `logPush` message contains a single `{ level, body, timestamp }` entry. These push messages are forwarded by the bridge host to all subscribed clients (see `07-bridge-network.md` section 5.3 for the host subscription routing mechanism). The CLI streams these entries to stdout, applying level and internal-message filters. On Ctrl+C (SIGINT), the server sends `unsubscribe { events: ['logPush'] }` to stop the push stream. Note: `logPush` is distinct from `output` -- `output` messages are batched and scoped to a single `execute` request, while `logPush` streams individual entries continuously from all sources. See `01-protocol.md` section 5.2 for the full subscribe/unsubscribe protocol.

### Server handler

File: `src/server/actions/query-logs.ts`

1. Translates CLI flags to a `queryLogs` payload:
   - `--tail N` maps to `{ count: N, direction: 'tail' }`.
   - `--head N` maps to `{ count: N, direction: 'head' }`.
   - `--level X,Y` maps to `{ levels: ['X', 'Y'] }`.
   - `--all` maps to `{ includeInternal: true }`.
2. Calls `performActionAsync` with the `queryLogs` message.
3. Awaits the `logsResult` response.
4. Formats entries for display: `{timestamp} [{level}] {body}` or JSON objects.
5. For `--follow`: sends `subscribe { events: ['logPush'] }`, then pipes incoming `logPush` push messages through the level filter and internal-message filter, printing each entry to stdout as it arrives. On Ctrl+C (SIGINT), sends `unsubscribe { events: ['logPush'] }` and exits. Push messages are delivered via WebSocket push from the plugin through the bridge host (see `07-bridge-network.md` section 5.3).

### Plugin handler

File: `templates/studio-bridge-plugin/src/Actions/LogAction.lua`

1. Reads from the ring buffer (capacity: 1000 entries, maintained by `LogBuffer.lua`).
2. Applies `direction`: `tail` slices from the end, `head` slices from the start.
3. Applies `count`: limits the number of returned entries.
4. Applies `levels` filter: only includes entries matching the requested levels.
5. Applies `includeInternal`: if false, filters out entries whose body starts with `[StudioBridge]`.
6. Sends `logsResult` with the filtered entries, total buffer count, and buffer capacity.

The ring buffer is populated by hooking `LogService.MessageOut` when the plugin loads. Each entry stores `{ level, body, timestamp }` where `timestamp` is `os.clock() * 1000` relative to plugin connection time.

### Error cases

| Condition | Error code | Message |
|-----------|-----------|---------|
| Plugin does not support `queryLogs` | `CAPABILITY_NOT_SUPPORTED` | `This Studio session does not support log queries. Update the studio-bridge plugin.` |
| Timeout | `TIMEOUT` | `Log query timed out after 10 seconds.` |
| Both `--tail` and `--head` specified | (CLI validation) | `Cannot use --tail and --head together.` |
| `--follow` with `--head` or `--tail` | (CLI validation) | `Cannot use --follow with --tail or --head.` |

### Timeout

10 seconds for `queryLogs`. No timeout for `--follow` mode (runs until interrupted).

### Retry safety

**Safe to retry.** `queryLogs` is a read-only query with no side effects. Retrying after a timeout is always safe. Note that the log buffer contents may differ between attempts (new entries added, old entries evicted).

### Return type

```typescript
interface LogsResult {
  entries: Array<{
    level: OutputLevel;
    body: string;
    timestamp: number;    // monotonic ms since plugin connection
  }>;
  total: number;
  bufferCapacity: number;
}
```

---

## 6. query -- Query DataModel

**Summary**: Inspect instances, properties, attributes, children, and services in the Roblox DataModel using dot-path expressions.

### CLI

**Command**: `studio-bridge query <expression> [session-id]`

| Positional | Type | Required | Description |
|------------|------|----------|-------------|
| `expression` | string | yes | Dot-separated instance path (e.g., `Workspace.SpawnLocation`) |

| Flag | Alias | Type | Default | Description |
|------|-------|------|---------|-------------|
| `--session` | `-s` | string | (auto) | Target session ID |
| `--children` | | boolean | `false` | List immediate children instead of the instance itself |
| `--descendants` | | boolean | `false` | List all descendants as a tree |
| `--properties` | | string | (default set) | Comma-separated property names to include |
| `--attributes` | | boolean | `false` | Include all attributes |
| `--depth` | | number | `1` | Max depth for `--descendants` |
| `--json` | | boolean | `true` | Output as JSON (default) |
| `--pretty` | | boolean | `true` | Pretty-print JSON (default; `--no-pretty` for compact) |

The CLI prepends `game.` to the expression before sending the wire message, unless the expression already starts with `game.`. This keeps user-facing paths ergonomic (`Workspace.SpawnLocation`) while the wire protocol is unambiguous (`game.Workspace.SpawnLocation`).

**Example**:

```
$ studio-bridge query Workspace.SpawnLocation
{
  "name": "SpawnLocation",
  "className": "SpawnLocation",
  "path": "game.Workspace.SpawnLocation",
  "childCount": 0,
  "properties": {
    "Position": { "type": "Vector3", "value": [0, 4, 0] },
    "Anchored": true,
    "Duration": 0
  },
  "attributes": {}
}
```

```
$ studio-bridge query Workspace --children
[
  { "name": "Camera", "className": "Camera" },
  { "name": "Terrain", "className": "Terrain" },
  { "name": "SpawnLocation", "className": "SpawnLocation" }
]
```

```
$ studio-bridge query Workspace.SpawnLocation --properties Position,Size,Anchored
{
  "name": "SpawnLocation",
  "className": "SpawnLocation",
  "path": "game.Workspace.SpawnLocation",
  "childCount": 0,
  "properties": {
    "Position": { "type": "Vector3", "value": [0, 4, 0] },
    "Size": { "type": "Vector3", "value": [8, 1, 8] },
    "Anchored": true
  },
  "attributes": {}
}
```

```
$ studio-bridge query --services
[
  { "name": "Workspace", "className": "Workspace" },
  { "name": "ReplicatedStorage", "className": "ReplicatedStorage" },
  { "name": "ServerScriptService", "className": "ServerScriptService" },
  ...
]
```

### Terminal

**Dot-command**: `.query <expression>`

Accepts the expression as a positional argument. Does not support flags; always returns the default property set in pretty-printed JSON.

```
> .query Workspace.SpawnLocation
{
  "name": "SpawnLocation",
  "className": "SpawnLocation",
  ...
}
```

### MCP

**Tool name**: `studio_query`

**Input schema**:
```typescript
interface StudioQueryInput {
  sessionId?: string;
  path: string;                  // dot-separated, without 'game.' prefix
  depth?: number;                // default: 0
  properties?: string[];         // specific property names
  includeAttributes?: boolean;   // default: false
  children?: boolean;            // default: false (list children instead of instance)
  listServices?: boolean;        // default: false
}
```

**Output schema**:
```typescript
interface StudioQueryOutput {
  instance: DataModelInstance;
}

// or, when children/listServices mode:
interface StudioQueryChildrenOutput {
  children: Array<{ name: string; className: string; path: string }>;
}
```

### Protocol

**Request**: `queryDataModel` (server to plugin)
```json
{
  "type": "queryDataModel", "sessionId": "...", "requestId": "req-004",
  "payload": {
    "path": "game.Workspace.SpawnLocation",
    "depth": 0,
    "properties": ["Position", "Anchored", "Size"],
    "includeAttributes": false
  }
}
```

**Response**: `dataModelResult` (plugin to server)
```json
{
  "type": "dataModelResult", "sessionId": "...", "requestId": "req-004",
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
```

For `--children` mode: the CLI sets `depth: 1` and the server extracts the `children` array from the result. For `--descendants`: the CLI sets `depth` to the `--depth` flag value. For `--services`: the CLI sets `listServices: true` and omits the `path`.

### Path format

Paths are **dot-separated**, matching Roblox convention. All paths on the wire start from `game` (the DataModel root).

**Examples**:
- `game.Workspace` -- the Workspace service
- `game.Workspace.Part1` -- a named child of Workspace
- `game.Workspace.Part1.Position` -- a property on Part1 (the plugin resolves up to the instance, then reads the property)
- `game.ReplicatedStorage.Modules.MyModule` -- nested path through multiple levels
- `game.StarterPlayer.StarterPlayerScripts` -- service child

**Path resolution algorithm** (plugin side):
1. Split the path on `.` to get segments: `["game", "Workspace", "SpawnLocation"]`.
2. Start at `game` (the DataModel root). Skip the first segment (which must be `"game"`).
3. For each subsequent segment, call `current:FindFirstChild(segment)`.
4. If `FindFirstChild` returns `nil` at any point, return an `INSTANCE_NOT_FOUND` error with `resolvedTo` (the dot-path of the last successful instance) and `failedSegment` (the segment that failed).
5. The final resolved instance is the target for property reads, child enumeration, etc.

**CLI path translation**: The CLI accepts user-facing paths without the `game.` prefix (e.g., `Workspace.SpawnLocation`). The CLI prepends `game.` before sending the `queryDataModel` message. If the user explicitly includes `game.`, the CLI does not double-prefix.

**Edge case -- instance names containing dots**: Instance names containing literal dots (e.g., a Part named `"my.part"`) are rare in practice. The current path format does not support escaping dots. If an instance name contains a dot, `FindFirstChild` will fail to resolve it because the dot is treated as a path separator. This is a known limitation. Implementers may choose to document this as unsupported, or add escaping support (e.g., backslash-dot `\.`) in a future protocol version.

### SerializedValue format

Property and attribute values are serialized for JSON transport using the `SerializedValue` type. Primitive types (string, number, boolean) are passed as bare JSON values without wrapping. Complex Roblox types use a `type` discriminant field and a flat `value` array containing the numeric components.

**All supported types with wire examples**:

```json
// Primitives -- passed as-is, no wrapping
"hello"
42
true

// Vector3 -- [x, y, z]
{ "type": "Vector3", "value": [1, 2, 3] }

// Vector2 -- [x, y]
{ "type": "Vector2", "value": [1, 2] }

// CFrame -- [posX, posY, posZ, r00, r01, r02, r10, r11, r12, r20, r21, r22]
// Position xyz followed by 9 rotation matrix components (row-major)
{ "type": "CFrame", "value": [1, 2, 3, 1, 0, 0, 0, 1, 0, 0, 0, 1] }

// Color3 -- [r, g, b] in 0-1 range
{ "type": "Color3", "value": [0.5, 0.2, 1.0] }

// UDim2 -- [xScale, xOffset, yScale, yOffset]
{ "type": "UDim2", "value": [0.5, 100, 0.5, 200] }

// UDim -- [scale, offset]
{ "type": "UDim", "value": [0.5, 100] }

// BrickColor -- name string + numeric ID
{ "type": "BrickColor", "name": "Bright red", "value": 21 }

// EnumItem -- enum type name, item name, numeric value
{ "type": "EnumItem", "enum": "Material", "name": "Plastic", "value": 256 }

// Instance reference -- className and dot-separated path
{ "type": "Instance", "className": "Part", "path": "game.Workspace.Part1" }

// Unsupported type -- fallback for types we cannot serialize
{ "type": "Unsupported", "typeName": "Ray", "toString": "Ray(0, 0, 0, 1, 0, 0)" }
```

**TypeScript type definition** (see `01-protocol.md` section 8 for the full definition):

```typescript
type SerializedValue =
  | string | number | boolean | null
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
```

The `type` discriminant field allows the receiver to reconstruct or display Roblox-specific types. The flat `value` array format is compact and easy to destructure. The `Unsupported` variant ensures the plugin never fails to serialize a property -- it always produces a string representation as a last resort.

### Server handler

File: `src/server/actions/query-datamodel.ts`

1. Translates CLI expression to wire path:
   - If expression starts with `game.`, use as-is.
   - Otherwise, prepend `game.` (e.g., `Workspace.SpawnLocation` becomes `game.Workspace.SpawnLocation`).
2. Builds the `queryDataModel` payload from CLI flags:
   - `--children` sets `depth: 1` (server extracts children from result).
   - `--descendants --depth N` sets `depth: N`.
   - `--properties X,Y` sets `properties: ['X', 'Y']`.
   - `--attributes` sets `includeAttributes: true`.
   - `--services` sets `listServices: true`.
3. Calls `performActionAsync` with the message.
4. Awaits `dataModelResult`.
5. Formats output:
   - Default: pretty-printed JSON of the full instance.
   - `--children`: extracts `instance.children` and prints as array of `{ name, className }`.
   - `--no-pretty`: compact single-line JSON.

### Plugin handler

File: `templates/studio-bridge-plugin/src/Actions/DataModelAction.lua`

1. If `listServices` is true: iterates `game:GetChildren()`, collects `{ name, className, path }` for each service, returns as children of a synthetic root instance.
2. Otherwise: resolves `path` by splitting on `.` and calling `FindFirstChild` at each segment starting from `game`.
3. If any segment fails to resolve, sends an `error` with code `INSTANCE_NOT_FOUND`, including `resolvedTo` (last successful path) and `failedSegment`.
4. Reads the requested `properties` from the resolved instance. For each property:
   - Primitive types (string, number, boolean) pass through as bare JSON values.
   - Roblox types (Vector3, CFrame, Color3, UDim2, etc.) are serialized using `ValueSerializer.lua` with the `type` discriminant and flat `value` arrays (see the SerializedValue format section above).
   - If a property does not exist on the instance, sends an `error` with code `PROPERTY_NOT_FOUND`.
5. If `includeAttributes` is true, reads all attributes via `instance:GetAttributes()`.
6. If `depth > 0`, recursively processes children up to the requested depth.
7. Sends `dataModelResult` with the assembled `DataModelInstance`.

### Error cases

| Condition | Error code | Message |
|-----------|-----------|---------|
| Instance path does not resolve | `INSTANCE_NOT_FOUND` | `No instance found at path: game.Workspace.NonExistent` |
| Property does not exist | `PROPERTY_NOT_FOUND` | `Property 'Foo' does not exist on SpawnLocation (SpawnLocation)` |
| Plugin does not support `queryDataModel` | `CAPABILITY_NOT_SUPPORTED` | `This Studio session does not support DataModel queries. Update the studio-bridge plugin.` |
| Timeout | `TIMEOUT` | `DataModel query timed out after 10 seconds.` |
| Expression is empty | (CLI validation) | `Expression is required. Example: studio-bridge query Workspace.SpawnLocation` |

### Timeout

10 seconds (per 01-protocol.md).

### Retry safety

**Safe to retry.** `queryDataModel` is a read-only query with no side effects. Retrying after a timeout is always safe, though DataModel state may differ between attempts.

### Return type

```typescript
interface DataModelResult {
  instance: DataModelInstance;
}

interface DataModelInstance {
  name: string;
  className: string;
  path: string;                          // full dot-separated path from game (e.g. "game.Workspace.SpawnLocation")
  properties: Record<string, SerializedValue>;
  attributes: Record<string, SerializedValue>;
  childCount: number;
  children?: DataModelInstance[];         // present only if depth > 0 was requested
}
```

See the `SerializedValue` format section above for the full type definition and wire examples, and `01-protocol.md` section 8 for the canonical TypeScript types.

---

## 7. exec -- Execute Luau code

**Summary**: Execute an inline Luau string in a Studio session. Enhanced from the existing command to support persistent sessions.

### CLI

**Command**: `studio-bridge exec <code> [session-id]`

| Positional | Type | Required | Description |
|------------|------|----------|-------------|
| `code` | string | yes | Luau code to execute |

| Flag | Alias | Type | Default | Description |
|------|-------|------|---------|-------------|
| `--session` | `-s` | string | (auto) | Target session ID |
| `--json` | | boolean | `false` | Output result as JSON `{ success, logs }` |

Global flags (`--verbose`, `--place`, `--timeout`, `--logs`, `--context`) remain available.

**Session resolution** (applies to `exec`, `run`, and `terminal`):
1. If `--session` is provided, use that session directly.
2. If no `--session`, group sessions by `instanceId`:
   a. **1 instance, Edit mode**: auto-select the Edit session (zero-config).
   b. **1 instance, Play mode**: default to the Server context for mutating commands (`exec`, `run`), or Edit context for read-only commands (`state`, `logs`, `query`, `screenshot`). Use `--context` to override. See the "Context default by command category" table below for the full rule.
   c. **0 instances**: fall back to the current behavior: launch a new Studio instance.
   d. **N instances**: error with list, require `--session` or instance selection.
3. If `--context` is provided alongside a single instance, select the session matching that context within the instance.

**Example**:

```
$ studio-bridge exec 'print("Hello from Studio")'
Hello from Studio
```

```
$ studio-bridge exec --session a1b2c3d4 'print(workspace:GetChildren())'
Camera Terrain SpawnLocation
```

```
$ studio-bridge exec --json 'print("hi"); error("oops")'
{
  "success": false,
  "error": "Script:2: oops",
  "logs": [
    { "level": "Print", "body": "hi" }
  ]
}
```

### Terminal

The terminal REPL is the primary exec surface. Any input that is not a dot-command is treated as Luau code and executed via the same path.

```
> print("Hello")
Hello

> workspace:GetChildren()
{Camera, Terrain, SpawnLocation}
```

### MCP

**Tool name**: `studio_exec`

**Input schema**:
```typescript
interface StudioExecInput {
  sessionId?: string;
  script: string;
}
```

**Output schema**:
```typescript
interface StudioExecOutput {
  success: boolean;
  error?: string;
  logs: Array<{
    level: OutputLevel;
    body: string;
  }>;
}
```

### Protocol

**Request**: `execute` (server to plugin)
```json
{
  "type": "execute", "sessionId": "...", "requestId": "req-005",
  "payload": { "script": "print('Hello from Studio')" }
}
```

**Intermediate**: `output` (plugin to server, zero or more)
```json
{
  "type": "output", "sessionId": "...",
  "payload": { "messages": [{ "level": "Print", "body": "Hello from Studio" }] }
}
```

**Response**: `scriptComplete` (plugin to server)
```json
{
  "type": "scriptComplete", "sessionId": "...", "requestId": "req-005",
  "payload": { "success": true }
}
```

The `requestId` on `execute` and `scriptComplete` is optional for backward compatibility with v1 plugins. When present, it enables concurrent request correlation.

### Server handler

The existing `executeAsync` method in `StudioBridgeServer` handles this. Changes for persistent sessions:

1. If connected to a persistent session, sends `execute` with a `requestId`.
2. Collects `output` messages into a log array.
3. Awaits `scriptComplete` with the matching `requestId`.
4. Returns `StudioBridgeResult` with success status, error string, and collected logs.

When no persistent session is available and no `--session` is provided, the server falls back to the existing flow: launch Studio, inject temporary plugin, execute, tear down.

### Plugin handler

File: `templates/studio-bridge-plugin/src/Actions/ExecuteAction.lua`

1. Receives `execute` message.
2. Calls `loadstring(script)`. If this fails (syntax error), sends `scriptComplete` with `success: false` and the error.
3. Executes the compiled function. Output from `print()` is captured via the log hook and sent as `output` messages.
4. If the function throws, captures the error and sends `scriptComplete` with `success: false`.
5. On success, sends `scriptComplete` with `success: true`.
6. Echoes `requestId` on `scriptComplete` if it was present on the `execute` message.
7. If a second `execute` arrives while the first is in progress, it is queued and executed after the first completes.

### Error cases

| Condition | Error code | Message |
|-----------|-----------|---------|
| Syntax error in code | `SCRIPT_LOAD_ERROR` | `Script error: {loadstring error message}` |
| Runtime error in code | `SCRIPT_RUNTIME_ERROR` | `Script error: {error message}` |
| Plugin busy with another execute | `BUSY` | `Plugin is busy executing another script. Please wait.` |
| Timeout | `TIMEOUT` | `Script execution timed out after {timeout} seconds.` |
| Multiple sessions, none specified | (CLI-level) | `Multiple sessions available. Use --session or --instance to specify one:\n{session list}` |

### Timeout

120 seconds default (configurable via `--timeout`).

### Retry safety

**NOT safe to retry blindly.** `exec` runs arbitrary Luau code that may have side effects (creating instances, modifying properties, firing events). A timed-out `exec` may still be running in the plugin -- the timeout is client-side only. The caller must understand the script's idempotency before deciding whether to retry. The MCP adapter should NOT auto-retry `exec` or `run`.

### Return type

```typescript
interface ExecResult {
  success: boolean;
  error?: string;
  logs: Array<{
    level: OutputLevel;
    body: string;
  }>;
}
```

---

## 8. run -- Run Luau file

**Summary**: Execute a Luau script file in a Studio session. Reads the file from disk and delegates to the same execution path as `exec`.

### CLI

**Command**: `studio-bridge run <file> [session-id]`

| Positional | Type | Required | Description |
|------------|------|----------|-------------|
| `file` | string | yes | Path to a `.lua` or `.luau` file |

| Flag | Alias | Type | Default | Description |
|------|-------|------|---------|-------------|
| `--session` | `-s` | string | (auto) | Target session ID |
| `--json` | | boolean | `false` | Output result as JSON |

Global flags remain available.

**Example**:

```
$ studio-bridge run ./scripts/setup.lua
Setting up workspace...
Done.
```

```
$ studio-bridge run --session a1b2c3d4 ./scripts/test.lua
Running tests...
All 12 tests passed.
```

### Terminal

**Dot-command**: `.run <file>`

Already exists in the current terminal mode. Reads the file and executes its contents.

```
> .run ./scripts/setup.lua
Setting up workspace...
Done.
```

### MCP

No dedicated MCP tool. Agents should read the file themselves and pass the content to `studio_exec`.

### Protocol

Same as `exec`. The CLI reads the file content and sends it as the `script` field in the `execute` message. The plugin does not know or care whether the script came from a file or inline.

### Server handler

1. Reads the file from disk via `fs.readFile`.
2. Delegates to the same `executeAsync` path used by `exec`.

### Plugin handler

Same as `exec`. The plugin receives an `execute` message with the script content.

### Error cases

| Condition | Error code | Message |
|-----------|-----------|---------|
| File not found | (CLI-level) | `Could not read script file: {path}` |
| File not readable | (CLI-level) | `Could not read script file: {path}: {os error}` |
| All `exec` errors | (same as exec) | (same as exec) |

### Timeout

120 seconds default (configurable via `--timeout`).

### Retry safety

**NOT safe to retry blindly.** Same as `exec` -- `run` delegates to the same execution path. See `exec` retry safety notes.

### Return type

Same as `exec`:

```typescript
interface ExecResult {
  success: boolean;
  error?: string;
  logs: Array<{
    level: OutputLevel;
    body: string;
  }>;
}
```

---

## 9. install-plugin -- Install persistent plugin

**Summary**: Build and install the persistent studio-bridge plugin into Roblox Studio's plugins folder. One-time setup that enables all persistent session features.

### CLI

**Command**: `studio-bridge install-plugin`

| Flag | Alias | Type | Default | Description |
|------|-------|------|---------|-------------|
| `--force` | | boolean | `false` | Overwrite existing plugin without prompting |

**Example**:

```
$ studio-bridge install-plugin
Building persistent plugin...
Plugin installed to /Users/dev/Library/Application Support/Roblox/Plugins/StudioBridgePlugin.rbxm
Restart Studio for the plugin to take effect.
```

```
$ studio-bridge install-plugin
Plugin already installed at /Users/dev/Library/Application Support/Roblox/Plugins/StudioBridgePlugin.rbxm
Use --force to overwrite.
```

```
$ studio-bridge install-plugin --force
Building persistent plugin...
Plugin updated at /Users/dev/Library/Application Support/Roblox/Plugins/StudioBridgePlugin.rbxm
Restart Studio for changes to take effect.
```

### Terminal

No dot-command. Plugin installation is a one-time setup step, not something done during an interactive session.

### MCP

No MCP tool. Plugin installation requires user action (restarting Studio) and is not suitable for automated agent use.

### Protocol

No wire protocol involvement. This is a local file operation.

### Server handler

File: `src/plugin/persistent-plugin-installer.ts`

1. Locates the Studio plugins folder using `findPluginsFolder()` from `studio-process-manager.ts`.
2. Builds the persistent plugin template via Rojo (`rojo build`).
3. Copies the resulting `.rbxm` to the plugins folder.
4. If the file already exists and `--force` is not set, prompts the user or prints the "already installed" message.

### Plugin handler

None. This action does not interact with a running plugin.

### Error cases

| Condition | Message |
|-----------|---------|
| Studio plugins folder not found | `Could not find Roblox Studio plugins folder. Is Studio installed?` |
| Rojo not installed | `Rojo is required to build the plugin. Run 'aftman install' to install it.` |
| Rojo build failed | `Failed to build plugin: {rojo error}` |
| Write permission denied | `Cannot write to {path}: Permission denied` |

### Timeout

Not applicable (local build and copy).

### Return type

```typescript
interface InstallPluginResult {
  installed: boolean;
  path: string;
  updated: boolean;   // true if overwrote an existing plugin
}
```

---

## 10. launch -- Launch new Studio session

**Summary**: Explicitly launch a new Roblox Studio instance with the studio-bridge plugin active. This preserves the current `exec` behavior as a dedicated command, useful when no sessions exist or when a fresh session is needed.

### CLI

**Command**: `studio-bridge launch [place]`

| Positional | Type | Required | Description |
|------------|------|----------|-------------|
| `place` | string | no | Path to `.rbxl` place file. If omitted, uses a default empty place. |

| Flag | Alias | Type | Default | Description |
|------|-------|------|---------|-------------|
| `--wait` | | boolean | `true` | Wait for the plugin to connect before returning |
| `--json` | | boolean | `false` | Output session info as JSON when connected |

**Example**:

```
$ studio-bridge launch ./MyGame.rbxl
Launching Studio with MyGame.rbxl...
Session a1b2c3d4-e5f6-7890-abcd-ef1234567890 connected.
```

```
$ studio-bridge launch --json
{
  "sessionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "placeName": "Empty",
  "state": "Edit"
}
```

When `exec` or `run` is called with no sessions available, this is the flow that executes internally. `launch` makes it explicit as a standalone command.

### Terminal

No dot-command. Launching Studio is the entry point to a session, not an action within one.

### MCP

No dedicated MCP tool. Agents discover existing sessions via `studio_sessions`. If no sessions exist, the agent should inform the user to launch Studio.

### Protocol

Uses the existing `hello`/`welcome` (or `register`/`welcome`) handshake. If the persistent plugin is installed, the server starts and waits for the plugin to discover it. If not, the server injects the temporary plugin as in the current implementation.

### Server handler

1. Creates a `StudioBridgeServer` with the specified place path.
2. Calls `startAsync()`, which:
   - Starts the WebSocket server on a random port.
   - Registers in the session registry.
   - If persistent plugin is installed: launches Studio and waits for the plugin to connect.
   - If not: builds and injects the temporary plugin, launches Studio, waits for handshake.
3. If `--wait` is true (default), blocks until the handshake completes, then prints session info.
4. If `--wait` is false, returns immediately after starting the server (useful for scripts that launch Studio in the background).

### Plugin handler

Standard handshake (same as any other session connection).

### Error cases

| Condition | Message |
|-----------|---------|
| Studio not installed | `Roblox Studio not found. Is it installed?` |
| Place file not found | `Place file not found: {path}` |
| Plugin handshake timeout | `Studio launched but plugin did not connect within {timeout}ms. Check Studio's output for errors.` |
| Port allocation failed | `Could not allocate a port for the WebSocket server.` |

### Timeout

Inherits global `--timeout` (default: 30000ms) for plugin handshake.

### Return type

```typescript
interface LaunchResult {
  sessionId: string;
  placeName: string;
  state: StudioState;
}
```

---

## Context default by command category

When a Studio instance is in Play mode and no `--context` flag is provided, the default context depends on the command category:

| Category | Commands | Default context | Rationale |
|----------|----------|----------------|-----------|
| Read-only | `state`, `logs`, `query`, `screenshot` | `edit` | The Edit context always exists and provides a stable view. |
| Mutating | `exec`, `run` | `server` | Script execution and file runs target the server VM, which is the most common debugging target during Play mode. |
| Non-session | `sessions`, `install-plugin`, `serve` | N/A | These commands do not target a session context. |

This table is the single source of truth. The `resolveSession` utility applies these defaults based on the `CommandDefinition`'s `defaultContext` field (or falls back to `'edit'` when unset).

---

## Session resolution logic

This section documents the shared heuristic used by all session-targeting commands (`state`, `screenshot`, `logs`, `query`, `exec`, `run`). It is implemented once in a shared utility and referenced by each command handler.

### Algorithm (instance-aware)

A single Studio instance produces 1-3 sessions that share an `instanceId`. In Edit mode there is one session (`context: 'edit'`). In Play mode the instance may produce up to three sessions (`context: 'edit'`, `context: 'server'`, `context: 'client'`). The resolution algorithm groups sessions by instance before selecting:

```
1. If --session <id> is provided:
   a. Look up <id> via bridge connection.
   b. If found and connected: use it.
   c. If found but disconnected: error "Session exists but plugin is not connected."
   d. If not found: error "Session not found."

2. If [session-id] positional argument is provided:
   Same as step 1.

3. If neither --session nor positional is provided:
   a. List all connected sessions from the bridge.
   b. Group sessions by instanceId.
   c. If zero instances: fall back to launch behavior (for exec/run) or error (for state/screenshot/logs/query).
   d. If exactly one instance:
      i.   If --context is provided: select the session matching that context within the instance.
           Error if no session matches (e.g., --context server when Studio is in Edit mode).
      ii.  If --context is NOT provided and instance is in Edit mode (1 session): auto-select it.
      iii. If --context is NOT provided and instance is in Play mode (2-3 sessions):
           default to the Edit context (safe default -- the Edit context always exists).
   e. If multiple instances:
      i.   Error: "Multiple Studio instances connected. Use --session to specify one:" + grouped list.
```

### Context selection summary

| Instance state | `--context` flag | Behavior |
|---------------|-----------------|----------|
| Edit mode (1 session) | not set | Auto-select Edit session |
| Edit mode (1 session) | `edit` | Select Edit session |
| Edit mode (1 session) | `server` or `client` | Error: "No server/client context. Studio is in Edit mode." |
| Play mode (2-3 sessions) | not set | Default to Edit context |
| Play mode (2-3 sessions) | `edit` | Select Edit session |
| Play mode (2-3 sessions) | `server` | Select Server session |
| Play mode (2-3 sessions) | `client` | Select Client session |

### Zero-instance behavior by command

| Command | When zero instances exist |
|---------|-------------------------|
| `exec` | Launch a new Studio session, then execute (current behavior preserved) |
| `run` | Launch a new Studio session, then execute (current behavior preserved) |
| `terminal` | Launch a new Studio session, then enter REPL (current behavior preserved) |
| `state` | Error: "No active sessions." |
| `screenshot` | Error: "No active sessions." |
| `logs` | Error: "No active sessions." |
| `query` | Error: "No active sessions." |

### Multiple-instance behavior

| Instances | `--session` flag | `--instance` flag | Behavior |
|-----------|-----------------|-------------------|----------|
| N > 1 | not set | not set | Error: "Multiple Studio instances connected. Use --session or --instance to specify one:" + grouped session list |
| N > 1 | set | any | Use specified session directly |
| N > 1 | not set | set | Select that instance, apply context selection |

---

## Timeout summary

| Action | Protocol message | Default timeout |
|--------|-----------------|----------------|
| state | `queryState` | 5s |
| screenshot | `captureScreenshot` | 15s |
| logs | `queryLogs` | 10s |
| query | `queryDataModel` | 10s |
| exec | `execute` | 120s |
| run | `execute` | 120s |
| subscribe | `subscribe` | 5s |
| unsubscribe | `unsubscribe` | 5s |

All timeouts are server-side. The server rejects the pending promise after the timeout period. No cancellation message is sent to the plugin.

---

## Error code reference

This is the complete mapping from error codes (defined in `01-protocol.md`) to the actions that can produce them.

| Error code | Actions | Meaning |
|-----------|---------|---------|
| `UNKNOWN_REQUEST` | any | Plugin received a message type it does not recognize |
| `INVALID_PAYLOAD` | any | Message payload failed validation |
| `TIMEOUT` | state, screenshot, logs, query, exec | Operation timed out (server-side) |
| `CAPABILITY_NOT_SUPPORTED` | state, screenshot, logs, query | Plugin does not support the requested capability |
| `INSTANCE_NOT_FOUND` | query | Dot-path did not resolve to an instance |
| `PROPERTY_NOT_FOUND` | query | Requested property does not exist on the instance |
| `SCREENSHOT_FAILED` | screenshot | CaptureService call failed |
| `SCRIPT_LOAD_ERROR` | exec, run | `loadstring` failed (syntax error) |
| `SCRIPT_RUNTIME_ERROR` | exec, run | Script threw during execution |
| `BUSY` | exec, run | Plugin is already executing another script |
| `SESSION_MISMATCH` | any | Session ID in message does not match the connection |
| `INTERNAL_ERROR` | any | Unexpected error inside the plugin |
