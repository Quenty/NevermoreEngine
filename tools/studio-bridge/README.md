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

**Host** — A single process binds port 38741, accepts plugin and client connections, and tracks sessions. A command that finds no host starts `studio-bridge serve` in the background and connects to it (see [`serve`](#serve)); with `--no-autohost` it hosts in its own process instead.

**Plugin** — A persistent Roblox Studio plugin that discovers the host by polling `GET /health`, then connects via WebSocket. Survives Studio restarts. Actions are pushed dynamically over the wire on connect.

**Client** — CLI commands connect as clients when a host is already running. Actions are relayed through the host to the target plugin.

## Quick Start

```bash
# 1. Install the persistent Studio plugin (one-time)
studio-bridge plugin install

# 2. Optional: start a bridge host (any command starts one in the background otherwise)
studio-bridge serve

# 3. Open Roblox Studio — the plugin connects automatically

# 4. Execute Luau code
studio-bridge console exec 'print("hello from the bridge")'

# 5. Inspect the DataModel
studio-bridge explorer inspect Workspace --children
```

## CLI Commands

```
studio-bridge <command> [options]

Execution:
  console <command>      Execute code and view logs
  explorer <command>     Inspect, search and modify the DataModel
  viewport <command>     Screenshots and camera control
  playtest <command>     Control play test sessions

Infrastructure:
  process <command>      Open and manage Studio
  plugin <command>       Manage the bridge plugin
  serve                  Start the bridge server
  linux <command>        Linux/Wine environment management
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

### `explorer inspect`

```bash
studio-bridge explorer inspect                                   # the place's services
studio-bridge explorer inspect Workspace --children
studio-bridge explorer inspect Workspace.SpawnLocation --children --depth 3
studio-bridge explorer inspect '_Index."jsdotlua_shared@17.2.1".shared' --children
studio-bridge explorer inspect Terrain --properties
studio-bridge explorer inspect --selection --attributes
```

Reads one instance, picked out the way `explorer find` picks them (a query, `--selector` and `--root`), or with `--selection`, the one selected in Studio. The query must match exactly one instance; when it matches several, `inspect` lists up to 20 of them and asks for a narrower query. A query of one name prefers the instance with exactly that name (`Terrain` over `TerrainUtils`). With no query it shows the place's services.

`--properties` lists every readable property, sorted by name, one line each: `Size: 4, 1, 2`, `Color: 163, 162, 165`, `CFrame: pos 6, 4, 0  rot 0, 90, 0`. Colors read 0-255 as in Studio. In JSON each property and attribute is `{ name, text, value }`, with `value` holding the components by name (`{ "X": 4, "Y": 1, "Z": 2 }`).

| Option | Description |
|--------|-------------|
| `--children` | Include direct children |
| `--descendants` | Include descendants, 10 levels down |
| `--depth` | Levels of descendants to include (default: 0) |
| `--properties` | Include every readable property, sorted by name |
| `--attributes` | Include instance attributes |
| `--selection` | Inspect the instance selected in Studio |

`explorer query` still runs as an old name for `inspect`.

### `explorer find` / `explorer grep`

```bash
studio-bridge explorer find spawn
studio-bridge explorer find 'is:BasePart tag:Hazard' --root Workspace.Map
studio-bridge explorer find '(Pill or Flag) StoryRouter.**'
studio-bridge explorer find 'Anchored=false Size > "10, 1, 10"'
studio-bridge explorer find --selector 'Model > BasePart' --root Workspace
studio-bridge explorer find is:ModuleScript --grep TakeDamage
studio-bridge explorer grep TakeDamage
studio-bridge explorer grep "^local %w+ = require" --lua-pattern --root ReplicatedStorage
studio-bridge explorer grep TakeDamage --query 'Combat.**'
```

`find` lists the instances that match everything it is given:

| Selection | Description |
|--------|-------------|
| `query` (positional) | [Roblox Explorer search syntax](https://create.roblox.com/docs/studio/explorer#search-methods). Words given unquoted are joined with spaces, so quote the query when it has quotes or parentheses |
| `--selector` | Passed as it is to `Instance:QueryDescendants` from the root. Fails clearly where Studio lacks the API |
| `--grep` | Only scripts whose source contains the text, matched as `grep` matches it (`--lua-pattern`, `--case-sensitive`) |
| `--root` | What to search under: a full path from `game` (`Workspace.Map`), or any query that picks out exactly one instance (`_Index`, `"pkg@1.2.3"`), failing as `inspect` does when none or several match. Quote a name with dots in it |

The query syntax, as the Explorer's search box reads it:

| Query | Matches |
|--------|-------------|
| `spawn`, `"Red Spawn"` | Names containing the text, case-insensitively |
| `is:BasePart` | Instances of the class or a subclass (`IsA`; case-sensitive) |
| `tag:Hazard`, `tag:"Light Source"` | Instances with the CollectionService tag |
| `Anchored=true`, `Health > 50`, `Transparency ~= 0.5` | A property compared with `=` (or `==`), `~=`, `<`, `>`, `<=`, `>=`. Text and enums match partially, ignoring case and spaces (`Material = plas`); numbers and booleans exactly |
| `Position.X = 1`, `Color.R > 120` | A field of a property; colors read 0-255 |
| `Size > "20, 5, 20"`, `Color = "255, 0, 0"` | A whole Vector3, Vector2, Color3, UDim or UDim2, every component compared |
| `Cart.Wheel`, `Cart.*`, `Cart.*.Trim`, `Cart.**`, `Cart.**.Trim` | Paths of whole names, matched anywhere in the place; `*` is one instance, `**` any number |
| `_Index."pkg@1.2.3".pkg` | A quoted segment is one whole name, dots and all |
| `a b`, `a and b`, `a or b`, `(a or b) c` | Every term (a space is an `and`), either side, grouping; `and` binds tighter than `or` |

`find` prints the matches as a tree, the way Studio's Explorer shows them, with the class after each name (`Door (Part)`) and the summary naming a class every match shares (`601 ModuleScripts among 813 instances`). `grep` prints each script with a matching line the same way, with every matching line under it as `line: text`. It searches unsaved editor text too. Text matches plainly and case-insensitively; `--lua-pattern` and `--case-sensitive` change that. `--query` (the same syntax as `find`'s), `--selector` and `--root` narrow the scripts it searches.

Both search the whole place by default, skipping Studio's own services such as CoreGui; `--root` narrows the search to a path, and `--limit` (default 200) caps the results, with `truncated` set when there were more. Both keep counting past the limit, so the summary says how many match in all (`200 of 1,532 matches among 11,604 instances`, `3 of 1,954 matching lines in 533 of 602 scripts`), as does `total` in JSON (and `scripts` for `grep`).

### `explorer sample`

```bash
studio-bridge explorer sample                         # what changes in the place over 2s
studio-bridge explorer sample --selection             # what changes under the Studio selection
studio-bridge explorer sample --watch                 # print the place's changes live until Ctrl-C
studio-bridge explorer sample Door --watch            # print Door's changes live until Ctrl-C
studio-bridge explorer sample 'Pill or Island or Flag' --root StarterGui.StoryRouter.Stage   --properties Size,Position,GroupTransparency,Scale   --trigger 'require(game.ReplicatedStorage.Story).playIntro()' --duration 0.8s -o samples.csv
```

Records how properties and attributes of instances change over `--duration` (default 2s), as rows of `{ kind, t, frame, path, ... }`. Every argument narrows the default:

- **Instances:** picked the same way `explorer find` picks them (a query, `--selector` and `--root`), or with `--selection`, what is selected in Studio and everything under it. With none of these it watches the whole place. Instances added or removed get `added`/`removed` rows (marked `+` / `-` in text).
- **Values:** without `--properties` or `--attributes`, it records whatever changes, as `value` rows. With them, those values get a row every frame, for up to 100 instances.
- **Starting values:** a scope of up to 100 instances gets a starting value row (frame 0) for each component that changes. A larger one prints a value's first change as just its new value (`BrickColor  → Really red`).
- **Noise:** recording whatever changes leaves out values the engine updates constantly, such as a part's `AssemblyLinearVelocity` and `Position`, and the current camera's `CFrame`. Naming one with `--properties` records it.
- **Rollups:** when more than 200 changes land in one recorded frame (or, under `--watch`, one poll), they come back as `rollup` rows counted per ancestor and property, with `count`, `instances` and an `example`. Text prints `0.50s  Workspace.Map.Cars.** (48 instances)  CFrame  ×1,920 changes`, where the path works as a query to see each change.
- **Cap:** a batch recording keeps at most 10,000 rows; past that, `omitted` counts the rest and the summary says so.

| Option | Description |
|--------|-------------|
| `--selection` | Watch the instances selected in Studio and their descendants instead of the whole place. Opt-in, since Studio nearly always has something selected |
| `--properties` | Properties to record every frame, comma-separated or repeated |
| `--attributes` | Attributes to record every frame, comma-separated or repeated; rows name them `@Name` |
| `--trigger` / `--trigger-file` | Luau to run in frame 0, as `console exec` runs code. Omit both to record passively |
| `--duration` | How long to record: `800ms`, `0.8s`, `2s`; a bare number is seconds. Default: 2s, or until Ctrl-C under `--watch` |
| `--fps` | Frames to record per second (default: every frame) |
| `--max-frames` | Stop after this many recorded frames (default: 300; no limit under `--watch`) |
| `--watch` | Print changes as they happen, until Ctrl-C or `--duration` |

- `t` is frame time since frame 0 (the sum of frame deltas), not wall time. Frame 0 and the first frame at or past `--duration` are always recorded.
- A tweened value read at frame `k` is the one drawn in frame `k - 1`.
- Composite values split into a row per component: `Size.X.Scale`, `Size.X.Offset` and so on for UDim2; `.X`/`.Y`/`.Z` for vectors; `.R`/`.G`/`.B` (0-255) for Color3; `.Position.X` and `.Orientation.X` (degrees) for CFrame. `--properties Size.X.Scale` records just that component.
- Text output shows each instance that changed, with a line per property from its starting value to its last:

  ```
  Workspace/Doors/
    Door1 (Part)
      @Open               false → true  0.07s
      CFrame.Orientation  0, 0, 0 → 0, 90, 0  0.07s–0.53s, 8 steps
      Color               163, 162, 165 → 255, 0, 0  0.07s–0.53s, 8 steps
    + Door4 (Part, 0.12s)
  ```
 `--format json` gives the rows, ordered by frame, then path, then property, each with a `kind` of `value`, `added`, `removed` or `rollup`, plus `scope` (`query`, `selection` or `place`), `watched` (the instance count), `omitted`, and `refs`, the InstanceRef of each instance the rows name, by `path`; `--format csv`, or `-o` ending in `.csv`, writes the rows as CSV with the columns `kind,t,frame,path,property,value,count,instances,example`.
- Under `--watch`, text prints each poll's changes under the time of its latest change (`3.07s`), JSON a row per line, CSV a header and then rows. `--watch` is CLI only.
- Like `console exec`, it is refused on Edit while a playtest runs, unless `--allow-edit`.

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

An image larger than 1024x1024 is scaled down to fit.

During a Play-mode playtest the screenshot comes from Studio's MCP server instead, as a lossy JPEG of what the Studio window shows, with `source` set to `studioMcp`. A Run-mode playtest can't be captured.

### `viewport record`

```bash
studio-bridge viewport record --trigger 'require(game.ReplicatedStorage.Story).playIntro()' \
  --duration 600ms --fps 30 --region 0,0,800,450 --scale 0.5 -o intro
```

Captures the viewport over `--duration`, with the same `--trigger`, `--duration`, `--fps` and `--max-frames` as `explorer sample`, and the same `--region` and `--scale` as `viewport screenshot`. `-o` is a required directory, which gets:

- `frame-000.png` onward, one per capture;
- `manifest.json`, the command's JSON result: each frame's `index`, `t`, `frame` and `file`; how many captures were `requested` and `captured`; `elapsed` and the `captureRate` achieved; and `skipped`, the captures that could not be read and why, when there were any. Times and rates are rounded to milliseconds;
- `sheet.png`, a contact sheet of `--sheet-frames` (default 16, `0` for none) evenly spaced frames, each labelled with its time and frame number (`0.268s · f4`).

Studio captures about one frame in three, so expect far fewer captures than `--fps` asks for; the manifest has the frames really captured, at the times they show. Recording is refused during a playtest; use Edit, or take single frames with `viewport screenshot`.

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
Mode: Edit, Place: test-place.rbxl (0)
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

A playtest's sessions are the studio-bridge plugin, which Studio only loads into a playtest with **Load user plugins on playtest** on. With it off, the edit plugin plants a copy of itself into the playtest as ordinary scripts: a Script for the server and, in play mode, a LocalScript that every player's client runs, so the server and client sessions still connect and `start`, `restart`, `stop`, `playtest player`, `console logs` and the other actions all work. Without plugin permissions those sessions can't compile code, so they only run the code `playtest run` gave them when the playtest started, and `console exec` with new code asks for the setting. With the setting on, nothing is planted, and the plugin is the playtest's sessions.

Playtests need the current plugin: plugin sessions register with the playtest's id, and a planted session is a copy of the edit plugin. An outdated one is handled as on any other command (see [`plugin install`](#plugin-install--plugin-uninstall)).

### Multiplayer tests: `playtest start --players` / `playtest player`

```bash
studio-bridge playtest start --players 2
studio-bridge playtest player list
studio-bridge playtest player add 2
studio-bridge playtest player remove Player2
studio-bridge console exec --target test-place-3f9a-client-player1 'return game.Players.LocalPlayer.Name'
```

`playtest start --players N` starts a multiplayer test: a server and a client per player, each in its own Studio window. Each client's session ID ends in its player's name (`<instance>-client-player1`), so `--context client` alone is ambiguous; pick a client with `--target`. `playtest restart` keeps the number of players in the test, counting any added since it started. Multiplayer tests need the current plugin, like any playtest.

`playtest player list` shows each player with its client session. `add` adds players to a multiplayer test and waits for them to join. `remove` has each player's client leave the test, which closes its window; a player without a connected client session is kicked instead, and its window stays open.

### `plugin install` / `plugin uninstall`

```bash
studio-bridge plugin install
studio-bridge plugin uninstall
```

`plugin install` builds the plugin and installs it into Studio's plugins folder. Studio hot-reloads it, and `plugin install` waits up to 15 seconds for each connected Studio to reconnect with the new version, then reports each one (in JSON, `sessions[].status` is `reloaded`, `current` or `not-reloaded`):

```
Installed studio-bridge plugin c3d4e5.
  ✓ MapNotifications reloaded
  ✗ Place1 did not reload within 15s; reopen it in Studio to load the new plugin
```

When a Studio runs an outdated plugin, a command that needs it:

- asks a person at a terminal (stdin and stderr are TTYs, no `--format json`) whether to update it, and on yes installs it, waits for that Studio to reload it, and goes on;
- updates it without asking with `--update-plugin`;
- otherwise fails with `"code": "PLUGIN_OUTDATED"` and a `fix` saying to run `studio-bridge plugin install` and retry, so an agent can fix it itself.

A playtest's sessions keep their plugin until the playtest restarts, and a Studio behind `--remote` needs the install on its own machine.

### `serve`

```bash
studio-bridge serve
studio-bridge serve --port 9000
studio-bridge serve --idle-timeout 10m
```

A `serve` you start runs until you stop it. Without one, a command starts `serve --idle-timeout 10m` in the background and connects to it, so later commands take about a second instead of about ten. That host exits after 10 minutes with no command using it, or 2 minutes with no Studio connected. It logs to `host-<port>.log` in `<temp>/studio-bridge`; `process list` shows its pid and log.

For CI, or anywhere nothing should outlive the command, `--no-autohost` or `STUDIO_BRIDGE_NO_AUTOHOST=1` keeps the host inside the command.

A command that finds a host from an older studio-bridge build replaces it when no other command is using it, and otherwise warns.

## Global Options

| Option | Default | Description |
|--------|---------|-------------|
| `--timeout` | `5000` | How long to wait for a Studio session to connect, in milliseconds |
| `--verbose` | `false` | Show internal debug output |
| `--remote` | — | Connect to a remote bridge host (`host:port`) |
| `--local` | `false` | Force local mode (skip devcontainer auto-detection) |
| `--no-autohost` | — | With no host running, host in this command instead of starting a background `serve` (also `STUDIO_BRIDGE_NO_AUTOHOST=1`) |

### Output

Every command accepts `--format text|json` and `-o <file>`. Commands with tabular results also take `--format csv`, which is the default when `-o` ends in `.csv`. The columns match the JSON fields:

| Command | CSV columns |
|---------|-------------|
| `explorer find` | `path,className` |
| `explorer grep` | `path,className,line,text` |
| `explorer inspect` | `path,property,value` with `--properties` or `--attributes` (attributes as `@Name`), otherwise `path,className` |
| `explorer sample` | `kind,t,frame,path,property,value,count,instances,example` |
| `console logs` | `timestamp,level,body,repeats` |
| `process list` | `sessionId,context,placeName,state,pid` |

For `viewport record`, `-o` is a required directory. stdout carries only the result; progress and warnings go to stderr. Text output ends with a one-line summary, dim. For commands whose text is the payload you'd pipe (`console exec`, `console logs`, `process run`, `playtest run`), stdout carries only that payload and the summary goes to stderr, so `studio-bridge console exec 'return 1+1' | cat` prints `2`. With `--format json`, failures print `{"success": false, "error": ...}`, with a `code` when there is one (`INVALID_PAYLOAD` for a bad query, say), and exit with code 1, and warnings (an outdated CLI, or a Studio plugin older than the CLI) are kept in the result's `_warnings` field.

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
nevermore test --cloud # Jest specs for the actions, in a Roblox cloud place
pnpm test:integration  # End-to-end smoke test (requires Studio)
```

| Layer | What it tests | Studio? |
|-------|--------------|---------|
| Unit (`pnpm test`) | Protocol, bridge connection, session tracking, command handlers, WebSocket lifecycle | No |
| Actions (`nevermore test --cloud`) | Action scripts, via the `*.spec.lua` beside them in `src/commands`, in a real engine built from `test/default.project.json` | No |
| Plugin (`nevermore test --cloud` in `plugins/studio-bridge-plugin`, at the repo root) | The plugin's own modules, via their specs | No |
| Integration (`pnpm test:integration`) | Full pipeline: rojo build, plugin injection, Studio launch, output capture | Yes |

## Working on this package

- [docs/playtest-bridge.md](docs/playtest-bridge.md): how a playtest gets a server session without Studio loading plugins into it, and what an ordinary playtest Script can and can't do.
- The Studio plugin is its own package, `plugins/studio-bridge-plugin`; see its README. Run `studio-bridge plugin install` after editing it.
- Check what the published package ships with `npm pack --dry-run`.

## Platform Support

| Platform | Studio Location | Plugins Folder |
|----------|----------------|----------------|
| Windows | `%LOCALAPPDATA%\Roblox\Versions\*\RobloxStudioBeta.exe` | `%LOCALAPPDATA%\Roblox\Plugins\` |
| macOS | `/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudioBeta` | `~/Documents/Roblox/Plugins/` |
