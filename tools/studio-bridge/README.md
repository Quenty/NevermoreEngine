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
studio-bridge console exec -f spawn-npc.lua -- Goblin 3
studio-bridge console exec -f load-map.lua --input europe-15m.json.zst -- europe
```

| Option | Alias | Description |
|--------|-------|-------------|
| `--file` | `-f` | Path to a Luau script file |
| `--target` | `-t` | Target session ID |
| `--context` | — | Target context (`edit`, `client`, `server`) |
| `--script-timeout` | — | Cancel the script after this many milliseconds (default: 120000) |
| `--allow-edit` | — | Change Edit even while a playtest of it runs |
| `--input <file>` | — | Send a file with the script, which receives it as a `buffer` in `...` before any args (`local data, region = ...`). Repeat for more files, up to 192 MiB in all |
| `-- <args..>` | — | Passed to the script as `...`, as strings (`local name, count = ...`) |

Output includes everything logged while the script runs, including prints from modules it requires and from threads it starts. A runtime error comes with a traceback. A script that runs past `--script-timeout` is cancelled, so the scripts queued behind it still run. While a playtest is running, `exec` on Edit is refused, since the playtest runs a copy and would not see the change; target the playtest with `--context server` or `--context client` instead.

`--run-as` says where the code runs, and the result says where it ran (`ranAs`, and a `(ran as …)` line when it was not the plugin). Asking for one that is not available fails with the reason:

| `--run-as` | Runs as | `require(game.SomeModule)` | Available |
|---|---|---|---|
| `plugin` | the studio-bridge plugin | a separate copy from the running game's | wherever the plugin is connected |
| `game` | an ordinary `Script` (server) or `LocalScript` (client) the plugin plants for the run | the instance the running game uses | a running playtest's server or client |
| `mcp` | Studio's MCP Assistant sandbox | refused for the game's own modules | wherever Studio's MCP server reaches that Studio; takes no args or `--input` |

Without `--run-as` the code runs in the plugin, or, in a playtest Studio loads no plugins into, as game code in the bridge planted there, which only runs code compiled when the playtest started. A plugin that does load into the playtest replaces that bridge.

### `console logs`

```bash
studio-bridge console logs
studio-bridge console logs --count 100 --direction head
studio-bridge console logs --levels Error Warning
studio-bridge console logs --context server --since-restart
studio-bridge console logs --since 5m
```

| Option | Alias | Description |
|--------|-------|-------------|
| `--count` | `-n` | Number of entries (default: 50) |
| `--direction` | — | `head` or `tail` (default: `tail`) |
| `--levels` | — | Filter by level (`Print`, `Info`, `Warning`, `Error`) |
| `--include-internal` | — | Include internal bridge messages |
| `--since` | — | Only entries since a duration ago (`30s`, `5m`, `2h`, `1d`) or a date |
| `--since-restart` | — | Only entries since the running playtest started |
| `--no-group-repeats` | — | Keep identical consecutive entries separate |

Identical consecutive entries are collapsed into one with a repeat count (`repeats` and `lastTimestamp` in JSON), before `--count` applies, so `-n 20` shows 20 distinct lines. Each playtest DataModel keeps its own log, so `--context server` or `--context client` already reads only the running playtest and `--since-restart` keeps all of it; on Edit, `--since-restart` keeps what was logged since that playtest started.

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

### `explorer find` / `explorer grep`

```bash
studio-bridge explorer find spawn
studio-bridge explorer find Pill Flag --exact --root StarterGui.StoryRouter
studio-bridge explorer find --class BasePart --tag Hazard --root Workspace.Map
studio-bridge explorer grep TakeDamage
studio-bridge explorer grep "^local %w+ = require" --lua-pattern --root ReplicatedStorage
```

`find` lists instances whose name contains the text (case-insensitive; `--exact` for the whole name; give several names to match any of them), narrowed by `--class` (matched with `IsA`, so `BasePart` finds every part) and `--tag`. `grep` prints every script line containing the text as `path:line: text`. It reads open editor tabs, so unsaved edits are searched. Text matches plainly and case-insensitively; `--lua-pattern` and `--case-sensitive` change that.

Both search the whole place by default, skipping Studio's own services such as CoreGui; `--root` narrows the search to a path, and `--limit` (default 200) caps the results, with `truncated` set when there were more.

### `explorer sample`

```bash
studio-bridge explorer sample Pill Island Flag --root StarterGui.StoryRouter.Stage \
  --properties Size,Position,GroupTransparency,Scale \
  --trigger 'require(game.ReplicatedStorage.Story).playIntro()' --duration 0.8s -o samples.csv
