# Architecture Overview: Technical Specification

This is the top-level architecture document for studio-bridge persistent sessions. It describes the system-level design, key decisions, and how the components fit together. Detailed designs for individual subsystems are in the companion specs referenced throughout.

Read this document first. It gives you the full picture in one place. The companion specs go deep on each subsystem.

## Spec Documents

| Document | Scope |
|----------|-------|
| `00-overview.md` | **This file.** Architecture overview, key decisions, component map, file layout, migration strategy, security |
| `01-protocol.md` | Wire protocol: message types, request/response correlation, capability negotiation, versioning, TypeScript type definitions |
| `02-command-system.md` | Unified command system: `CommandDefinition` interface, CLI/terminal/MCP adapters, session resolution, output formatting |
| `03-persistent-plugin.md` | Plugin Luau architecture: boot mode detection, discovery protocol, state machine, reconnection, action handlers, `PluginManager` API |
| `04-action-specs.md` | Per-action specification: CLI flags, terminal dot-command, MCP tool schema, wire messages, handler logic, error cases, timeouts |
| `05-split-server.md` | Devcontainer support: `studio-bridge serve` command, explicit bridge host, port forwarding, environment detection |
| `06-mcp-server.md` | MCP server: tool registration from `allCommands`, stdio transport, session auto-selection, error mapping, Claude Code configuration |
| `07-bridge-network.md` | **Authoritative networking spec.** `BridgeConnection` and `BridgeSession` public API, internal architecture (host, client, transport, session tracker, hand-off), role detection, host-client protocol, session lifecycle, testing strategy |

## 1. Architecture Overview

The persistent sessions system transforms studio-bridge from a launch-use-discard tool into a long-lived service that maintains connections to running Studio instances. The central design principle: **networking is completely abstracted away from consumers.** The public API is two classes (`BridgeConnection` and `BridgeSession`) and a handful of result types. Everything else -- ports, WebSockets, host/client roles, plugin discovery, hand-off protocol -- is internal to the networking layer and invisible to any code that uses studio-bridge.

### What consumers see (the only public API)

```
┌─────────────────────────────────────────────────────┐
│                  Consumer Code                       │
│                                                      │
│  const conn = await BridgeConnection.connectAsync()  │
│  const session = await conn.waitForSession()         │
│  await session.execAsync(...)                        │
│  await session.queryStateAsync()                     │
│  await session.captureScreenshotAsync()              │
│                                                      │
│  // Same code whether 1 Studio or 10 Studios         │
│  // Same code whether local or devcontainer          │
│  // Same code whether this process is host or client │
│  // No ports, no WebSocket, no host/client roles     │
└──────────────────────────┬──────────────────────────┘
                           │
               ┌───────────┴───────────┐
               │   BridgeConnection    │  <- only public entry point
               │   BridgeSession       │  <- only public handle
               │   SessionInfo, types  │  <- only public data
               └───────────┬───────────┘
                           │
                   ┌───────┴───────┐
                   │  (networking) │  <- hidden, not importable
                   │  (transport)  │     by consumer code
                   └───────────────┘
```

### What is inside the networking layer (internal -- consumers never see this)

The networking layer handles all the complexity of multi-process coordination. The topology is **many-to-one**: many plugins and many CLI clients all connect to a single bridge host on port 38741. There is never more than one bridge host per port. This diagram is for implementors; consumers never interact with these components directly.

```
                  +---------------------------------------------+
                  |          CLI / Library Consumer              |
                  |                                              |
                  |  studio-bridge exec 'print("hi")'           |
                  |  studio-bridge terminal                      |
                  |  studio-bridge connect <session>             |
                  |  nevermore test --local                      |
                  +------------------+---------------------------+
                                     |
                    (calls BridgeConnection / BridgeSession only)
                                     |
          ══════════════════════════════════════════════════════
          ║  INTERNAL NETWORKING LAYER (never imported directly) ║
          ══════════════════════════════════════════════════════
                                     |
                  +------------------v---------------------------+
                  |            Bridge Host                       |
                  |       (first CLI to bind port 38741)         |
                  |                                              |
                  |   WebSocket server on port 38741             |
                  |   Tracks connected plugins (live sessions)   |
                  |   Groups sessions by instanceId              |
                  |   Routes commands to sessions                |
                  |   Multiplexes client requests                |
                  +------+------------------+--------------------+
                         |                  |
                    +----v-----+      +-----v-----------+
                    | Plugin A |      | Plugin B (Edit) |  <-- connect via /plugin
                    |(Studio 1)|      | Plugin B (Srv)  |
                    | (Edit)   |      | Plugin B (Clt)  |
                    +----------+      +-----------------+
                                             ^
                    Studio 1: Edit mode       |  Studio 2: Play mode
                    (1 connection)            |  (3 connections, same instanceId)
                                             |
                              CLI Clients ---+  <-- connect via /client
                         (subsequent CLI processes)
```

### Data flow for a persistent-session execution

1. Consumer calls `BridgeConnection.connectAsync()`. Internally, this attempts to bind port 38741. Success means this process becomes the bridge host; failure (EADDRINUSE) means it connects as a client to the existing host. **The consumer does not know which happened.**
2. Consumer calls `conn.waitForSession()`. Internally, the plugin in Studio polls `localhost:38741/health` every 2 seconds, connects when the host appears, and sends a `register` message with session metadata (including its `instanceId` and `context`). **The consumer just awaits a `BridgeSession`.** When Studio enters Play mode, 2 new plugin instances (client and server) connect as separate sessions with the same `instanceId`, joining the already-connected edit session -- the bridge host groups them automatically.
3. Consumer calls `session.execAsync(...)`. Internally, the command is routed through the bridge host to the plugin, and results flow back. **The consumer sees a promise that resolves with results.**
4. All subsequent calls (`queryStateAsync`, `captureScreenshotAsync`, etc.) follow the same pattern -- the consumer calls a method on `BridgeSession`, the networking layer handles routing, and the consumer gets a typed result.

### Two operating modes (transparent to consumers)

Both modes use the exact same consumer API. The difference is entirely within the networking layer:

- **Implicit host** (default): The first CLI process binds port 38741 and becomes the bridge host. Subsequent CLI processes connect as clients. Plugins connect directly. This is the mode used for local single-machine development.
- **Explicit host** (devcontainer/remote): The user runs `studio-bridge serve` on the host machine, which becomes a dedicated headless bridge host on port 38741. The devcontainer CLI connects to `localhost:38741` (port-forwarded) as a client. Alternatively, `studio-bridge terminal --keep-alive` serves the same role with a REPL attached.

```
Implicit host (default)              Explicit host (studio-bridge serve)
┌─────────────────────────────┐      ┌─────────────────────────────┐
│ CLI process (first started) │      │ studio-bridge serve         │
│ ┌─────────────┐             │      │ ┌─────────────┐             │
│ │ Bridge Host  │<── plugins  │      │ │ Bridge Host  │<── plugins  │
│ └─────────────┘             │      │ └─────────────┘             │
│ + CLI commands              │      └──────────────┬──────────────┘
└─────────────────────────────┘                     │ port 38741
                                     ┌──────────────┴──────────────┐
                                     │ CLI process (client mode)   │
                                     │ CLI commands, MCP, terminal │
                                     └─────────────────────────────┘
```

