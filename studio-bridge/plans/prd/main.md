# Studio-Bridge Persistent Sessions PRD

## Problem Statement

Studio-bridge currently requires launching a fresh Roblox Studio instance for every interaction. The `exec` and `run` commands each spin up a new Studio process, inject a temporary plugin, wait for it to connect, execute a single script, and tear everything down. This takes 15-30 seconds per invocation on a fast machine and over a minute on slower hardware. The `terminal` command partially addresses this by keeping a single Studio session alive for multiple executions, but it still requires launching Studio from scratch when the terminal starts.

There is no way to connect to a Studio session that is already running. Developers who keep Studio open all day -- the overwhelming majority of Roblox developers -- cannot use studio-bridge without closing and relaunching Studio through the CLI. This makes the tool impractical for iterative workflows and completely unusable for AI agents that need to inspect, query, or interact with a running game.

The lack of persistent sessions also prevents building higher-level capabilities. There is no way to ask "what state is Studio in?", capture a screenshot of the viewport, query the DataModel for instances and properties, or tail the output log of a running session. These are all things that require a persistent, discoverable connection to an already-running Studio.

This PRD defines the requirements for persistent session support: the ability to discover running Studio sessions, connect to them, and interact with them through a rich set of capabilities beyond script execution.

## User Stories

### Developer working in Studio

> As a Roblox developer with Studio already open, I want to run a Luau script in my existing Studio session from the command line, so that I don't have to relaunch Studio every time I want to test something.

> As a developer debugging a problem, I want to query the DataModel from the terminal to inspect instance properties and service state, so that I can understand what's happening without adding print statements and re-running.

> As a developer working on UI, I want to capture a screenshot of the Studio viewport from the command line, so that I can quickly verify visual changes without switching windows.

### AI agent using MCP

> As an AI coding agent connected via MCP, I want to discover all running Studio sessions and connect to one, so that I can execute Luau code and inspect results on the user's behalf.

> As an AI agent, I want to query the DataModel to understand the current state of the game (what instances exist, what properties they have, what services are loaded), so that I can provide contextually relevant assistance.

> As an AI agent, I want to capture a screenshot to see what the user sees in the viewport, so that I can debug visual issues or verify that a UI change looks correct.

> As an AI agent, I want to check whether Studio is in Edit mode, Play mode, or Paused, so that I can decide whether to execute code in the command bar context or the running game context.

### Developer managing multiple sessions

> As a developer working on multiple places simultaneously, I want to list all running Studio sessions and choose which one to interact with, so that I can target the right session without ambiguity.

> As a developer, I want studio-bridge to remember which session I was last connected to, so that I don't have to specify a session ID every time.

## Feature Requirements

### F1: Session Discovery

Users must be able to list all running Studio sessions that have the studio-bridge plugin active.

A single Roblox Studio instance can produce multiple simultaneous sessions. The Edit plugin instance is always running and connected to the bridge host. When a developer enters Play mode, Studio creates two additional plugin instances: one for the simulated server and one for the simulated client. The edit instance continues running unchanged -- it is never stopped or restarted by Play mode transitions. Each of the 3 concurrent plugin instances has its own WebSocket connection to the bridge host. They share the same **instance ID** but receive distinct **session IDs** and report different **contexts**.

**Instance**: A group of sessions originating from the same Studio installation. Sessions within an instance share an `instanceId` (a stable identifier stored in plugin settings, unique per Studio installation). An instance always has 1 session for the Edit context (which runs continuously), and up to 3 sessions total when the developer enters Play mode (the existing Edit session plus 2 new sessions for Client and Server).

**Session context** (`SessionContext`): One of `edit`, `client`, or `server`. The `edit` context is always present. The `client` and `server` contexts appear only while Studio is in Play mode and disappear when the developer stops the session.

