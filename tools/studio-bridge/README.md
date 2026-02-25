# @quenty/studio-bridge

Persistent WebSocket bridge between Node.js and Roblox Studio. Install a plugin once, then execute Luau, capture screenshots, query the DataModel, and stream logs — all from the CLI or programmatically.

## Architecture

```
                          ┌──────────────────────────┐
                          │    Roblox Studio (1..N)   │
                          │  ┌────────────────────┐  │
                          │  │ Persistent Plugin   │  │
                          │  │ (port scan → connect│  │
                          │  │  via /health)       │  │
                          │  └────────┬───────────┘  │
                          └───────────┼──────────────┘
                  WebSocket /plugin   │
                          ┌───────────┴──────────────┐
                          │      Bridge Host          │
                          │  ┌──────────────────────┐│
                          │  │ SessionTracker       ││
                          │  │  (groups by instance) ││
                          │  └──────────────────────┘│
                          │  /health  /plugin  /client│
                          └──┬───────────────────┬───┘
              WebSocket /client │                │ WebSocket /client
                 ┌──────────┘                └──────────┐
                 │                                      │
          ┌──────┴──────┐                      ┌────────┴────┐
          │  CLI Client  │                      │  MCP Server  │
          │ (exec, run,  │                      │ (Claude, etc)│
          │  terminal…)  │                      │              │
          └─────────────┘                      └──────────────┘
```

**Host** — A single process binds port 38741, accepts plugin and client connections, and tracks sessions. Any CLI invocation auto-promotes to host if the port is free.

**Plugin** — A persistent Roblox Studio plugin that discovers the host by polling `GET /health`, then connects via WebSocket. Survives Studio restarts. Actions are pushed dynamically over the wire on connect.

**Client** — CLI commands and the MCP server connect as clients when a host is already running. Actions are relayed through the host to the target plugin.

## Quick Start

```bash
# 1. Install the persistent Studio plugin (one-time)
studio-bridge plugin install

# 2. Start a bridge host (or let any command auto-start one)
studio-bridge serve

# 3. Open Roblox Studio — the plugin connects automatically

# 4. Execute Luau code
studio-bridge console exec 'print("hello from the bridge")'

# 5. Query the DataModel
studio-bridge explorer query Workspace --children
```

## CLI Commands

```
studio-bridge <command> [options]

Execution:
  console <command>      Execute code and view logs
  explorer <command>     Query and modify the DataModel
  viewport <command>     Screenshots and camera control
  action <name>          Invoke a Studio action

Infrastructure:
  process <command>      Manage Studio processes
  plugin <command>       Manage the bridge plugin
  serve                  Start the bridge server
  mcp                    Start the MCP server
  terminal               Interactive REPL
```

### `console exec`

```bash
studio-bridge console exec 'print(workspace:GetChildren())'
studio-bridge console exec --file test.lua
studio-bridge console exec 'return game.PlaceId' --format json
```

| Option | Alias | Description |
|--------|-------|-------------|
| `--file` | `-f` | Path to a Luau script file |
| `--target` | `-t` | Target session ID |
| `--context` | — | Target context (`edit`, `client`, `server`) |

### `console logs`

```bash
studio-bridge console logs
studio-bridge console logs --count 100 --direction head
studio-bridge console logs --levels Error,Warning
```

| Option | Alias | Description |
|--------|-------|-------------|
| `--count` | `-n` | Number of entries (default: 50) |
| `--direction` | `-d` | `head` or `tail` (default: `tail`) |
| `--levels` | `-l` | Filter by level (comma-separated) |
| `--includeInternal` | — | Include internal bridge messages |

### `explorer query`

```bash
studio-bridge explorer query Workspace
studio-bridge explorer query Workspace.SpawnLocation --children --depth 3
```

| Option | Description |
|--------|-------------|
| `--children` | Include direct children |
| `--depth` | Max depth (default: 0) |
| `--properties` | Include instance properties |
| `--attributes` | Include instance attributes |

