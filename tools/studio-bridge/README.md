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

**Plugin** — A persistent Roblox Studio plugin that discovers the host by polling `GET /health`, then connects via WebSocket. Survives Studio restarts.

**Client** — CLI commands and the MCP server connect as clients when a host is already running. Actions are relayed through the host to the target plugin.

## Quick Start

```bash
# 1. Install the persistent Studio plugin (one-time)
studio-bridge install-plugin

# 2. Start a bridge host (or let any command auto-start one)
studio-bridge serve

# 3. Open Roblox Studio — the plugin connects automatically

# 4. Execute Luau code
studio-bridge exec 'print("hello from the bridge")'

# 5. Run a script file
studio-bridge run test.lua
```

## CLI Commands

| Command | Description |
|---------|-------------|
| `exec <code>` | Execute inline Luau code |
| `run <file>` | Execute a Luau script file |
| `terminal` | Interactive REPL (keeps Studio alive between executions) |
| `sessions` | List active sessions |
| `serve` | Start a dedicated bridge host |
| `state` | Query current Studio state (mode, place, IDs) |
| `logs` | Retrieve and stream output logs |
| `screenshot` | Capture a screenshot from Studio |
| `query <path>` | Query the DataModel (instances, properties, attributes) |
| `mcp` | Start an MCP server (stdio transport) |
| `launch` | Launch Roblox Studio |
| `install-plugin` | Install the persistent bridge plugin |
| `uninstall-plugin` | Remove the persistent bridge plugin |

### `exec`

```bash
studio-bridge exec 'print(workspace:GetChildren())'
studio-bridge exec 'return game.PlaceId' --json
studio-bridge exec 'print("hello")' --session my-session
```

| Option | Alias | Default | Description |
|--------|-------|---------|-------------|
| `--session` | `-s` | — | Target session ID |
| `--instance` | — | — | Target instance ID |
| `--context` | — | — | Target context (`edit`, `client`, `server`) |
| `--json` | — | `false` | Output as JSON |

### `run`

```bash
studio-bridge run test.lua
studio-bridge run test.lua --context server --json
```

Same options as `exec`.

### `terminal`

Interactive REPL mode. Keeps Studio alive between executions — type Luau, see results, repeat.

```bash
studio-bridge terminal
studio-bridge terminal --script init.lua
studio-bridge terminal --script-text 'print("setup")'
```

| Option | Alias | Default | Description |
|--------|-------|---------|-------------|
| `--script` | `-s` | — | Luau file to run on connect |
| `--script-text` | `-t` | — | Inline Luau to run on connect |

| Key | Action |
|-----|--------|
| Enter | New line |
| Ctrl+Enter | Execute buffer |
| Ctrl+C | Clear buffer (exit if empty) |
| Ctrl+D | Exit |

| Command | Description |
|---------|-------------|
| `.help` | Show keybindings |
| `.exit` | Exit terminal |
| `.run <file>` | Execute a Luau file |
| `.clear` | Clear editor buffer |

### `sessions`

```bash
studio-bridge sessions
studio-bridge sessions --json
```

Lists all active sessions with their ID, place, context, state, and origin.

### `serve`

```bash
studio-bridge serve
studio-bridge serve --port 9000 --log-level debug
studio-bridge serve --json
```

| Option | Default | Description |
|--------|---------|-------------|
| `--port` | `38741` | Port to listen on |
| `--json` | `false` | Output structured JSON lines |
| `--log-level` | `info` | Verbosity (`silent`, `error`, `warn`, `info`, `debug`) |

### `state`

```bash
studio-bridge state
studio-bridge state --session my-session --json
```

Returns the Studio mode (`Edit`, `Play`, `Run`, etc.), place name, place ID, and game ID. Supports `--session`, `--instance`, `--context`, `--json`.

### `logs`

```bash
studio-bridge logs
studio-bridge logs --tail 100
studio-bridge logs --head 20 --level Error,Warning
studio-bridge logs --all --json
```