Each session entry must include:
- **Session ID** -- a stable identifier for the session (not a PID; survives Studio restarts if the plugin reconnects)
- **Instance ID** -- the grouping key that identifies which Studio installation this session belongs to. All sessions from the same Studio instance share this value.
- **Context** -- the session context: `edit`, `client`, or `server`
- **Origin** -- how the session was created: `user` (developer opened Studio manually; persistent plugin connected on its own) or `managed` (studio-bridge launched Studio via `exec`, `run`, `terminal`, or `launch`). This field is critical for both humans and AI agents: it determines cleanup behavior (managed sessions are killed on exit; user sessions are left running) and communicates intent (a `user` session belongs to the developer; a `managed` session was created by tooling and can be safely torn down).
- **Place name** -- the human-readable name of the open place (e.g., "TestPlace" or "My Game")
- **Place file path** -- the file path of the `.rbxl` file, if available
- **Place ID** -- the Roblox place ID, if the place has been published
- **Game ID** -- the Roblox universe/game ID, if applicable
- **Connection status** -- whether the session is currently connected, was connected but dropped, or is connecting
- **Uptime** -- how long the session has been connected

The session list must update in real time when sessions connect or disconnect. When no sessions are available, the CLI must clearly indicate this rather than hanging or timing out silently.

### F2: Studio State

Users must be able to query the current state of a Studio session.

Each session context has its own independent state. The Edit context is always present and reflects the editing DataModel. The Client and Server contexts only exist while Studio is in Play mode -- they appear when the developer presses Play and disappear when they press Stop. Querying state on a Client or Server context while Studio is not in Play mode is an error.

The state response must include:
- **Context** -- which context this state belongs to (`edit`, `client`, or `server`)
- **Run mode** -- Edit, Play (Client), Play (Server), Play (Paused), or Run
- **Place name** -- the name of the currently open place
- **Place ID** -- the Roblox place ID, if the place has been published
- **Game ID** -- the Roblox universe/game ID, if applicable

State must be queryable both as a one-shot request and as a subscription (for agents that want to react to state changes). The plugin must detect state transitions (e.g., the user pressing Play or Stop) and report them without polling. When the developer enters or exits Play mode, the appearance and disappearance of Client and Server sessions must be reported as session lifecycle events (connect/disconnect), not as state changes on the Edit session.

### F3: Screenshots

Users must be able to capture a screenshot of the Studio 3D viewport.

Requirements:
- Capture must use Roblox's `CaptureService` API (or equivalent) to get the actual rendered viewport, not a window screenshot
- The image must be returned as a file path to a PNG on disk (written to a temp directory)
- The CLI must print the file path to stdout so it can be consumed by scripts and pipelines
- For MCP consumers, the image must be returned as base64-encoded data in the tool response
- Capture must work in both Edit and Play modes
- Capture must fail gracefully with a clear error if the viewport is not available (e.g., Studio is minimized on some platforms)

### F4: Output Logs

Users must be able to retrieve and follow the output log of a connected Studio session.

Three modes:
- **Tail** -- show the last N lines of output (default: 50)
- **Head** -- show the first N lines captured since the plugin connected
- **Follow** -- stream new output lines in real time until interrupted (Ctrl+C)

Requirements:
- The plugin must buffer output logs so that lines generated before the CLI connects are still available (up to a configurable ring buffer size, default: 1000 lines)
- Each log line must include its timestamp and level (Print, Info, Warning, Error)
- The follow mode must support optional level filtering (e.g., show only Warnings and Errors)
- Internal `[StudioBridge]` messages must be filtered out by default (with a `--all` flag to include them)

### F5: DataModel Queries

Users must be able to query the Roblox DataModel to inspect instances, properties, attributes, and services.

The query system must support:
- **Instance lookup by path** -- e.g., `Workspace.SpawnLocation` or `ReplicatedStorage.Modules.MyModule`
- **Property reading** -- get the value of a named property on an instance (e.g., `Workspace.SpawnLocation.Position`)
- **Attribute reading** -- get the value of a named attribute on an instance
- **Children listing** -- list all children of an instance, with their ClassName and Name
- **Service listing** -- list all services currently loaded in the DataModel
- **FindFirstChild / FindFirstDescendant** -- find instances by name, optionally recursive

The query expression format must be a simple dot-separated path (e.g., `Workspace.Camera.CFrame`), not raw Luau. The plugin translates this into the appropriate API calls and returns structured JSON, not stringified output. This is intentionally more constrained than `exec` -- it provides structured, predictable output suitable for programmatic consumption.

The response for an instance query must include:
- **ClassName** -- the Roblox class name
- **Name** -- the instance name
- **Properties** -- a selected set of commonly useful properties (at minimum: Name, ClassName, Parent path)
- **Children count** -- how many children the instance has