studio-bridge explorer sample Health --attributes Current --duration 2s --fps 10
```

Records properties and attributes of instances every frame for `--duration`, and answers with one row per value per frame: `{ t, frame, path, property, value }`. Instances are picked the same way `explorer find` picks them (names, `--root`, `--class`, `--tag`, `--exact`), once, in frame 0.

| Option | Description |
|--------|-------------|
| `--properties` | Properties to record, comma-separated or repeated |
| `--attributes` | Attributes to record, comma-separated or repeated; rows name them `@Name` |
| `--trigger` / `--trigger-file` | Luau to run in frame 0, as `console exec` runs code. Omit both to record passively |
| `--duration` | How long to record: `800ms`, `0.8s`, `2s`; a bare number is seconds. Required |
| `--fps` | Frames to record per second (default: every frame) |
| `--max-frames` | Stop after this many recorded frames (default: 300) |

- `t` is frame time since frame 0 (the sum of frame deltas), not wall time. Frame 0 and the first frame at or past `--duration` are always recorded.
- Values are read with `BindToRenderStep` at `Enum.RenderPriority.Last`, after other render-step code that frame. TweenService moves GUI after that, so a tweened value read at frame `k` is the one drawn in frame `k - 1`. On a playtest's server, which has no render step, it records on Heartbeat.
- Composite values split into a row per component: `Size.X.Scale`, `Size.X.Offset`, `Size.Y.Scale`, `Size.Y.Offset` for UDim2; `.Scale`/`.Offset` for UDim; `.X`/`.Y`/`.Z` for vectors; `.R`/`.G`/`.B` for Color3. A property or attribute an instance lacks is skipped.
- Text output is a short summary; `--format json` gives the rows; `--format csv`, or `-o` ending in `.csv`, writes them as CSV.
- Recording runs in Studio and comes back in one reply at the end. A trigger can change the place, so like `console exec` it is refused on Edit while a playtest runs, unless `--allow-edit`.

### `explorer export` / `explorer import`

```bash
studio-bridge explorer export Workspace.Map Lighting -o map.rbxm
studio-bridge explorer import map.rbxm --parent ServerStorage
```

`export` saves instances as a binary model (`.rbxm`) through `SerializationService`, and writes it with `-o`. `import` inserts a `.rbxm` under `--parent` (default: `Workspace`).

### `viewport screenshot`

```bash
studio-bridge viewport screenshot --output viewport.png
studio-bridge viewport screenshot --region 0,0,640,360 --scale 0.5 -o corner.png
```

| Option | Alias | Description |
|--------|-------|-------------|
| `--output` | `-o` | Write PNG to file |
| `--region` | — | Crop to `x,y,width,height` in viewport pixels |
| `--scale` | — | Scale by this factor after cropping, up to 1 |

Studio reads at most 1024x1024 pixels at a time, so a larger image is scaled down to fit.

### `viewport record`

```bash
studio-bridge viewport record --trigger 'require(game.ReplicatedStorage.Story).playIntro()' \
  --duration 600ms --fps 30 --region 0,0,800,450 --scale 0.5 -o intro
