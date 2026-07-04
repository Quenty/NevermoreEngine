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
              WebSocket /client │
                 ┌──────────┘
                 │
          ┌──────┴──────┐
          │  CLI Client  │
          │ (exec, run,  │
          │  query…)     │
          └─────────────┘
```

**Host** — A single process binds port 38741, accepts plugin and client connections, and tracks sessions. Any CLI invocation auto-promotes to host if the port is free.

**Plugin** — A persistent Roblox Studio plugin that discovers the host by polling `GET /health`, then connects via WebSocket. Survives Studio restarts. Actions are pushed dynamically over the wire on connect.

**Client** — CLI commands connect as clients when a host is already running. Actions are relayed through the host to the target plugin.

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