Property values must be serialized to JSON-compatible types. CFrames, Vector3s, Color3s, and other Roblox types must have a consistent string or object representation.

### F6: Script Execution (Adaptation)

The existing `exec` and `run` commands must be adapted to work with persistent sessions and the multi-context session model.

#### Session Resolution Cascade

Session resolution is a two-step process: first resolve the **instance**, then resolve the **context** within that instance.

**Step 1: Instance resolution**
- When `--session <session-id>` is provided, use the session directly (skip context resolution -- the session already identifies a specific context).
- When no `--session` is provided and exactly one instance is connected, select that instance automatically.
- When no `--session` is provided and multiple instances are connected, the CLI must list them and prompt the user to choose (or error in non-interactive mode).
- When no instances are connected, the current behavior (launch a new Studio) must be preserved as a fallback.

**Step 2: Context resolution** (within the selected instance)
- When `--context <context>` is provided, use the session matching that context. Error if the requested context is not available (e.g., `--context server` when Studio is in Edit mode).
- When no `--context` is provided and the instance has only one session (Edit mode), select it automatically.
- When no `--context` is provided and the instance has multiple sessions (Play mode), default to the **Edit** context. Edit is the safest default: it is always present, and executing code there does not interfere with the running game simulation.

This means the zero-flag happy path (`studio-bridge exec 'print("hi")'`) resolves to: sole instance, Edit context. Targeting a specific Play mode context requires the explicit `--context server` or `--context client` flag.

#### Requirements

- When a session ID is provided, `exec` and `run` must connect to the existing session instead of launching a new Studio instance
- Instance and context resolution must follow the cascade described above
- The `--context` flag (`edit`, `client`, or `server`) must be accepted on `exec`, `run`, and `terminal` commands
- Consumers can target any context independently -- for example, executing on the Server context to inspect server state while separately executing on the Client context to inspect client state
- The `terminal` command must also accept a session ID or `--context` flag to attach to a specific context within an existing session

### F7: MCP Integration

All capabilities (F1-F6) must be exposed as MCP (Model Context Protocol) tools so that AI agents can use them.

Tools to expose:
- `studio_sessions` -- list all connected sessions (maps to F1)
- `studio_state` -- get the state of a session (maps to F2)
- `studio_screenshot` -- capture a viewport screenshot, returned as base64 (maps to F3)
- `studio_logs` -- retrieve log output (maps to F4)
- `studio_query` -- query the DataModel (maps to F5)
- `studio_exec` -- execute a Luau script (maps to F6)

