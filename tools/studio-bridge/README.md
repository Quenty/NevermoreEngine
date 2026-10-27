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
| `--timeout` | — | Cancel the script after this many milliseconds (default: 120000) |
| `--allow-edit` | — | Change Edit even while a playtest of it runs |

Output includes everything logged while the script runs, including prints from modules it requires and from threads it starts. A runtime error comes with a traceback. A script that runs past `--timeout` is cancelled, so the scripts queued behind it still run. While a playtest is running, `exec` on Edit is refused, since the playtest runs a copy and would not see the change; target the playtest with `--context server` or `--context client` instead.

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

### `explorer export` / `explorer import`

```bash
studio-bridge explorer export Workspace.Map Lighting -o map.rbxm
studio-bridge explorer import map.rbxm --parent ServerStorage
```

`export` saves instances as a binary model (`.rbxm`) through `SerializationService`, and writes it with `-o`. `import` inserts a `.rbxm` under `--parent` (default: `Workspace`).

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

Lists the connected sessions with their ID, context, place, and state. `--target` and `--context` narrow the list. While a playtest studio-bridge started is running, every session of that Studio shows `Play` (or `Run` without a client).

### `process info`

```bash
studio-bridge process info
```

Returns the Studio mode (`Edit`, `Play`, `Run`, etc.), place name, place ID, game ID, and viewport size, plus whether the Studio window is focused or minimized.

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

Launches Studio on a copy of the place, runs the script there and nowhere else, then closes that Studio. Other open Studios are never used. While the script runs, the launched Studio is a session like any other, so `process list` shows it (origin `managed`) and other commands can target it.

### `process close`

```bash
studio-bridge process close --target test-place
studio-bridge process close --target test-place --force
```

Closes the Studio process showing the session's place, found by its window title. Studio usually asks to save a local place first, so without `--force` the command reports that Studio is still open; `--force` kills it without saving. When several windows show the same place, pick one with `--pid`.

### `playtest run` / `playtest start` / `playtest restart` / `playtest stop`

```bash
studio-bridge playtest run 'return #game:GetService("Players"):GetPlayers()'
studio-bridge playtest run --context client 'return game:GetService("Players").LocalPlayer.Name'
studio-bridge playtest start --mode run
studio-bridge console exec --context server 'print("in the playtest")'
studio-bridge playtest restart
studio-bridge playtest stop
```

Starts a playtest through `StudioTestService` in the open Studio. `--mode play` (the default) runs a server and a client with a player; `--mode run` runs only the server.

`playtest run` executes the code in a fresh playtest's server, returns its output and values like `console exec`, then stops the playtest. It plants a temporary runner script in the playtest to do so, so it works whatever Studio's **Load user plugins on playtest** setting says. `--context client` runs the code in the playtest's client instead, which needs that setting on.

`playtest start` leaves the playtest running, so other commands can target it with `--context server` or `--context client`. `playtest restart` stops it and starts a new one in the same mode, picking up code changed since it started; with none running, it starts one. `playtest stop` ends it.

`start`, `restart`, and `stop` talk to the playtest's own server and client, which only connect when **Load user plugins on playtest** is on. With it off, `playtest start` still starts the playtest but reports that its sessions never connected, and the playtest has to be stopped in Studio.

### Multiplayer tests: `playtest start --players` / `playtest player`

```bash
studio-bridge playtest start --players 2
studio-bridge playtest player list
studio-bridge playtest player add 2
studio-bridge playtest player remove Player2
studio-bridge console exec --target test-place-3f9a-client-player1 'return game.Players.LocalPlayer.Name'
```

`playtest start --players N` starts a multiplayer test: a server and a client per player, each in its own Studio window. Each client's session ID ends in its player's name (`<instance>-client-player1`), so `--context client` alone is ambiguous; pick a client with `--target`. `playtest restart` keeps the player count.

`playtest player list` shows each player with its client session. `add` adds players to a multiplayer test and waits for them to join. `remove` has each player's client leave the test, which closes its window; a player without a connected client session is kicked instead, and its window stays open.

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
| `--timeout` | `5000` | How long to wait for a Studio session to connect, in milliseconds |
| `--verbose` | `false` | Show internal debug output |
| `--remote` | — | Connect to a remote bridge host (`host:port`) |
| `--local` | `false` | Force local mode (skip devcontainer auto-detection) |

### Output

Every command accepts `--format text|json` and `-o <file>`. stdout carries only the result; progress and warnings go to stderr. With `--format json`, failures print `{"success": false, "error": ...}` and exit with code 1, and warnings (an outdated CLI, or a Studio plugin older than the CLI) are kept in the result's `_warnings` field.

### Target Selection

Session IDs are the place name plus a short suffix and the context, like `test-place-a05a-edit`. They stay the same until Studio closes, including across plugin reinstalls. Commands that target a session accept `--target` and `--context`:

- **No flags** — auto-resolves if only one session exists
- **`--target <id>`** — a session ID, an instance ID (`test-place-a05a`), or any unique prefix of one (`test-place`)
- **`--context <ctx>`** — select context within an instance (`edit`, `client`, `server`)

When Studio is in Play mode, a single instance has multiple contexts (Edit + Client + Server). The default is `edit`.

## Testing

```bash
pnpm test              # Unit tests (Vitest, no Studio needed)
pnpm test:watch        # Watch mode
nevermore test --cloud # Jest specs for the plugin, in a Roblox cloud place
pnpm test:integration  # End-to-end smoke test (requires Studio)
```

| Layer | What it tests | Studio? |
|-------|--------------|---------|
| Unit (`pnpm test`) | Protocol, bridge connection, session tracking, command handlers, WebSocket lifecycle | No |
| Plugin (`nevermore test --cloud`) | Plugin modules and action scripts, via the `*.spec.lua` beside them in `templates/studio-bridge-plugin/src/Shared` and `src/commands`, in a real engine built from `test/default.project.json` | No |
| Integration (`pnpm test:integration`) | Full pipeline: rojo build, plugin injection, Studio launch, output capture | Yes |

## Platform Support

| Platform | Studio Location | Plugins Folder |
|----------|----------------|----------------|
| Windows | `%LOCALAPPDATA%\Roblox\Versions\*\RobloxStudioBeta.exe` | `%LOCALAPPDATA%\Roblox\Plugins\` |
| macOS | `/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudioBeta` | `~/Documents/Roblox/Plugins/` |