### `viewport screenshot`

```bash
studio-bridge viewport screenshot --output viewport.png
studio-bridge viewport screenshot --format base64
```

| Option | Alias | Description |
|--------|-------|-------------|
| `--output` | `-o` | Write PNG to file |

### `process list`

```bash
studio-bridge process list
```

Lists all active sessions with their ID, place, context, state, and origin.

### `process info`

```bash
studio-bridge process info
```

Returns the Studio mode (`Edit`, `Play`, `Run`, etc.), place name, place ID, and game ID.

### `process launch`

```bash
studio-bridge process launch
studio-bridge process launch --place ./build/test.rbxl
```

### `process run`

```bash
studio-bridge process run 'print("hello")'
studio-bridge process run --file test.lua --place ./build/test.rbxl
```

Explicit ephemeral mode: launches Studio, executes the script, and shuts down.

### `process close`

```bash
studio-bridge process close --target session-id
```

Send a shutdown message to a connected Studio session.

### `plugin install` / `plugin uninstall`

```bash
studio-bridge plugin install
studio-bridge plugin uninstall
```

### `serve`

```bash
studio-bridge serve
studio-bridge serve --port 9000
```

### `terminal`

Interactive REPL mode. Keeps Studio alive between executions.

```bash
studio-bridge terminal
studio-bridge terminal --script init.lua
```

| Key | Action |
|-----|--------|
| Enter | New line |
| Ctrl+Enter | Execute buffer |
| Ctrl+C | Clear buffer (exit if empty) |
| Ctrl+D | Exit |

### `mcp`

```bash
studio-bridge mcp
```