MCP requirements:
- The MCP server must run as a long-lived process (not spawn-per-request)
- The MCP server must share session state with the CLI (if a CLI terminal session is connected, MCP must see it too)
- Tool responses must use structured JSON, not formatted text
- Errors must use MCP error codes, not process exit codes
- The MCP server must be registerable as an MCP tool provider (e.g., in Claude Code's MCP configuration)

## CLI Interface Design

### Top-Level Commands

```
studio-bridge sessions                        List all connected Studio sessions
studio-bridge connect <session-id>            Connect to an existing session (interactive)
studio-bridge state [session-id]              Get Studio state (run mode, place info)
studio-bridge screenshot [session-id]         Capture a viewport screenshot
studio-bridge logs [session-id]               Retrieve output logs
studio-bridge query <expression> [session-id] Query the DataModel
studio-bridge exec <code> [session-id]        Execute inline Luau code
studio-bridge run <file> [session-id]         Execute a Luau script file
studio-bridge terminal [session-id]           Interactive REPL mode
```

When `[session-id]` is optional and omitted, the CLI uses the session resolution cascade (see F6): auto-select the sole instance, default to the Edit context. A `--session` / `-s` flag is also accepted as an alternative to the positional argument.

**Context targeting**: Commands that interact with a session (`state`, `screenshot`, `logs`, `query`, `exec`, `run`, `terminal`) accept a `--context` / `-c` flag with values `edit`, `client`, or `server`. This selects which plugin context within an instance to target. When omitted, defaults to `edit`.

### `studio-bridge sessions`

Sessions are grouped by instance. Each instance represents a single Roblox Studio installation. Within an instance, sessions are listed by context.

```
$ studio-bridge sessions
  Instance abc12345 (user) — TestPlace.rbxl [PlaceId: 1234567890]
    SESSION ID                             CONTEXT    STATE      CONNECTED
    a1b2c3d4-e5f6-7890-abcd-ef1234567890  edit       Edit       2m 30s

  Instance def67890 (managed) — MyGame.rbxl [PlaceId: 9876543210]
    SESSION ID                             CONTEXT    STATE      CONNECTED
    f9e8d7c6-b5a4-3210-fedc-ba0987654321  edit       Play       15m 42s
    b2c3d4e5-f6a7-8901-bcde-f12345678901  client     Play       15m 40s
    c3d4e5f6-a7b8-9012-cdef-123456789012  server     Play       15m 40s

2 instances, 4 sessions connected.
```

In the example above, instance `abc12345` is in Edit mode (1 session). Instance `def67890` is in Play mode, so it has 3 sessions: the Edit context (still present), plus the Client and Server contexts that appeared when the developer pressed Play.

Flags:
- `--json` -- output as JSON array (for scripting and MCP)
- `--watch` -- continuously update the list (like `watch`)

### `studio-bridge connect <session-id>`

Enters an interactive terminal session attached to the specified Studio session. Equivalent to `studio-bridge terminal <session-id>` but with a name that makes the "attach to existing" intent clear.

### `studio-bridge state [session-id]`

```
$ studio-bridge state
Place:    TestPlace
PlaceId:  1234567890
GameId:   9876543210
Mode:     Edit
```

Flags:
- `--json` -- output as JSON
- `--watch` -- continuously print state changes

### `studio-bridge screenshot [session-id]`

```
$ studio-bridge screenshot
Screenshot saved to /tmp/studio-bridge/screenshot-2026-02-20-143022.png
```

Flags:
- `--output` / `-o` -- specify output file path (default: temp directory with timestamp)
- `--open` -- open the screenshot in the default image viewer after capture
- `--base64` -- print base64-encoded PNG to stdout instead of writing a file

### `studio-bridge logs [session-id]`

```
$ studio-bridge logs
$ studio-bridge logs --tail 100
$ studio-bridge logs --follow
$ studio-bridge logs --follow --level Error,Warning
$ studio-bridge logs --head 20
```

Flags:
- `--tail <n>` -- show last N lines (default: 50)
- `--head <n>` -- show first N lines
- `--follow` / `-f` -- stream new output in real time
- `--level <levels>` -- comma-separated level filter (Print, Info, Warning, Error)
- `--all` -- include internal `[StudioBridge]` messages
- `--json` -- output each line as a JSON object with timestamp, level, body

### `studio-bridge query <expression> [session-id]`

```
$ studio-bridge query Workspace.SpawnLocation
{
  "className": "SpawnLocation",
  "name": "SpawnLocation",
  "path": "Workspace.SpawnLocation",
  "childCount": 0,
  "properties": {
    "Position": { "x": 0, "y": 4, "z": 0 },
    "Anchored": true,
    "Duration": 0
  }
}

$ studio-bridge query Workspace --children
[
  { "name": "Camera", "className": "Camera" },
  { "name": "Terrain", "className": "Terrain" },
  { "name": "SpawnLocation", "className": "SpawnLocation" }
]

$ studio-bridge query StarterPlayer.StarterPlayerScripts --descendants
```

Flags:
- `--children` -- list immediate children instead of querying the instance itself
- `--descendants` -- list all descendants (tree)
- `--properties <names>` -- comma-separated list of property names to include
- `--attributes` -- include all attributes
- `--json` -- output as JSON (this is the default; `--pretty` for formatted)
- `--depth <n>` -- max depth for `--descendants` (default: 1)

### Existing Commands (Adapted)

The `exec`, `run`, and `terminal` commands gain the optional `[session-id]` positional argument, `--session` / `-s` flag, and `--context` / `-c` flag. Their existing flags remain unchanged. The `--context` flag accepts `edit`, `client`, or `server` and selects which plugin context to target within the resolved instance.

## Terminal Mode Extensions

When in terminal mode (whether launched via `studio-bridge terminal` or `studio-bridge connect`), the following dot-commands are added alongside the existing `.help`, `.exit`, `.run`, and `.clear`:

| Command | Description |
|---------|-------------|
| `.sessions` | List all connected Studio sessions |
| `.connect <session-id>` | Switch to a different session (if in multi-session mode) |
| `.state` | Show the current session's Studio state |
| `.screenshot [path]` | Capture a viewport screenshot |
| `.logs [--tail N \| --follow]` | Show or follow output logs |
| `.query <expression>` | Query the DataModel |
| `.disconnect` | Disconnect from the current session without killing Studio |

The `.help` output must be updated to include these new commands.

When connected to a `user`-origin session (i.e., the developer started Studio manually), the `.exit` command must disconnect without killing Studio. The existing behavior of killing Studio on exit must only apply to `managed`-origin sessions (sessions that studio-bridge launched itself). The origin is always visible in session listings so humans and agents can make informed decisions about session lifecycle.

## Non-Goals

The following are explicitly out of scope for this project:

- **Remote Studio connections** -- All connections are localhost only. Connecting to Studio on a different machine over a network is not supported.
- **Multiple simultaneous CLI connections to one session** -- A single Studio session has one WebSocket connection at a time. If a second client connects, the first is disconnected.
- **Automatic plugin installation** -- The persistent plugin must still be installed manually or via `studio-bridge install-plugin`. We do not auto-install plugins into the user's Studio without their explicit action.
- **Place file editing** -- studio-bridge does not modify the place file's DataModel (inserting instances, changing properties from the CLI). It is read-only plus script execution. Write operations happen via `exec`.
- **Source code syncing** -- Rojo handles file syncing. studio-bridge does not replicate or replace any Rojo functionality.
- **Play Solo / Team Test orchestration** -- Programmatically launching Play mode, starting server/client sessions, or coordinating team test is out of scope. Users can trigger these via `exec` if needed. However, **exposing the existing Play mode contexts is a goal**: when a developer has already entered Play mode, studio-bridge surfaces the Client and Server sessions and allows targeting them independently. The non-goal is orchestrating *entry into* Play mode, not interacting with sessions that already exist.
- **Studio version management** -- studio-bridge does not install, update, or manage Roblox Studio versions.
- **Authentication** -- No login or API key management. studio-bridge relies on the user's existing Studio auth session.

## Success Metrics

### Adoption Metrics

- **Session reuse rate** -- Percentage of `exec`/`run` invocations that connect to an existing session rather than launching a new one. Target: >80% within 3 months of release for users who have the persistent plugin installed.
- **MCP tool invocations** -- Number of MCP tool calls per day across all users. This is a leading indicator of AI agent adoption. Target: measurable growth month-over-month.

### Performance Metrics

- **Time to first execution (cold start)** -- Time from `studio-bridge exec` to script output when launching a new Studio. Baseline: 15-30s. Target: no regression from current.
- **Time to first execution (warm start)** -- Time from `studio-bridge exec` to script output when connecting to an existing session. Target: <2 seconds.
- **Screenshot latency** -- Time from `studio-bridge screenshot` to file written. Target: <3 seconds.
- **Query latency** -- Time from `studio-bridge query` to JSON response. Target: <1 second.

### Reliability Metrics

- **Session reconnection rate** -- When Studio is still running but the WebSocket drops (e.g., CLI process was killed), the plugin must reconnect within 5 seconds of the next CLI invocation.
- **Stale session cleanup** -- Sessions where Studio has quit must be removed from the session list within 10 seconds.
- **Graceful degradation** -- All commands must fail with a clear error message within the timeout period. No hanging indefinitely.

### User Experience Metrics

- **Zero-config happy path** -- A user with the persistent plugin installed and one Studio instance open must be able to run `studio-bridge exec 'print("hi")'` with no flags and get output. No session ID, no port, no configuration. This works regardless of whether Studio is in Edit mode or Play mode: in Edit mode there is exactly one session (auto-selected); in Play mode there are three sessions but the resolution cascade defaults to the Edit context (always present, does not interfere with the running game). Targeting a Play mode context requires the explicit `--context` flag, which is the expected progressive-disclosure tradeoff.
- **Error message clarity** -- Every error message must include what went wrong, why, and what the user can do about it (e.g., "No Studio sessions found. Is Studio running with the studio-bridge plugin installed? See: <doc link>").