| Option | Alias | Default | Description |
|--------|-------|---------|-------------|
| `--tail` | — | `50` | Number of most recent entries |
| `--head` | — | — | Number of oldest entries (overrides `--tail`) |
| `--level` | `-l` | — | Filter by level (comma-separated: `Print`, `Warning`, `Error`) |
| `--all` | — | `false` | Include internal messages |

Also supports `--session`, `--instance`, `--context`, `--json`.

### `screenshot`

```bash
studio-bridge screenshot --output viewport.png
studio-bridge screenshot --base64
studio-bridge screenshot --json
```

| Option | Alias | Default | Description |
|--------|-------|---------|-------------|
| `--output` | `-o` | — | File path to write the PNG |
| `--base64` | — | `false` | Output raw base64 to stdout |

Also supports `--session`, `--instance`, `--context`, `--json`.

### `query`

```bash
studio-bridge query Workspace.SpawnLocation
studio-bridge query Workspace --children
studio-bridge query Workspace --descendants --depth 3 --properties
```

| Option | Default | Description |
|--------|---------|-------------|
| `--children` | `false` | Include direct children |
| `--descendants` | `false` | Include all descendants |
| `--depth` | `10` | Max depth for descendants |
| `--properties` | `false` | Include instance properties |
| `--attributes` | `false` | Include instance attributes |

Also supports `--session`, `--instance`, `--context`, `--json`.

### `mcp`

```bash
studio-bridge mcp
```

Starts an MCP server over stdio. See [MCP Server](#mcp-server) for integration details.

## Global Options

| Option | Alias | Default | Description |
|--------|-------|---------|-------------|
| `--place` | `-p` | — | Path to `.rbxl` file (builds minimal place via rojo if omitted) |
| `--timeout` | — | `120000` | Timeout in milliseconds |
| `--verbose` | — | `false` | Show internal debug output |
| `--logs` / `--no-logs` | — | `true` | Show execution logs in spinner mode |
| `--remote` | — | — | Connect to a remote bridge host (`host:port`) |
| `--local` | — | `false` | Force local mode (skip devcontainer auto-detection) |

### Session Selection

Several commands accept `--session`, `--instance`, and `--context` to target a specific Studio session:

- **No flags** — auto-resolves if only one session exists
- **`--session <id>`** — target a specific session by ID
- **`--instance <id>`** — target by instance ID (groups Edit/Client/Server contexts)
- **`--context <ctx>`** — select context within an instance (`edit`, `client`, `server`)

When Studio is in Play mode, a single instance has multiple contexts (Edit + Client + Server). The default is `edit`.

## Programmatic API

### Persistent sessions (v2)

```typescript
import { BridgeConnection } from '@quenty/studio-bridge';

const connection = await BridgeConnection.connectAsync();
const session = await connection.resolveSession();

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
| `studio_sessions` | List active sessions |
| `studio_state` | Query Studio state (mode, place, IDs) |
| `studio_exec` | Execute Luau code |
| `studio_screenshot` | Capture viewport screenshot |
| `studio_logs` | Retrieve buffered logs |
| `studio_query` | Query DataModel instances and properties |

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

### Capabilities

Negotiated during handshake: `execute`, `queryState`, `captureScreenshot`, `queryDataModel`, `queryLogs`, `subscribe`, `heartbeat`.

### Output Levels

`"Print"`, `"Info"`, `"Warning"`, `"Error"` — matches `Enum.MessageType`.

### Error Codes

`UNKNOWN_REQUEST`, `INVALID_PAYLOAD`, `TIMEOUT`, `CAPABILITY_NOT_SUPPORTED`, `INSTANCE_NOT_FOUND`, `PROPERTY_NOT_FOUND`, `SCREENSHOT_FAILED`, `SCRIPT_LOAD_ERROR`, `SCRIPT_RUNTIME_ERROR`, `BUSY`, `SESSION_MISMATCH`, `INTERNAL_ERROR`

## Plugin Discovery

The persistent plugin discovers the bridge host automatically:

1. Poll `GET http://localhost:38741/health` (default port)
2. Health endpoint returns `{ status, port, protocolVersion, sessions, uptime }`
3. Connect to `ws://localhost:{port}/plugin`
4. Send `register` message with capabilities
5. Receive `welcome` with negotiated protocol version

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