```

Captures the viewport over `--duration`, with the same `--trigger`, `--duration`, `--fps` and `--max-frames` as `explorer sample`, and the same `--region` and `--scale` as `viewport screenshot`. `-o` is a required directory, which gets:

- `frame-000.png` onward, one per capture;
- `manifest.json`, the command's JSON result: each frame's `index`, `t`, `frame` and `file`; how many captures were `requested` and `captured`; `elapsed` and the `captureRate` achieved; and `skipped`, the captures that could not be read and why, when there were any. Times and rates are rounded to milliseconds;
- `sheet.png`, a contact sheet of `--sheet-frames` (default 16, `0` for none) evenly spaced frames. A header gives the counts, rate and duration (`6 of 19 captured · 5.0/s · 1.201s`), and a strip under each frame its time and frame number (`0.268s · f4`), so gaps left by dropped captures show. The column count keeps the sheet near 4:3, so wide strips stack in a column; it is scaled down to fit 2048 pixels each way.

`--region` is checked against the viewport before the trigger runs. While recording it only asks for captures; reading, cropping, scaling and PNG encoding wait until the window is over, and a capture that fails to read is skipped rather than failing the recording. CaptureService accepts about one request every three frames and silently drops the rest, so expect far fewer captures than `--fps` asks for. The manifest has the frames really captured, at the times they show. Each capture shows the frame it was requested in. A playtest's server renders nothing, so recording it is refused; record Edit, or the client with `--context client`.

### `process list`

```bash
studio-bridge process list
```

Lists the connected sessions with their ID, context, place, and state. `--target` and `--context` narrow the list. While a playtest studio-bridge started is running, every session of that Studio shows `Play` (or `Run` without a client).

Below the sessions, a table lists every running Studio process, whether or not its plugin is connected: its pid, how long it has run, its window, the plugin session in it, its id in [Studio's MCP server](#studios-mcp-server), and the folder and place `process launch` opened it with. Studios showing the same place, such as two unsaved `Place1` windows, are told apart by how long each has run: `os.clock()` in Studio is the process's uptime, read through the plugin and through MCP and matched against the start time of each process. `process close` uses the same match when several windows show the session's place. With no session, the summary says whether no Studio is open at all or Studios are open without the plugin, and how long it waited.

The last line reports the MCP server's health. MCP never holds the list up: it waits at most 3 seconds, and under `--watch` each frame shows the latest check while the next one runs, so a stalled server shows up as a stale check rather than a frozen screen. `--no-mcp` skips it.

### `process info`

```bash
studio-bridge process info
```

```text
Session:  test-place-3f9a-edit (edit, user, connected 4m ago)
Mode:     Edit
Playtest: running (multiplayer, 2 players): test-place-3f9a-server, test-place-3f9a-client-player1, test-place-3f9a-client-player2
Place:    test-place.rbxl (PlaceId 0, GameId 0)
Viewport: 849x1003
Window:   pid 31876, open, not focused
Studio:   0.744.0.7441077
Plugin:   6c751ae59131 (up to date)
MCP:      reachable (studio_id 1268b6c6-47aa-4df9-8f3a-0a9ddb0c5f42)
```

Reports on one session: its ID, context and origin; the run mode of its own DataModel; the playtest running in its Studio (mode, player count, and the playtest's sessions, when they are connected); the place; the viewport size; the Studio window, when exactly one window shows it; the Studio version; whether its plugin matches the one this CLI installs; and whether Studio's MCP server can reach it (`--no-mcp` to skip). The two clients of a multiplayer test share a window title, so they report no window.

### `process launch`

```bash
studio-bridge process launch                          # default target of the nearest deploy.nevermore.json
studio-bridge process launch integration.places.hub   # a named target, or one place of it
studio-bridge process launch --place ./build/test.rbxl
studio-bridge process launch --place-id 123 --universe-id 456
```

Without `--place` or `--place-id`, opens the cloud place of a target from the nearest `deploy.nevermore.json` (in the current directory or a parent), so running it in a package or game folder opens that project's place. With no target it uses the config's default (`integration`, then `test`). Outside any `deploy.nevermore.json`, or in one without targets like the repo root's, it opens a new Baseplate from Roblox's template, the same unsaved place the start page's Baseplate gives.

### `process run`

```bash
studio-bridge process run 'print("hello")'
studio-bridge process run --file test.lua --place ./build/test.rbxl -- arg1 arg2
```

Launches Studio on a copy of the place, runs the script there and nowhere else, then closes that Studio. Other open Studios are never used. While the script runs, the launched Studio is a session like any other, so `process list` shows it (origin `managed`) and other commands can target it.

### `process close`

```bash
studio-bridge process close --target test-place
studio-bridge process close integration.places.hub   # the Studio showing a deploy.nevermore.json target
studio-bridge process close --all                    # every running Studio, connected or not
```

Closes the Studio process showing the session's place, found by its window title, or for a cloud place by the place id Studio was launched with. Given a `deploy.nevermore.json` target instead, closes the Studio showing that target's place, whether or not its plugin is connected. Studio is closed without saving, so no dialog waits on someone to click it. Pass `--ask-to-save` to let Studio prompt instead; if it is still open after that, the command says so. When several windows show the same place, pick one with `--pid`.

### `playtest run` / `playtest start` / `playtest restart` / `playtest stop`

```bash
studio-bridge playtest run 'return #game:GetService("Players"):GetPlayers()'
studio-bridge playtest run --context client 'return game:GetService("Players").LocalPlayer.Name'
studio-bridge playtest run --file spawn-test.lua -- Goblin 3
studio-bridge playtest run --file load-map.lua --input europe-15m.json.zst -- europe
studio-bridge playtest start --mode run
studio-bridge console exec --context server 'print("in the playtest")'
studio-bridge playtest restart
studio-bridge playtest stop
```

Starts a playtest through `StudioTestService` in the open Studio. `--mode play` (the default) runs a server and a client with a player; `--mode run` runs only the server.

`playtest run` executes the code in a fresh playtest's server, returns its output and values like `console exec`, then stops the playtest. It takes `--input` like `console exec`. In play mode it waits for the player to join first. It works whatever Studio's **Load user plugins on playtest** setting says (see below). `--context client` runs the code in the playtest's client instead.

`playtest start` leaves the playtest running, so other commands can target it with `--context server` or `--context client`. `playtest restart` stops it and starts a new one in the same mode, picking up code changed since it started; with none running, it starts one. `playtest stop` ends it.

A playtest's sessions are the studio-bridge plugin, which Studio only loads into a playtest with **Load user plugins on playtest** on. With it off, the edit session plants the same client into the playtest as ordinary scripts: a Script for the server and, in play mode, a LocalScript that every player's client runs, so the server and client sessions still connect and `start`, `restart`, `stop`, `playtest player`, `console logs` and the other actions all work. Without plugin permissions those sessions can't compile code, so they only run the code `playtest run` gave them when the playtest started, and `console exec` with new code asks for the setting. With the setting on, nothing is planted, and the plugin is the playtest's sessions.

Playtests whose sessions are the plugin need the current plugin (`studio-bridge plugin install`), since those sessions register with the playtest's id.

### Multiplayer tests: `playtest start --players` / `playtest player`

```bash
studio-bridge playtest start --players 2
studio-bridge playtest player list
studio-bridge playtest player add 2
studio-bridge playtest player remove Player2
studio-bridge console exec --target test-place-3f9a-client-player1 'return game.Players.LocalPlayer.Name'
```

`playtest start --players N` starts a multiplayer test: a server and a client per player, each in its own Studio window. Each client's session ID ends in its player's name (`<instance>-client-player1`), so `--context client` alone is ambiguous; pick a client with `--target`. `playtest restart` keeps the number of players in the test, counting any added since it started. Multiplayer tests need the current plugin (`studio-bridge plugin install`), and `--players` refuses to start with an older one.

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

Every command accepts `--format text|json` and `-o <file>`. Commands with tabular results (`explorer sample`) also take `--format csv`, which is the default when `-o` ends in `.csv`. For `viewport record`, `-o` is a required directory. stdout carries only the result; progress and warnings go to stderr. With `--format json`, failures print `{"success": false, "error": ...}` and exit with code 1, and warnings (an outdated CLI, or a Studio plugin older than the CLI) are kept in the result's `_warnings` field.

A single reply from Studio can carry up to 256 MiB. A larger one, such as a script returning a huge string, fails that request with `RESULT_TOO_LARGE` and leaves the connection and every other request alone.

### Target Selection

Session IDs are the place name plus a short suffix and the context, like `test-place-a05a-edit`. They stay the same until Studio closes, including across plugin reinstalls. Commands that target a session accept `--target` and `--context`:

- **No flags** — auto-resolves if only one Studio is connected. With several, uses the one that has a place of the nearest `deploy.nevermore.json` open (and says which), so a command run in a package or game folder reaches that project's Studio.
- **`--target <id>`** — a session ID, an instance ID (`test-place-a05a`), or any unique prefix of one (`test-place`)
- **`--context <ctx>`** — select context within an instance (`edit`, `client`, `server`)

When Studio is in Play mode, a single instance has multiple contexts (Edit + Client + Server). The default is `edit`.

## Studio's MCP server

`src/roblox-mcp/` reaches Studio through `StudioMCP.exe`, the MCP server Roblox ships with Studio, for things the plugin can't do or when it isn't running. All MCP knowledge stays in that folder; commands call `tryExecuteLuauAsync`, `tryCallStudioToolAsync` or `tryListStudiosAsync` with the bridge's usual `--target` and context. They never throw, run under a strict deadline, and return a `reason` when MCP is unavailable, finds no Studio, fails or times out. Windows only.

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

## Working on this package

- [docs/playtest-bridge.md](docs/playtest-bridge.md): how a playtest gets a server session without Studio loading plugins into it, and what an ordinary playtest Script can and can't do.

## Platform Support

| Platform | Studio Location | Plugins Folder |
|----------|----------------|----------------|
| Windows | `%LOCALAPPDATA%\Roblox\Versions\*\RobloxStudioBeta.exe` | `%LOCALAPPDATA%\Roblox\Plugins\` |
| macOS | `/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudioBeta` | `~/Documents/Roblox/Plugins/` |