In both cases, CLI commands use `BridgeConnection` identically. Consumer code calling `BridgeConnection.connectAsync()` cannot tell which mode is active.

Split-server mode is detailed in `05-split-server.md`.

### 1.1 API Boundary

The architecture has a strict boundary between the public API and the internal networking layer. This boundary is enforced by directory structure and import rules. The full API definition is in `07-bridge-network.md` (the authoritative networking spec); what follows is a summary.

**Public API (exported from `src/bridge/index.ts`):**

- **`BridgeConnection`** -- connect to the studio-bridge network, access sessions. The ONLY entry point for programmatic use.
- **`BridgeSession`** -- interact with a single Studio instance. Action methods: `execAsync`, `queryStateAsync`, `captureScreenshotAsync`, `queryLogsAsync`, `queryDataModelAsync`, `subscribeAsync`, `unsubscribeAsync`.
- **`SessionInfo`** -- read-only metadata about a session (session ID, place name, state, capabilities, origin, context, instanceId, placeId, gameId).
- **`InstanceInfo`** -- read-only metadata about a Studio instance (instanceId, placeName, placeId, gameId, connected contexts, origin).
- **`SessionContext`** -- `'edit' | 'client' | 'server'` identifying which Studio VM a session belongs to.
- **Result types** -- `ExecResult`, `StateResult`, `ScreenshotResult`, `LogsResult`, `DataModelResult`.
- **Option types** -- `BridgeConnectionOptions`, `LogOptions`, `QueryDataModelOptions`.
- **Error types** -- `SessionNotFoundError`, `ContextNotFoundError`, `ActionTimeoutError`, `HostUnreachableError`, etc.

**Everything else is internal:**

Bridge host, bridge client, transport server, transport client, hand-off protocol, health endpoint, WebSocket paths, session tracker, host-protocol envelopes -- ALL internal. Consumers never create a `BridgeHost`, `BridgeClient`, or `TransportServer`. Those classes exist inside `src/bridge/internal/` and are not re-exported.

**The consumer invariant:**

A consumer using `BridgeConnection` cannot tell whether:
- There is one Studio or ten Studios connected
- Studio is in Edit mode (1 context) or Play mode (3 contexts)
- Their process is the bridge host or a bridge client
- The connection is local or over a forwarded port
- The plugin connected via persistent discovery or ephemeral injection
- The host was started implicitly or via `studio-bridge serve`

This is a hard architectural constraint, not a convenience. Any change that would require consumers to be aware of the networking topology is a design violation.

## 2. Key Design Decisions

### 2.1 Unified plugin with two boot modes

There is ONE plugin source, not two. The same Luau code ships in both installation modes. The difference is how the plugin is built and how it discovers the server:

**Persistent mode** (local development):
- Built with `IS_EPHEMERAL = false`, `PORT = nil`, and `SESSION_ID = nil`.
- Installed once to the Studio plugins folder via `studio-bridge install-plugin`.
- At startup, checks `IS_EPHEMERAL` and enters the discovery loop: polls `localhost:38741` to find the bridge host, connects via WebSocket, and registers with session metadata.
- Survives across Studio restarts; reconnects automatically when a server appears or reappears.

**Ephemeral mode** (CI, legacy, fallback):
- Built with `IS_EPHEMERAL = true`, `PORT` set to a number, and `SESSION_ID` set to a UUID string.
- Injected per session by `StudioBridgeServer.startAsync()`, deleted on `stopAsync()`.
- At startup, checks `IS_EPHEMERAL` and connects directly to the known server -- no discovery, no polling.
- Behaves identically to the current temporary plugin.

Build constants are injected via a two-step pipeline: Handlebars template substitution (in TemplateHelper) replaces placeholders like `{{IS_EPHEMERAL}}` in the Lua source, then Rojo builds the substituted sources into an `.rbxm` plugin file. The result is a plain boolean constant that the plugin checks without any string comparison tricks:

```lua
local IS_EPHEMERAL = {{IS_EPHEMERAL}}  -- substituted by Handlebars, then built by Rojo
local PORT = {{PORT}}                   -- replaced with number (ephemeral) or nil (persistent)
local SESSION_ID = "{{SESSION_ID}}"     -- replaced with UUID (ephemeral) or nil/empty (persistent)
```

If `IS_EPHEMERAL` is true, the plugin connects directly (ephemeral mode). Otherwise, it enters the discovery state machine (persistent mode).

Why a unified source instead of two separate plugins:
- Eliminates code drift between persistent and ephemeral implementations
- All action handlers, protocol logic, and serialization are shared -- validated once, used everywhere
- Reduces validation risk: a bug fix in one mode automatically applies to the other
- Eliminates the most fragile part of the current system (file injection races, stale plugins after crashes) in persistent mode
- Enables the plugin to reconnect after server restarts without re-launching Studio
- Required for split-server mode where the server may start after Studio
- Allows the plugin to offer richer capabilities (screenshot, DataModel query) that persist across sessions

Trade-offs:
- Plugin must handle discovery and reconnection logic (more complex Luau code), though this only activates in persistent mode
- Users must explicitly install the plugin for persistent mode (one-time setup step)
- Security surface increases in persistent mode (see section 10)

Details in `03-persistent-plugin.md`.

### 2.1.1 Plugin management as a reusable subsystem

The plugin build/install infrastructure is a general-purpose utility, not a studio-bridge-specific feature. The `src/plugins/` module provides a `PluginManager` class that operates on `PluginTemplate` descriptors -- it never hard-codes paths, filenames, or build constants for any specific plugin. studio-bridge registers its plugin template during initialization; future tools register theirs.

This means that adding a new persistent plugin (e.g., for Rojo sync, test running, or remote debugging) requires only:
1. Creating a template directory with a Rojo project and Luau source.
2. Defining a `PluginTemplate` with the template's name, path, build constants, and output filename.
3. Calling `pluginManager.registerTemplate(template)`.

No changes to `PluginManager` itself. The build, install, version tracking, and uninstall flows work unchanged for any registered template. See `03-persistent-plugin.md` section 2 for the full API design.

### 2.2 Bridge host discovery

Sessions are discovered live through the bridge host, not via files on disk. A single well-known port (38741) serves as the rendezvous point -- the topology is many-to-one (many plugins and CLI clients, one bridge host). The first CLI process to start binds this port and becomes the bridge host; subsequent CLI processes connect as clients.