Starts an MCP server over stdio. See [MCP Server](#mcp-server) for integration details.

### `action`

```bash
studio-bridge action <name> [--payload '{"key": "value"}']
```

Invoke a named Studio action on the connected session.

## Global Options

| Option | Default | Description |
|--------|---------|-------------|
| `--timeout` | `120000` | Timeout in milliseconds |
| `--verbose` | `false` | Show internal debug output |
| `--remote` | — | Connect to a remote bridge host (`host:port`) |
| `--local` | `false` | Force local mode (skip devcontainer auto-detection) |

### Target Selection

Commands that target a session accept `--target` and `--context`:

- **No flags** — auto-resolves if only one session exists
- **`--target <id>`** — target a specific session by ID
- **`--context <ctx>`** — select context within an instance (`edit`, `client`, `server`)

When Studio is in Play mode, a single instance has multiple contexts (Edit + Client + Server). The default is `edit`.

## Programmatic API

### Persistent sessions (v2)

```typescript
import { BridgeConnection } from '@quenty/studio-bridge';

const connection = await BridgeConnection.connectAsync();
const session = await connection.resolveSessionAsync();

const result = await session.execAsync('return game.PlaceId');
console.log(result.success, result.returnValue);

const state = await session.queryStateAsync();
console.log(state.mode, state.placeName);

const screenshot = await session.captureScreenshotAsync();
// screenshot.base64, screenshot.width, screenshot.height

const logs = await session.queryLogsAsync({ tail: 50 });
// logs.entries: { level, body, timestamp }[]

const tree = await session.queryDataModelAsync({ path: 'Workspace' });
// tree.name, tree.className, tree.children

await connection.disconnectAsync();
```

#### `BridgeConnectionOptions`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `port` | `number` | `38741` | Port to bind/connect |
| `timeoutMs` | `number` | `30000` | Connection setup timeout |
| `keepAlive` | `boolean` | `false` | Prevent idle host shutdown |
| `remoteHost` | `string` | — | Force client mode (`host:port`) |
| `local` | `boolean` | `false` | Skip devcontainer auto-detection |

#### `BridgeSession` methods

| Method | Timeout | Description |
|--------|---------|-------------|
| `execAsync(code, timeout?)` | 120s | Execute Luau code |
| `queryStateAsync()` | 5s | Get Studio mode, place name, IDs |
| `captureScreenshotAsync()` | 15s | Capture viewport PNG |
| `queryLogsAsync(options?)` | 10s | Retrieve buffered log entries |
| `queryDataModelAsync(options)` | 10s | Query instance tree |
| `subscribeAsync(events)` | 5s | Subscribe to push events |
| `unsubscribeAsync(events)` | 5s | Unsubscribe from events |

### One-shot execution (legacy)

```typescript
import { StudioBridge } from '@quenty/studio-bridge';

const bridge = new StudioBridge({ placePath: './build/test.rbxl' });
await bridge.startAsync();

const result = await bridge.executeAsync({
  scriptContent: 'print("Hello from studio-bridge!")',
  timeoutMs: 90_000,
  onOutput: (level, body) => console.log(`[${level}] ${body}`),
});

console.log(result.success); // boolean
console.log(result.logs);    // all captured output, newline-separated

await bridge.stopAsync();
```

The legacy API launches Studio, injects a temporary plugin, executes a script, and tears everything down. Use `BridgeConnection` instead for persistent workflows.

## MCP Server

The MCP server exposes studio-bridge capabilities to Claude and other MCP clients.

```bash
# Start directly
studio-bridge mcp
```

Add to your Claude configuration:

```json
{
  "mcpServers": {
    "studio-bridge": {
      "command": "studio-bridge",
      "args": ["mcp"]
    }
  }
}
```

### MCP Tools

| Tool | Description |
|------|-------------|
| `studio_console_exec` | Execute Luau code |
| `studio_console_logs` | Retrieve buffered logs |
| `studio_explorer_query` | Query DataModel instances and properties |
| `studio_viewport_screenshot` | Capture viewport screenshot |
| `studio_process_info` | Query Studio state (mode, place, IDs) |
| `studio_process_list` | List active sessions |
| `studio_process_close` | Send shutdown to a session |
| `studio_action` | Invoke a named Studio action |

All session-aware tools accept optional `sessionId` and `context` parameters and auto-resolve when omitted.

## WebSocket Protocol

All messages are JSON: `{ type, sessionId, payload }`. The plugin and server negotiate protocol version on connect — v1 plugins get the minimal message set, v2 plugins get the full feature set.

### v1 Messages (legacy)

**Plugin to Server:**

| Type | Payload | Description |
|------|---------|-------------|
| `hello` | `{ sessionId }` | Handshake |
| `output` | `{ messages: [{ level, body }] }` | Batched log output |
| `scriptComplete` | `{ success, error? }` | Script finished |

**Server to Plugin:**

| Type | Payload | Description |
|------|---------|-------------|
| `welcome` | `{ sessionId }` | Handshake accepted |
| `execute` | `{ script }` | Luau script to run |
| `shutdown` | `{}` | Graceful disconnect |

### v2 Messages

**Plugin to Server:**

| Type | Payload | Description |
|------|---------|-------------|
| `register` | `{ sessionId, capabilities, pluginVersion, … }` | v2 handshake with capabilities |
| `stateResult` | `{ requestId, mode, placeName, placeId, gameId }` | Response to `queryState` |
| `screenshotResult` | `{ requestId, base64, width, height }` | Response to `captureScreenshot` |
| `dataModelResult` | `{ requestId, instances }` | Response to `queryDataModel` |
| `logsResult` | `{ requestId, entries }` | Response to `queryLogs` |
| `stateChange` | `{ state, previousState }` | Push event on state transition |
| `heartbeat` | `{ uptimeMs, state, pendingRequests }` | Periodic keep-alive |
| `subscribeResult` | `{ requestId, events }` | Subscription confirmed |
| `unsubscribeResult` | `{ requestId, events }` | Unsubscription confirmed |
| `registerActionResult` | `{ requestId, name, success, error? }` | Dynamic action registration result |
| `error` | `{ requestId, code, message }` | Error response |

**Server to Plugin:**

| Type | Payload | Description |
|------|---------|-------------|
| `queryState` | `{ requestId }` | Request current state |
| `captureScreenshot` | `{ requestId }` | Request viewport screenshot |
| `queryDataModel` | `{ requestId, path, depth?, properties?, attributes? }` | Request instance tree |
| `queryLogs` | `{ requestId, tail?, head?, levels? }` | Request buffered logs |
| `subscribe` | `{ requestId, events }` | Subscribe to push events |
| `unsubscribe` | `{ requestId, events }` | Unsubscribe from events |
| `registerAction` | `{ requestId, name, source, responseType? }` | Push a Luau action module dynamically |

### Capabilities

Negotiated during handshake: `execute`, `queryState`, `captureScreenshot`, `queryDataModel`, `queryLogs`, `subscribe`, `heartbeat`, `registerAction`.

### Output Levels

`"Print"`, `"Info"`, `"Warning"`, `"Error"` — matches `Enum.MessageType`.

### Error Codes

`UNKNOWN_REQUEST`, `INVALID_PAYLOAD`, `TIMEOUT`, `CAPABILITY_NOT_SUPPORTED`, `INSTANCE_NOT_FOUND`, `PROPERTY_NOT_FOUND`, `SCREENSHOT_FAILED`, `SCRIPT_LOAD_ERROR`, `SCRIPT_RUNTIME_ERROR`, `BUSY`, `SESSION_MISMATCH`, `INTERNAL_ERROR`

## Dynamic Action Registration

The bridge plugin ships as a thin runtime — no static Luau action modules. Instead, action code is pushed dynamically over the wire when a plugin connects:

1. Plugin connects and sends `register` with `registerAction` capability
2. Bridge host scans co-located `.luau` files from `src/commands/<group>/<name>/`
3. Each action's source is sent via `registerAction` message
4. Plugin calls `loadstring()` to install the handler at runtime

This means:
- Adding a new command requires only a `.ts` + `.luau` file in the command directory
- No plugin reinstallation needed when actions change
- Hot-reload during development: reconnect pushes updated action code

## Plugin Discovery

The persistent plugin discovers the bridge host automatically:

1. Poll `GET http://localhost:38741/health` (default port)
2. Health endpoint returns `{ status, port, protocolVersion, sessions, uptime }`
3. Connect to `ws://localhost:{port}/plugin`
4. Send `register` message with capabilities
5. Receive `welcome` with negotiated protocol version
6. Receive `registerAction` messages for each command's Luau action

If the health endpoint is unreachable, the plugin retries with backoff. The plugin survives Studio restarts and reconnects automatically when a host becomes available.

### Role Detection

When a CLI command runs, `BridgeConnection` automatically detects whether to be host or client:

1. If `--remote` specified — connect as client
2. If inside a devcontainer — attempt remote connection first (3s timeout)
3. Try to bind the port — success means become host
4. Port in use — check `/health` — if healthy, become client; if stale, retry

## Testing

```bash
pnpm test              # Unit tests (Vitest, no Studio needed)
pnpm test:watch        # Watch mode
pnpm test:plugin       # Lune-based plugin tests
pnpm test:integration  # End-to-end smoke test (requires Studio)
```

| Layer | What it tests | Studio? |
|-------|--------------|---------|
| Unit (`pnpm test`) | Protocol, bridge connection, session tracking, command handlers, WebSocket lifecycle | No |
| Plugin (`pnpm test:plugin`) | Luau plugin logic via Lune runner | No |
| Integration (`pnpm test:integration`) | Full pipeline: rojo build, plugin injection, Studio launch, output capture | Yes |

## Platform Support

| Platform | Studio Location | Plugins Folder |
|----------|----------------|----------------|
| Windows | `%LOCALAPPDATA%\Roblox\Versions\*\RobloxStudioBeta.exe` | `%LOCALAPPDATA%\Roblox\Plugins\` |
| macOS | `/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudioBeta` | `~/Documents/Roblox/Plugins/` |