Session discovery works as follows:
1. CLI starts (as host or connects as client)
2. Sends a `listSessions` request to the host
3. Host responds with all currently connected plugins and their metadata (place name, state, session ID, context, instanceId -- all from the plugin's `register` message)
4. If no plugins are connected yet, the host waits up to `timeoutMs` for plugins to connect

The bridge host groups sessions by `instanceId`. A single Studio instance may have 1 session (Edit mode) or up to 3 sessions (Play mode: Edit + Client + Server). Consumers typically interact at the instance level (via `listInstances()` and `resolveSession()`) rather than enumerating individual context sessions.

There is no session registry on disk. "Session scanning" = "see which plugins are connected to the host right now."

Why bridge host instead of file-based registry:
- Roblox plugins cannot read arbitrary files from disk (`plugin:SetSetting()` is opaque to external processes)
- CLI processes are ephemeral -- making them "session owners" inverts the natural lifecycle (Studio is the long-lived process)
- Zero-infrastructure: no daemon management, no lock files, no stale PID checks
- Self-healing: if the bridge host dies, a connected client takes over the port automatically
- Cross-process: `nevermore-cli`'s `LocalJobContext` connects to the same bridge host as the `studio-bridge` CLI

### 2.3 Named message types with request/response correlation

Currently, the server-to-plugin protocol has one action: `execute` (run a Luau string). The persistent plugin needs to support a richer set of operations: state queries, screenshots, DataModel inspection, and log retrieval.

The solution is named message types with request/response correlation. Each operation has its own dedicated server-to-plugin request type and a corresponding plugin-to-server response type:

```typescript
// Server -> Plugin (each operation gets its own type)
{ type: 'queryState',        sessionId, requestId, payload: {} }
{ type: 'captureScreenshot', sessionId, requestId, payload: { format?: 'png' } }
{ type: 'queryDataModel',    sessionId, requestId, payload: { path, depth?, ... } }
{ type: 'queryLogs',         sessionId, requestId, payload: { count?, ... } }

// Plugin -> Server (named responses)
{ type: 'stateResult',       sessionId, requestId, payload: { state, placeId, ... } }
{ type: 'screenshotResult',  sessionId, requestId, payload: { data, format, ... } }
{ type: 'dataModelResult',   sessionId, requestId, payload: { instance: { ... } } }
{ type: 'logsResult',        sessionId, requestId, payload: { entries: [...] } }
```

Named types are more explicit, produce better TypeScript discriminated unions, and are easier to validate per-message. A `requestId` field (UUIDv4) on each request enables concurrent request/response correlation -- the server can have multiple operations in flight simultaneously.

The existing `execute` and `scriptComplete` message types are fully preserved. The `execute` message gains an optional `requestId` field; if present, `scriptComplete` echoes it. Legacy plugins that omit `requestId` continue to work with sequential semantics.

Details in `01-protocol.md`.

### 2.4 Backward compatibility as a hard constraint

The library API (`StudioBridgeServer` class, re-exported as `StudioBridge` from `index.ts` via `export { StudioBridgeServer as StudioBridge }`, consumed by `LocalJobContext` in nevermore-cli) must not break. Existing callers that do:

```typescript
const bridge = new StudioBridgeServer({ placePath });
await bridge.startAsync();
const result = await bridge.executeAsync({ scriptContent });
await bridge.stopAsync();
```

...must continue to work unchanged. The persistent session features are additive: new options on existing methods, new methods on the class, and new CLI commands.

The re-export alias ensures backward compatibility:

```typescript
// src/index.ts -- re-export alias preserves the public name
export { StudioBridgeServer as StudioBridge } from './server/studio-bridge-server.js';
```

The temporary plugin injection path remains available as a fallback when the persistent plugin is not installed, preserving zero-config behavior for CI environments.

The existing `StudioBridgeServer` class wraps `BridgeConnection` internally:

```typescript
// src/server/studio-bridge-server.ts -- preserved API
export class StudioBridgeServer {
  private _connection?: BridgeConnection;
  private _session?: BridgeSession;

  async startAsync(): Promise<void> {
    this._connection = await BridgeConnection.connectAsync({
      keepAlive: true,
      timeoutMs: this._defaultTimeoutMs,
    });
    this._session = await this._connection.waitForSession(this._defaultTimeoutMs);
  }

  async executeAsync(options: ExecuteOptions): Promise<StudioBridgeResult> {
    return this._session!.execAsync(options.scriptContent);
  }

  async stopAsync(): Promise<void> {
    await this._connection?.disconnectAsync();
  }
}
```

Callers of `new StudioBridgeServer()` (or `new StudioBridge()` via the re-export) / `startAsync()` / `executeAsync()` / `stopAsync()` see no change.

## 3. Component Map

### 3.1 Bridge module file layout

The `src/bridge/` directory is organized to make the API boundary structurally obvious. Public files live at the top level; internal networking files live in `internal/`. The directory structure IS the API contract.

```
src/bridge/
  index.ts                        PUBLIC: re-exports ONLY BridgeConnection, BridgeSession, types

  # Public API (importable by consumers via src/bridge/index.ts)
  bridge-connection.ts            BridgeConnection class
  bridge-session.ts               BridgeSession class
  types.ts                        SessionInfo, SessionOrigin, result types, option types

  # Internal networking (NEVER imported by consumers)
  internal/
    bridge-host.ts                WebSocket server on port 38741, plugin + client management
    bridge-client.ts              WebSocket client connecting to existing host
    transport-server.ts           Low-level WebSocket/HTTP server
    transport-client.ts           Low-level WebSocket client
    transport-handle.ts           TransportHandle interface (abstraction between layers)
    health-endpoint.ts            HTTP /health endpoint
    hand-off.ts                   Host transfer logic (graceful shutdown + crash recovery)
    host-protocol.ts              Client-to-host envelope messages (listSessions, hostTransfer, etc.)
    session-tracker.ts            In-memory session map (used by bridge-host)
    environment-detection.ts      isDevcontainer(), getDefaultRemoteHost() (split-server auto-detection)
```

The `internal/` directory makes it structurally clear what is and is not public. TypeScript path restrictions (or convention enforced by review) ensure consumers only import from `src/bridge/index.ts`.

### 3.1.1 Plugin management module file layout

The `src/plugins/` directory contains the **universal plugin management subsystem**. This is a reusable utility -- not specific to studio-bridge. studio-bridge is its first consumer, but any Nevermore tool that needs to build and install a persistent Roblox Studio plugin uses this same infrastructure. The design is detailed in `03-persistent-plugin.md` section 2.

```
src/plugins/
  index.ts                          PUBLIC: re-exports PluginManager, PluginTemplate, types
  plugin-manager.ts                 PluginManager class: build, install, uninstall, list
  plugin-template.ts                PluginTemplate interface and validation
  plugin-discovery.ts               discoverPluginsDirAsync() -- platform-specific Studio folder detection
  types.ts                          InstalledPlugin, BuiltPlugin, BuildOverrides types
```

The plugin manager is parameterized by `PluginTemplate` -- it never hard-codes paths or names for any specific plugin. studio-bridge registers its template during initialization; future tools register theirs. Adding a new plugin never requires modifying the manager.

### 3.2 Other new files

| File | Purpose |
|------|---------|
| `src/server/pending-request-map.ts` | Track in-flight requests by `requestId`, enforce timeouts, resolve/reject promises |
| `src/server/action-dispatcher.ts` | Route incoming response messages to waiting callers by `requestId` via `PendingRequestMap` |
| `src/server/actions/query-state.ts` | Server-side handler for `queryState` action (used by `StudioBridgeServer`) |
| `src/server/actions/capture-screenshot.ts` | Server-side handler for `captureScreenshot` action (used by `StudioBridgeServer`) |
| `src/server/actions/query-logs.ts` | Server-side handler for `queryLogs` action (used by `StudioBridgeServer`) |
| `src/server/actions/query-datamodel.ts` | Server-side handler for `queryDataModel` action (used by `StudioBridgeServer`) |
| `src/commands/index.ts` | Command registry: barrel file exporting all command definitions and the `allCommands` array. CLI, terminal, and MCP all register from this single source. See `02-command-system.md` section 3. |
| `src/commands/types.ts` | `CommandDefinition`, `CommandContext`, `CommandResult`, `ArgSpec` types |
| `src/commands/session-resolver.ts` | Shared `resolveSessionAsync` utility used by all adapters |
| `src/commands/sessions.ts` | `sessions` command handler -- list active sessions |
| `src/commands/state.ts` | `state` command handler -- query Studio state (run mode, place info) |
| `src/commands/screenshot.ts` | `screenshot` command handler -- capture viewport screenshot |
| `src/commands/logs.ts` | `logs` command handler -- retrieve and follow output logs |
| `src/commands/query.ts` | `query` command handler -- query the DataModel |
| `src/commands/exec.ts` | `exec` command handler -- execute Luau code (extracted from exec-command.ts) |
| `src/commands/run.ts` | `run` command handler -- run a Luau file (extracted from run-command.ts) |
| `src/commands/connect.ts` | `connect` command handler -- connect to an already-running Studio |
| `src/commands/disconnect.ts` | `disconnect` command handler -- disconnect from a session |
| `src/commands/launch.ts` | `launch` command handler -- explicitly launch a new Studio session |
| `src/commands/install-plugin.ts` | `install-plugin` command handler -- delegates to `PluginManager` to build and install the studio-bridge persistent plugin |
| `src/commands/serve.ts` | `serve` command handler -- start a dedicated bridge host process (see `05-split-server.md`) |
| `src/cli/adapters/cli-adapter.ts` | `createCliCommand` -- generic adapter: `CommandDefinition` to yargs `CommandModule` |
| `src/cli/adapters/terminal-adapter.ts` | `createDotCommandHandler` -- generic adapter: `CommandDefinition[]` to dot-command dispatcher |
| `src/mcp/adapters/mcp-adapter.ts` | `createMcpTool` -- generic adapter: `CommandDefinition` to MCP tool. See `06-mcp-server.md`. |
| `src/mcp/mcp-server.ts` | MCP server lifecycle: creates `BridgeConnection`, registers tools from `allCommands`, handles stdio transport. See `06-mcp-server.md`. |
| `src/mcp/index.ts` | Public exports for the MCP module |
| `src/commands/mcp.ts` | `mcp` command handler (`mcpEnabled: false`) -- starts MCP server via `startMcpServerAsync()` |

### 3.3 Modified files

| File | Changes |
|------|---------|
| `src/server/studio-bridge-server.ts` | Add bridge connection integration; support both temporary and persistent plugin modes; add `requestId`-based request dispatch alongside existing execute path |
| `src/server/web-socket-protocol.ts` | Add v2 message types (`queryState`, `stateResult`, `captureScreenshot`, `screenshotResult`, `queryDataModel`, `dataModelResult`, `queryLogs`, `logsResult`, `subscribe`, `subscribeResult`, `unsubscribe`, `unsubscribeResult`, `stateChange`, `heartbeat`, `register`, `error`); add `requestId` and `protocolVersion` to base envelope; add shared types (`Capability`, `ErrorCode`, `StudioState`, `SerializedValue`, `DataModelInstance`); keep all existing types |
| `src/plugin/plugin-injector.ts` | Delegate to `PluginManager.isInstalledAsync('studio-bridge')` for persistent plugin detection; skip injection when persistent plugin is present; use `PluginManager.buildAsync()` with overrides for ephemeral builds |
| `src/cli/cli.ts` | Register all commands via `allCommands` loop (imports from `src/commands/index.js`, no individual command imports). Add `--remote` and `--local` global options for split-server mode. |
| `src/cli/commands/terminal/terminal-mode.ts` | Wire up `dotcommand` event to `createDotCommandHandler(allCommands)`. Support connecting to existing sessions. |
| `src/cli/commands/terminal/terminal-editor.ts` | Emit `dotcommand` event for non-intrinsic dot-commands (`.help`, `.exit`, `.clear` stay inline) |
| `src/mcp/mcp-server.ts` | Register all MCP-eligible tools via `allCommands.filter(c => c.mcpEnabled !== false)` loop (imports from `src/commands/index.js`, no individual command imports). See `06-mcp-server.md`. |
| `src/index.ts` | Export new public types (`BridgeConnection`, `BridgeSession`, `SessionInfo`, `InstanceInfo`, `SessionContext`, result types, error types, v2 message types, `Capability`, `ErrorCode`, `StudioState`, `SerializedValue`, `DataModelInstance`) |
| `templates/studio-bridge-plugin/` | Upgraded in-place: same directory, same name, but source now supports both persistent and ephemeral boot modes with full v2 protocol support |

### 3.4 Import rules

These rules enforce the API boundary between the public bridge API and the internal networking layer:

```
Import rules:
  src/bridge/index.ts              Re-exports public API only. No internal/ types leak out.
  src/bridge/bridge-connection.ts   May import from internal/ (it orchestrates networking).
  src/bridge/bridge-session.ts      May import from internal/ (it delegates to transport handles).
  src/bridge/types.ts               No imports from internal/ (pure type definitions).
  src/bridge/internal/*.ts          May import from each other. NEVER imported outside src/bridge/.

  src/plugins/index.ts             Re-exports PluginManager, PluginTemplate, types.
  src/plugins/*.ts                 Self-contained module. May import from src/plugins/ only (no bridge internals).

  src/commands/*.ts                 Imports from src/bridge/index.ts and src/plugins/index.ts (public APIs).
  src/cli/*.ts                      Imports from src/bridge/index.ts and src/plugins/index.ts (public APIs).
  src/mcp/*.ts                      Imports from src/bridge/index.ts only (public API).
  src/plugin/plugin-injector.ts     Imports from src/plugins/index.ts (uses PluginManager for build/install checks).
  src/index.ts                      Re-exports from src/bridge/index.ts and src/plugins/index.ts (public API surfaces).

  External consumers (nevermore-cli) Import from 'studio-bridge' package entry (src/index.ts).
```

The key rule: **nothing outside `src/bridge/` may import from `src/bridge/internal/`**. This is what makes the networking abstraction real. If a consumer needs something from the internal layer, the correct fix is to add it to the public API in `src/bridge/index.ts`, not to reach into internals.

**Shared workspace dependency**: `@quenty/cli-output-helpers` is already a dependency of studio-bridge (used for `OutputHelper` colored output). The persistent sessions work adds a dependency on `@quenty/cli-output-helpers/output-modes` for command output formatting (table rendering, JSON output, watch/follow mode). These output mode utilities are new additions to the existing shared package -- no new package is created. The CLI adapter (`src/cli/adapters/cli-adapter.ts`) is the primary consumer. See `execution/output-modes-plan.md` for the full design.

### 3.5 Unified plugin template directory

The existing `templates/studio-bridge-plugin/` directory is upgraded in-place. There is no second template directory. The same source supports both boot modes.

```
templates/studio-bridge-plugin/              (unified -- replaces the old single-purpose template)
  default.project.json
  src/
    StudioBridgePlugin.server.lua            -- entry point, detects boot mode, runs state machine
    Discovery.lua                             -- HTTP health polling (persistent mode only)
    Protocol.lua                              -- JSON encode/decode, send helpers
    ActionHandler.lua                         -- dispatch table, routes messages to handlers
    Actions/
      ExecuteAction.lua                       -- handle 'execute' messages
      StateAction.lua                         -- handle 'queryState', send 'stateResult'
      ScreenshotAction.lua                    -- handle 'captureScreenshot', send 'screenshotResult'
      DataModelAction.lua                     -- handle 'queryDataModel', send 'dataModelResult'
      LogAction.lua                           -- handle 'queryLogs', send 'logsResult'
      SubscribeHandler.lua                    -- handle 'subscribe'/'unsubscribe'
    LogBuffer.lua                             -- ring buffer for output log entries
    StateMonitor.lua                          -- detect and report Studio state changes
    ValueSerializer.lua                       -- Roblox type to JSON serialization
```

## 4. Session Discovery

### 4.1 In-memory session tracking

Sessions are tracked entirely in-memory by the bridge host. When a plugin connects to port 38741 via the `/plugin` WebSocket path, it sends a `register` message containing its session metadata (including `instanceId`, `context`, `placeId`, and `gameId`). The bridge host stores this in a live map of connected plugins, grouped by `instanceId`. When a plugin disconnects, its session is removed from the map immediately. When all sessions for an `instanceId` have disconnected, the instance group is removed.

Each session has an `origin` field that records how the plugin connected. Plugins that connect on their own (the persistent plugin polling and discovering an existing bridge host) are `'user'` origin -- these represent Studio instances the developer opened manually. Plugins that connect because studio-bridge launched Studio and injected or waited for the plugin are `'managed'` origin -- these represent Studio instances that the bridge owns.

Each session also has a `context` field (`'edit'`, `'client'`, or `'server'`) indicating which Studio VM it represents. In Edit mode, a Studio instance has one session with `context: 'edit'`. When Studio enters Play mode, the Client and Server VMs each spawn a separate plugin instance that connects as additional sessions with the same `instanceId`. The bridge host automatically groups these into a single logical instance.

There is no directory structure, no lock files, and no PID-based stale session detection. A session exists if and only if its plugin is currently connected to the bridge host.

```
~/.nevermore/studio-bridge/
  plugin/
    StudioBridgePlugin.rbxm   # installed persistent plugin
  config.json                 # optional user config
```

### 4.2 BridgeConnection and BridgeSession (public API summary)

`BridgeConnection` is the ONLY way to interact with studio-bridge programmatically. The full API definition with all method signatures, events, and error types is in `07-bridge-network.md` section 2. This section provides a summary for orientation.

The same code works identically in all scenarios:
- **1:1** (one CLI, one Studio in Edit mode) -- `resolveSession()` auto-selects the single Edit session
- **1:1 Play mode** (one CLI, one Studio in Play mode) -- `resolveSession()` auto-selects the Edit context; `resolveSession(undefined, 'server')` selects the Server context
- **N:N** (multiple CLIs, multiple Studios) -- `listInstances()` returns instance groups, `listSessions()` returns all sessions, `getSession(id)` targets a specific one
- **Local** -- networking is localhost
- **Remote/devcontainer** -- networking is port-forwarded, but the API is the same
- **Host role** -- this process bound the port
- **Client role** -- this process connected to an existing host

```typescript
// BridgeConnection -- the ONLY entry point
static connectAsync(options?: BridgeConnectionOptions): Promise<BridgeConnection>;
disconnectAsync(): Promise<void>;
listSessions(): SessionInfo[];               // in-memory, synchronous
listInstances(): InstanceInfo[];             // unique Studio instances (grouped by instanceId)
getSession(sessionId: string): BridgeSession | undefined;
waitForSession(timeout?: number): Promise<BridgeSession>;
resolveSession(sessionId?: string, context?: SessionContext, instanceId?: string): Promise<BridgeSession>;
readonly role: 'host' | 'client';

// InstanceInfo -- a Studio instance that may have 1-3 context sessions
{ instanceId, placeName, placeId, gameId, contexts: SessionContext[], origin }

// resolveSession() is instance-aware:
//   1. If sessionId provided -> return that session
//   2. If instanceId provided -> select that instance, apply context selection
//   3. Collect unique instances (by instanceId)
//   4. If 0 instances -> wait (with timeout)
//   5. If 1 instance:
//      a. If context flag provided -> return that context's session
//      b. If only 1 context (Edit mode) -> return it
//      c. If multiple contexts (Play mode) -> return Edit context (default)
//   6. If N instances -> throw with instance list (use --session or --instance)

// BridgeConnectionOptions
{ port?, timeoutMs?, keepAlive?, remoteHost? }

// BridgeSession -- handle to a single Studio instance
readonly info: SessionInfo;
execAsync(code: string, timeout?: number): Promise<ExecResult>;
queryStateAsync(): Promise<StateResult>;
captureScreenshotAsync(): Promise<ScreenshotResult>;
queryLogsAsync(options?: LogOptions): Promise<LogsResult>;
queryDataModelAsync(options: QueryDataModelOptions): Promise<DataModelResult>;
subscribeAsync(events: SubscribableEvent[]): Promise<void>;
unsubscribeAsync(events: SubscribableEvent[]): Promise<void>;

// SessionInfo -- read-only metadata
{ sessionId, placeName, placeFile?, state, pluginVersion, capabilities, connectedAt, origin,
  context, instanceId, placeId, gameId }

// SessionContext -- which Studio VM this session represents
type SessionContext = 'edit' | 'client' | 'server';

// SessionOrigin
type SessionOrigin = 'user' | 'managed';
```

Note: the overview uses abbreviated signatures for readability. See `07-bridge-network.md` section 2 for complete interface definitions including events, error types, and `followLogs()` async iterable.

### 4.3 Stale session handling

There is no stale session problem. Sessions are live WebSocket connections:
- Plugin connects -> session appears (grouped by instanceId)
- Plugin disconnects (Studio closed, crash, network drop) -> session disappears immediately
- All contexts for an instance disconnect -> instance group is removed
- Studio leaves Play mode -> Client and Server contexts disconnect, Edit stays
- Bridge host dies -> clients detect disconnect, one takes over the port, plugins reconnect within ~2 seconds

### 4.4 Plugin discovery: many-to-one topology

Discovery is many-to-one, not many-to-many. There is exactly one bridge host on port 38741. All plugins connect to it. All CLI/MCP processes either are the host or connect to it.

```
Studio A (Edit plugin) ─────────┐
                                │  /plugin WebSocket
Studio B (Edit plugin) ─────────┼──→ Bridge Host (:38741) ←──┬── CLI (host process)
Studio B (Server plugin) ───────┤                              ├── CLI (client)
Studio B (Client plugin) ───────┘                              └── MCP server (client)
                                     instanceId groups:
                                       Studio A: [edit]              (Edit mode)
                                       Studio B: [edit, server, client] (Play mode)
```

Each Studio instance runs one persistent plugin in Edit context. When Studio enters Play mode, the Client and Server VMs each load a separate plugin instance. These additional instances connect to the bridge host as separate WebSocket sessions, sharing the same `instanceId` but with distinct `context` values (`'edit'`, `'client'`, `'server'`). The bridge host groups all sessions with the same `instanceId` into a single logical instance.

The persistent plugin discovers the bridge host by polling `localhost:38741/health` (HTTP GET) every 2 seconds. When the health endpoint responds with HTTP 200 and `status: "ok"`:

1. The plugin opens a WebSocket connection to `ws://localhost:38741/plugin`
2. It generates a UUID (via `HttpService:GenerateGUID()`) and sends a `register` message with this proposed session ID, plus session metadata (instanceId, context, place name, placeId, gameId, Studio state, capabilities)
3. The bridge host accepts the plugin's proposed session ID (or overrides it on collision), stores the session (grouped by instanceId), and responds with `welcome` containing the authoritative session ID
4. The plugin adopts the session ID from the `welcome` response and enters the connected state, processing commands and sending heartbeats (every 5 seconds)
5. If the connection drops (host died, crash), the plugin returns to polling with exponential backoff

Multiple plugins can connect simultaneously. Each generates its own UUID as the proposed session ID (collisions are astronomically unlikely). The bridge host tracks all connected sessions in an in-memory map, grouped by `instanceId`. CLI consumers typically target sessions via `resolveSession()`, which auto-selects based on instance count and context. Direct session targeting by ID is available for advanced use.

When Studio enters Play mode, 2 new `register` messages arrive (server and client) joining the existing edit session, all sharing the same `instanceId` but with different `context` values. The edit plugin was already connected and is unaffected by Play mode transitions. When Studio leaves Play mode, the Client and Server contexts disconnect; the Edit context remains connected. The bridge host removes an instance from the grouping only when all its context sessions have disconnected.

If no bridge host is running, plugins poll indefinitely (the health check is a lightweight HTTP GET with 500ms timeout, negligible cost). When a CLI process eventually starts and binds port 38741, plugins discover it on the next poll cycle.

The full discovery protocol, including race conditions, disambiguation, and debugging, is documented in `03-persistent-plugin.md` section 3.

### 4.5 Connection types on port 38741

The WebSocket server distinguishes connection types by path:

| Path | Source | Purpose |
|------|--------|---------|
| `/plugin` | Studio plugin (Luau) | Plugin connection. Plugin sends `register`/`hello`, receives actions, sends responses and push messages. |
| `/client` | CLI process / MCP server | Client connection. Client sends host-protocol envelopes, receives forwarded responses and session events. |
| `/health` | HTTP GET (any) | Health check. Returns JSON with host status, session count, and uptime. Used by plugins for discovery. |

## 5. Plugin Architecture

### 5.1 Unified plugin -- two boot modes

The same plugin source operates in two modes, determined at startup by the presence of build-time constants (injected via a two-step pipeline: Handlebars template substitution in TemplateHelper, then Rojo build):

| Aspect | Ephemeral mode (CI / fallback) | Persistent mode (local dev) |
|--------|-------------------------------|----------------------------|
| Build-time constants | `IS_EPHEMERAL = true`, `PORT = <number>`, `SESSION_ID = "<uuid>"` | `IS_EPHEMERAL = false`, `PORT = nil`, `SESSION_ID = nil` |
| Installation | Auto-injected per session by `startAsync()` | One-time `studio-bridge install-plugin` |
| Server discovery | Connects directly to hardcoded PORT | Polls `localhost:38741` health endpoint |
| Lifespan | Deleted on `stopAsync()` | Survives across Studio restarts |
| Reconnection | None (plugin is deleted with session) | Auto-reconnect on server restart with exponential backoff |
| Session binding | `Workspace:GetAttribute("StudioBridgeSessionId")` guard | Plugin generates instanceId, detects context, announces via `register` |
| Capabilities | All v2 capabilities (shared source) | All v2 capabilities (shared source) |

Both modes share the same action handlers, protocol logic, serialization, and log buffering. The only difference is the connection establishment path.

### 5.2 Plugin state machine

```
    +----------+
    |  idle    | (Studio just opened, plugin loaded)
    +----+-----+
         | begin discovery
    +----v-----+
    |searching | (polling localhost:38741 every 2 seconds)
    +----+-----+
         | server found
    +----v-------+
    | connecting | (WebSocket handshake in progress)
    +----+-------+
         | handshake accepted
    +----v-----+
    |connected | (ready for actions)
    +----+-----+
         | WebSocket closed / error
    +----v--------+
    |reconnecting | (back to searching after backoff)
    +-------------+
```

Details in `03-persistent-plugin.md`.

## 6. Protocol Extensions

### 6.1 Current protocol (preserved)

```
Plugin -> Server:  hello, output, scriptComplete
Server -> Plugin:  welcome, execute, shutdown
```

All six message types remain valid. Existing plugins that only speak this protocol continue to work.

### 6.2 New message types

```
Server -> Plugin:  queryState          (request Studio run mode and place info)
Server -> Plugin:  captureScreenshot   (request viewport capture)
Server -> Plugin:  queryDataModel      (request instance tree / property lookup)
Server -> Plugin:  queryLogs           (request buffered log history)
Server -> Plugin:  subscribe           (subscribe to push events)
Server -> Plugin:  unsubscribe         (cancel event subscriptions)

Plugin -> Server:  register            (persistent plugin handshake, superset of hello; includes instanceId, context, placeId, gameId)
Plugin -> Server:  stateResult         (response to queryState)
Plugin -> Server:  screenshotResult    (response to captureScreenshot)
Plugin -> Server:  dataModelResult     (response to queryDataModel)
Plugin -> Server:  logsResult          (response to queryLogs)
Plugin -> Server:  subscribeResult     (confirmation of subscribe)
Plugin -> Server:  unsubscribeResult   (confirmation of unsubscribe)
Plugin -> Server:  stateChange         (unsolicited push: Studio mode transition)
Plugin -> Server:  logPush             (unsolicited push: individual log entry from LogService)
Plugin -> Server:  heartbeat           (periodic keep-alive with state info)
Plugin -> Server:  error               (error response to any request)
```

### 6.3 Capability negotiation

On handshake, the plugin's `hello` message gains an optional `capabilities` field:

```json
{
  "type": "hello",
  "sessionId": "abc-123",
  "protocolVersion": 2,
  "payload": {
    "sessionId": "abc-123",
    "capabilities": ["execute", "queryState", "captureScreenshot", "queryDataModel", "queryLogs", "subscribe", "heartbeat"],
    "pluginVersion": "1.0.0"
  }
}
```

The server's `welcome` response confirms which capabilities it will use, allowing graceful fallback when talking to an older plugin. Persistent plugins use `register` instead of `hello` to provide richer metadata (place name, file path, Studio state) in a single message.

Details in `01-protocol.md`.

## 7. Bridge Host Modes

### 7.1 Implicit host (default)

The first CLI process to start becomes the bridge host by binding port 38741. Subsequent CLI processes connect as clients to the existing host. Changes from current behavior:

- `BridgeConnection.connectAsync()` attempts to bind port 38741. Success = host, EADDRINUSE = client
- If a persistent plugin is installed, the host waits for the plugin to connect (plugin polls port 38741 every 2 seconds)
- If no persistent plugin is installed, `startAsync()` falls back to temporary plugin injection (existing behavior preserved for CI)
- If a host is already running, the CLI connects as a client and sends commands through the host

The state machine for the bridge host:

```
idle -> binding-port -> waiting-for-plugin -> ready -> executing -> ready -> idle/shutdown
                         ^^^^^^^^^^^^^^^^^^^
                         (plugin connects via polling, sends register message)
```

The state machine for a bridge client:

```
idle -> connecting-to-host -> ready -> executing -> ready -> disconnecting -> done
```

If the bridge host dies, the hand-off protocol kicks in: a connected client re-binds port 38741, becomes the new host, and plugins reconnect within ~2 seconds.

### 7.2 Hand-off protocol

When the bridge host process exits (gracefully or crash):

**Graceful exit** (Ctrl+C, normal shutdown):
1. Host sends `hostTransfer` message to all connected clients
2. Clients receive the message and enter "takeover standby" mode
3. Host closes the server
4. First client to successfully bind 38741 becomes new host
5. New host sends `hostReady` to remaining clients
6. Remaining clients reconnect to new host
7. Plugins poll, detect new server, reconnect

**Crash / kill -9**:
1. Clients detect WebSocket disconnect (error or close event)
2. Each client waits a random jitter (0-500ms) to avoid thundering herd
3. First client to bind 38741 becomes new host
4. Remaining clients retry connection to 38741
5. Plugins poll, detect new server, reconnect

**No clients connected when host exits**:
1. Host exits, port freed
2. Plugins poll, get connection refused, keep polling
3. Next CLI invocation becomes the new host

### 7.3 Idle behavior

When the bridge host is running but has no active CLI commands:
- If the host was started by `studio-bridge terminal`, it stays alive (terminal REPL is interactive)
- If the host was started by `studio-bridge exec` or `run`, it enters idle mode after the command completes
- In idle mode: if other clients are connected, the host stays alive. If no clients and no pending commands, the host exits after a 5-second grace period (allows plugins to remain connected briefly for rapid re-invocation)
- The `--keep-alive` flag forces the host to stay alive indefinitely (useful for MCP servers that want plugins to stay connected)

Idle shutdown (the 5-second grace period and automatic exit) only applies to `managed` sessions -- sessions where studio-bridge launched Studio. `user` sessions (where the developer opened Studio manually and the persistent plugin connected on its own) are never killed by the bridge host. The bridge host will stay alive as long as any `user` session is connected, regardless of idle state.

### 7.4 Split-server mode

For devcontainer workflows where Studio runs on the host OS but the CLI runs inside a container. The `studio-bridge serve` command starts a dedicated bridge host on the host machine; the devcontainer CLI connects as a client via port forwarding:

```
+-----------------------------+     +-------------------------------+
|        Devcontainer         |     |         Host OS                |
|                             |     |                                |
|  nevermore test --local ----+-----+---> localhost:38741             |
|  studio-bridge exec '...'  | TCP |    (bridge host via serve)     |
|                             |     |         |                      |
+-----------------------------+     |     WebSocket                  |
                                    |         |                      |
                                    |    +----v-----+                |
                                    |    | Studio   |                |
                                    |    | Plugin   |                |
                                    |    +----------+                |
                                    +-------------------------------+
```

The user runs `studio-bridge serve` on the host machine. This starts a dedicated headless bridge host on port 38741. Alternatively, `studio-bridge terminal --keep-alive` serves the same role with a REPL attached. The devcontainer CLI connects to `localhost:38741` (port-forwarded) as a client.

The `serve` command is a thin wrapper: it calls `BridgeConnection.connectAsync({ keepAlive: true })` and sets up signal handling. There is no separate daemon process, no PID files, no auth tokens. All bridge host logic lives in `src/bridge/internal/bridge-host.ts`. The `serve` command lives in `src/commands/serve.ts` like any other command. Environment detection for auto-detecting devcontainers lives in `src/bridge/internal/environment-detection.ts`.

Details in `05-split-server.md`.

## 8. Migration Strategy

### 8.1 Phase 1: Protocol v2 + bridge host module (non-breaking)

1. Add v2 message types, capability negotiation, and `requestId` correlation to the protocol module
2. Build the `src/bridge/` module: `BridgeConnection`, `BridgeSession` (public), `bridge-host`, `bridge-client`, hand-off protocol (internal)
3. Build `PendingRequestMap` for request/response correlation
4. Integrate `BridgeConnection` into the existing `StudioBridgeServer` class (transparent wrapper; re-exported as `StudioBridge` via `export { StudioBridgeServer as StudioBridge }`)
5. Add v2 handshake support and action dispatch to `StudioBridgeServer`
6. All existing behavior unchanged -- temporary plugin injection remains the default

At this point, the bridge host infrastructure is in place but no user-visible behavior has changed.

### 8.2 Phase 2: Unified plugin upgrade (opt-in persistent mode)

1. Upgrade the existing `templates/studio-bridge-plugin/` with the unified source that supports both boot modes (persistent discovery and ephemeral direct-connect)
2. Ship the `install-plugin` command that builds the unified plugin without template substitution (persistent mode) and installs it to the Studio plugins folder
3. Add health endpoint to the bridge host for plugin discovery
4. Add detection in `BridgeConnection`: if persistent plugin is installed, wait for plugin to discover the host; if not, build the unified plugin with substituted constants (ephemeral mode) and inject it
5. Add `sessions` CLI command that queries the bridge host's connected plugin list
6. Add `--session` flag and session selection to existing commands (`exec`, `run`, `terminal`)
7. Ephemeral injection remains as fallback (same plugin source, different build)

Users who run `studio-bridge install-plugin` get the persistent experience. Everyone else gets the same plugin code but in ephemeral mode -- identical to current behavior but with v2 capabilities.

### 8.3 Phase 3: Protocol extensions (additive)

1. Implement action handlers in the persistent plugin for each new capability: state query, screenshot, DataModel inspection, log retrieval
2. Implement server-side action wrappers and CLI commands for each capability
3. Add terminal dot-commands for all new actions
4. Add `subscribe`/`unsubscribe` for push events (`stateChange`, `logPush`) via the WebSocket push subscription protocol (see `01-protocol.md` section 5.2 and `07-bridge-network.md` section 5.3)

### 8.4 Phase 4: Split-server mode (new command)

1. Add `studio-bridge serve` command (headless bridge host with `--keep-alive`)
2. Add `--remote` flag to CLI for explicit remote connection
3. Add devcontainer auto-detection for implicit remote connection

### 8.5 Library API compatibility -- Public API Freeze

The `StudioBridgeServer` class (re-exported as `StudioBridge` from `index.ts` via `export { StudioBridgeServer as StudioBridge }`, consumed by `LocalJobContext` in `/workspaces/NevermoreEngine/tools/nevermore-cli/src/utils/job-context/local-job-context.ts`) keeps its existing interface.

**Public API Freeze** -- the following method signatures, type exports, and re-exports from `src/index.ts` MUST remain unchanged:

```typescript
// From StudioBridgeServer (exported as StudioBridge via: export { StudioBridgeServer as StudioBridge }):
constructor(options?: StudioBridgeServerOptions)
startAsync(): Promise<void>
executeAsync(options: ExecuteOptions): Promise<StudioBridgeResult>
stopAsync(): Promise<void>
```

These are consumed by `LocalJobContext` in `/workspaces/NevermoreEngine/tools/nevermore-cli/src/utils/job-context/local-job-context.ts`. New methods and new exports are additive and permitted; changes to the above signatures are not.

New capabilities are exposed through:
- Additional optional fields on `StudioBridgeServerOptions` (e.g., `preferPersistentPlugin`)
- New methods on the class (e.g., `queryStateAsync`, `captureScreenshotAsync`, `queryDataModelAsync`, `queryLogsAsync`)
- New standalone exports (`BridgeConnection`, `BridgeSession`, result types, error types)

## 9. MCP Integration

PRD requirement F7 specifies that all capabilities (F1-F6) must be exposed as MCP tools. The MCP server is a long-lived process that shares session state with the CLI. Full design: `06-mcp-server.md`.

### 9.1 MCP tool mapping

| MCP Tool | PRD Feature | Protocol Messages Used |
|----------|-------------|----------------------|
| `studio_sessions` | F1: Session Discovery | `BridgeConnection.listSessions()` (no plugin message needed) |
| `studio_state` | F2: Studio State | `queryState` / `stateResult` |
| `studio_screenshot` | F3: Screenshots | `captureScreenshot` / `screenshotResult` (returns base64 in tool response) |
| `studio_logs` | F4: Output Logs | `queryLogs` / `logsResult` |
| `studio_query` | F5: DataModel Queries | `queryDataModel` / `dataModelResult` |
| `studio_exec` | F6: Script Execution | `execute` / `scriptComplete` + `output` |

### 9.2 Architecture

The MCP server runs as `studio-bridge mcp` (a new CLI command, added to the component map). It is a thin adapter over the same `CommandDefinition` handlers used by the CLI and terminal -- it does not have its own business logic. Each MCP tool is generated from a `CommandDefinition` via `createMcpTool()`. See `02-command-system.md` for the unified handler pattern and `06-mcp-server.md` for the full MCP server design.

The MCP server:
- Starts a long-lived process that speaks the MCP protocol over stdio
- Connects to the bridge host (or becomes the host) via `BridgeConnection`
- Registers MCP tools from `allCommands.filter(c => c.mcpEnabled !== false)`
- Returns structured JSON tool responses (not formatted text)
- Uses MCP error codes for failures (not process exit codes)
- Returns base64 image data for screenshots (MCP image content blocks)

### 9.3 Session selection in MCP

MCP tools accept optional `sessionId` and `context` parameters. The auto-selection heuristic matches the CLI via the shared `resolveSessionAsync` utility: if exactly one instance exists, select its Edit context (or the specified `context`); if multiple instances exist, return an error listing available instances so the agent can choose. The `--context` parameter allows targeting `server` or `client` contexts in Play mode. Unlike the CLI, the MCP server does NOT launch Studio when no sessions are available -- it returns an error with guidance.

### 9.4 Configuration

Register studio-bridge as an MCP tool provider in Claude Code:

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

## 10. Security Considerations

### 10.1 Increased attack surface with persistent plugin

The temporary plugin model has a narrow security window: the plugin only exists for the duration of a test run. The persistent plugin is always loaded in Studio, which means:

**Risk: Localhost port scanning**
Any process on the machine can connect to the WebSocket server. Mitigations:
- WebSocket upgrade is only accepted on `/plugin` and `/client` paths; all other paths return 404
- The bridge host validates plugin `register` messages before accepting connections
- In ephemeral mode, the session ID in the WebSocket path acts as an unguessable token (UUIDv4), preserving existing behavior
- All connections (including split-server mode) are localhost-only or over secure port-forwarded localhost

**Risk: Stale plugin after uninstall**
If a user uninstalls studio-bridge but the persistent plugin remains, it will keep attempting discovery connections. Mitigations:
- `install-plugin` command prints clear instructions about how to uninstall
- Plugin has a configurable inactivity timeout after which it stops polling
- The plugin's polling (HTTP GET to `localhost:38741/health` with 500ms timeout) is lightweight

### 10.2 No new network exposure

The system only binds to `localhost`. No external network access is introduced. The persistent plugin uses the same `HttpService:CreateWebStreamClient` API as the temporary plugin, which Roblox restricts to `localhost` in Studio.

### 10.3 CI environments

In CI (GitHub Actions, etc.), the persistent plugin is not installed. The system falls back to temporary plugin injection, which requires no persistent state on the machine. The bridge host pattern has no disk state to clean up.

## 11. Reference: Current File Paths

These are the existing source files that the implementation will modify or interact with:

| File | Role |
|------|------|
| `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/studio-bridge-server.ts` | Main server class with state machine |
| `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/web-socket-protocol.ts` | Message types and JSON codec |
| `/workspaces/NevermoreEngine/tools/studio-bridge/src/plugin/plugin-injector.ts` | Temporary plugin build + inject |
| `/workspaces/NevermoreEngine/tools/studio-bridge/src/process/studio-process-manager.ts` | Studio path resolution + launch |
| `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/cli.ts` | CLI entry point with yargs |
| `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/script-executor.ts` | Shared exec lifecycle for CLI commands |
| `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/args/global-args.ts` | `StudioBridgeGlobalArgs` interface |
| `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/commands/exec-command.ts` | `exec <code>` command |
| `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/commands/run-command.ts` | `run <file>` command |
| `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/commands/terminal/terminal-command.ts` | `terminal` command |
| `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/commands/terminal/terminal-mode.ts` | REPL orchestration |
| `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/commands/terminal/terminal-editor.ts` | Raw-mode editor |
| `/workspaces/NevermoreEngine/tools/studio-bridge/src/index.ts` | Public API exports |
| `/workspaces/NevermoreEngine/tools/studio-bridge/templates/studio-bridge-plugin/src/StudioBridgePlugin.server.lua` | Current plugin Luau source |
| `/workspaces/NevermoreEngine/tools/nevermore-cli/src/utils/job-context/local-job-context.ts` | Library consumer in nevermore-cli |
