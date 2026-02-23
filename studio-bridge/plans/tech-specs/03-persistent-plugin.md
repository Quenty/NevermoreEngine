# Unified Plugin: Technical Specification

This document describes the Luau architecture, boot mode detection, discovery protocol, reconnection logic, and installation flow for the studio-bridge unified plugin. It is the companion document referenced from `00-overview.md` section 5 and section 2.1. For protocol message definitions and TypeScript types, see `01-protocol.md`.

## 1. Overview

The studio-bridge plugin is a single Luau source that boots in one of two modes depending on whether build-time constants are present:

- **Ephemeral mode**: The plugin is built with `IS_EPHEMERAL = true`, a numeric `PORT`, and a UUID `SESSION_ID`. Build constants are injected via a two-step pipeline: Handlebars template substitution (in TemplateHelper) replaces placeholders like `{{IS_EPHEMERAL}}`, `{{PORT}}`, and `{{SESSION_ID}}` in the Lua source, then Rojo builds the substituted sources into an `.rbxm` plugin file. It connects directly to the known server at the hardcoded port -- no discovery, no polling. This is used in CI environments and as a fallback when the persistent plugin is not installed. The plugin is injected per session by `StudioBridgeServer.startAsync()` and deleted on `stopAsync()`.
- **Persistent mode**: The plugin is built with `IS_EPHEMERAL = false`, `PORT = nil`, and `SESSION_ID = nil` (the same two-step pipeline runs, but with these default values). It is installed once to the user's local plugins folder via `studio-bridge install-plugin`. At startup, it checks `IS_EPHEMERAL` and enters the discovery loop: polls HTTP health endpoints on candidate ports, connects via WebSocket, and maintains that connection across server restarts through automatic reconnection.

Both modes share the same action handlers, protocol logic, serialization, and log buffering. The plugin supports the full v2 protocol (execute, state queries, screenshots, DataModel inspection, log retrieval) and degrades gracefully to v1 when connected to an older server. Having one source eliminates code drift between the two modes and ensures that bug fixes and new capabilities apply everywhere.

### 1.1 Multi-context plugin instances

When Studio enters Play mode, Roblox creates 2 new separate plugin instances in addition to the already-running edit instance. Each runs in its own Luau execution environment with its own DataModel:

- **Edit context**: The plugin instance attached to the edit DataModel. Always present while Studio is open. **It continues running unchanged during Play mode** -- it is never stopped or restarted by Play mode transitions.
- **Server context**: A new plugin instance created in the Play-mode server DataModel. Appears when Play starts, destroyed when Play stops.
- **Client context**: A new plugin instance created in the Play-mode client DataModel. Appears when Play starts, destroyed when Play stops.

The edit instance is already connected to the bridge host before Play mode starts. The 2 new instances (server and client) independently detect their context (see section 4.4), open their own WebSocket connections to the bridge host, and send their own `register` messages. The bridge host sees the 2 new sessions join the existing edit session, all sharing the same `instanceId` but with different `context` values. No coordination between instances is needed -- this is natural behavior that falls out of how Roblox Studio creates plugin instances.

The `instanceId` is stored in `PluginSettings` (per-installation), so all 3 instances within the same Studio installation share the same `instanceId`. This allows the bridge host to correlate contexts that belong to the same Studio. The `context` field in the `register` message distinguishes them.

```
Studio Installation A
  ├── Edit plugin instance ──── ws://localhost:38741/plugin ──→ session "abc" (context=edit)
  ├── Server plugin instance ── ws://localhost:38741/plugin ──→ session "def" (context=server)
  └── Client plugin instance ── ws://localhost:38741/plugin ──→ session "ghi" (context=client)

Studio Installation B
  ├── Edit plugin instance ──── ws://localhost:38741/plugin ──→ session "jkl" (context=edit)
  ├── Server plugin instance ── ws://localhost:38741/plugin ──→ session "mno" (context=server)
  └── Client plugin instance ── ws://localhost:38741/plugin ──→ session "pqr" (context=client)
```

All 6 sessions connect to the same bridge host. The bridge host distinguishes them by session ID and can group them by `instanceId` and `context`.

## 2. Plugin Management System (Universal)

The plugin build, discovery, and installation system is a **general-purpose utility, not a feature specific to studio-bridge**. studio-bridge is its first consumer, but the system is designed so that future persistent plugins (e.g., a Rojo integration plugin, a testing plugin, a remote debugging plugin) can use the same infrastructure without modifying the manager itself.

The key insight: plugin management (build from template, discover the Studio plugins folder, install, track versions, uninstall) is a reusable operation that any Nevermore tool might need. By making the API generic from the start, we avoid the common pattern of building a one-off installer and then painfully generalizing it later.

### 2.0 PluginTemplate interface

Every installable plugin is described by a `PluginTemplate`. This is the registration contract: a template declares its name, where its source lives, what build constants to substitute, and a human-readable description. The plugin manager operates entirely on `PluginTemplate` values -- it never hard-codes paths or names for any specific plugin.

```typescript
/**
 * Describes a plugin that can be built and installed into Roblox Studio.
 *
 * Each tool that ships a persistent plugin creates one of these and
 * registers it with the PluginManager. The manager handles all
 * build/install/uninstall operations generically.
 */
export interface PluginTemplate {
  /** Unique identifier for this plugin, e.g., "studio-bridge" */
  name: string;

  /** Absolute path to the template source directory (contains default.project.json) */
  templateDir: string;

  /**
   * Build constants substituted by Handlebars (via TemplateHelper) before Rojo builds the .rbxm.
   * For persistent mode these are typically the "unsubstituted" defaults.
   * For ephemeral mode, the caller overrides specific keys.
   */
  buildConstants: Record<string, string | number | boolean>;

  /** Human-readable description shown in CLI output */
  description: string;

  /** Output filename for the built .rbxm (e.g., "StudioBridgePlugin.rbxm") */
  outputFileName: string;

  /**
   * Optional version string embedded in the plugin source.
   * Used for upgrade detection without rebuilding.
   */
  version?: string;
}
```

### 2.0.1 Plugin registry

Plugin templates are registered, not hard-coded. Each tool that ships a persistent plugin registers its template with the plugin manager. studio-bridge registers its own:

```typescript
import { resolveTemplatePath } from '@quenty/nevermore-template-helpers';

// studio-bridge registers its plugin template
const studioBridgePlugin: PluginTemplate = {
  name: 'studio-bridge',
  templateDir: resolveTemplatePath(import.meta.url, 'studio-bridge-plugin'),
  buildConstants: { PORT: '{{PORT}}', SESSION_ID: '{{SESSION_ID}}' },
  description: 'Studio-bridge persistent connection plugin',
  outputFileName: 'StudioBridgePlugin.rbxm',
  version: '1.0.0',
};

// Future plugins would register their own templates:
//
// const rojoPlugin: PluginTemplate = {
//   name: 'rojo-sync',
//   templateDir: resolveTemplatePath(import.meta.url, 'rojo-sync-plugin'),
//   buildConstants: { SYNC_MODE: 'automatic' },
//   description: 'Rojo live-sync integration for Studio',
//   outputFileName: 'RojoSyncPlugin.rbxm',
//   version: '0.1.0',
// };
//
// const debugPlugin: PluginTemplate = {
//   name: 'remote-debug',
//   templateDir: resolveTemplatePath(import.meta.url, 'remote-debug-plugin'),
//   buildConstants: { DEBUG_PORT: '9229' },
//   description: 'Remote debugging support for Studio',
//   outputFileName: 'RemoteDebugPlugin.rbxm',
//   version: '0.1.0',
// };
```

The registry is a simple array or map of `PluginTemplate` values. The plugin manager iterates over registered templates when listing installed plugins, and individual commands reference templates by name.

### 2.0.2 PluginManager API

The `PluginManager` class provides all build, discover, install, and uninstall operations. It is parameterized by `PluginTemplate` -- it never assumes which plugin it is operating on. All methods accept a template (or plugin name to look up in the registry) and operate generically.

```typescript
export interface InstalledPlugin {
  /** The template name this was installed from */
  name: string;
  /** Absolute path to the installed .rbxm file */
  pluginPath: string;
  /** Version from the version tracking sidecar */
  version: string;
  /** When the plugin was installed */
  installedAt: Date;
  /** Hash of the built .rbxm for change detection */
  templateHash: string;
}

export interface BuiltPlugin {
  /** The template this was built from */
  template: PluginTemplate;
  /** Absolute path to the built .rbxm file in a temp directory */
  builtPath: string;
  /** SHA-256 hash of the built file */
  hash: string;
  /** Cleanup function to remove the temp build directory */
  cleanupAsync: () => Promise<void>;
}

export interface BuildOverrides {
  /** Override specific build constants (e.g., { PORT: '49201', SESSION_ID: 'abc-123' } for ephemeral mode) */
  constants?: Record<string, string>;
}

/**
 * Manages the lifecycle of Roblox Studio plugins.
 *
 * This is a general-purpose utility. studio-bridge is its first consumer,
 * but any tool that needs to install a persistent plugin into Studio can
 * use this same manager by registering a PluginTemplate.
 *
 * The manager handles:
 * - Discovering the Studio plugins folder (platform-specific)
 * - Building plugins from templates via Rojo
 * - Installing built plugins to the Studio folder with version tracking
 * - Listing currently installed plugins
 * - Uninstalling plugins cleanly
 */
export class PluginManager {
  private _templates: Map<string, PluginTemplate> = new Map();

  /** Register a plugin template. Call this during tool initialization. */
  registerTemplate(template: PluginTemplate): void;

  /** Get a registered template by name. */
  getTemplate(name: string): PluginTemplate | undefined;

  /** List all registered templates. */
  listTemplates(): PluginTemplate[];

  /**
   * Discover the Roblox Studio plugins directory.
   * - macOS: ~/Documents/Roblox/Plugins/
   * - Windows: %LOCALAPPDATA%/Roblox/Plugins/
   * Throws if the directory cannot be determined.
   */
  async discoverPluginsDirAsync(): Promise<string>;

  /**
   * List all plugins installed by this manager (across all templates).
   * Reads from the version tracking sidecar files.
   */
  async listInstalledAsync(): Promise<InstalledPlugin[]>;

  /**
   * Check whether a specific plugin is installed.
   * Reads the sidecar metadata -- does not inspect the Studio folder directly.
   */
  async isInstalledAsync(name: string): Promise<boolean>;

  /**
   * Build a plugin from its template.
   * Returns a BuiltPlugin with the path to the .rbxm and a cleanup function.
   * The caller is responsible for calling cleanupAsync() when done.
   *
   * @param template - The plugin template to build
   * @param overrides - Optional constant overrides (for ephemeral mode builds)
   */
  async buildAsync(template: PluginTemplate, overrides?: BuildOverrides): Promise<BuiltPlugin>;

  /**
   * Install a built plugin to the Studio plugins folder.
   * Writes the .rbxm and updates the version tracking sidecar.
   *
   * @param built - The built plugin (from buildAsync)
   * @param options - Install options (force overwrite, etc.)
   */
  async installAsync(built: BuiltPlugin, options?: { force?: boolean }): Promise<InstalledPlugin>;

  /**
   * Uninstall a plugin by name.
   * Removes the .rbxm from the Studio plugins folder and the version tracking sidecar.
   */
  async uninstallAsync(name: string): Promise<void>;
}
```

### 2.0.3 Extensibility contract

The plugin management system is designed around these invariants:

1. **Adding a new plugin never requires modifying PluginManager.** A new plugin is added by creating a `PluginTemplate` and calling `registerTemplate()`. The manager's build, install, and uninstall methods work unchanged.

2. **Each plugin owns its template directory.** Templates live alongside the tool that defines them (e.g., `templates/studio-bridge-plugin/` for studio-bridge). The manager does not prescribe where templates are stored.

3. **Version tracking is per-plugin.** Each installed plugin gets its own sidecar metadata at `~/.nevermore/<tool-name>/plugin/<plugin-name>/version.json`. Plugins do not interfere with each other's version state.

4. **The CLI surface is composable.** The `install-plugin` and `uninstall-plugin` commands accept a `--plugin` flag (or default to the tool's primary plugin). Future tools can expose their own install commands that delegate to the same `PluginManager`.

Future plugins that could use this infrastructure include:
- **Rojo integration plugin**: A persistent plugin that syncs project state between Rojo and Studio, built from its own template directory.
- **Testing plugin**: A persistent plugin that provides in-Studio test running UI, installed via `nevermore install-plugin --plugin test-runner`.
- **Remote debugging plugin**: A persistent plugin that exposes a debug protocol endpoint inside Studio.

Each of these would define a `PluginTemplate`, register it, and use the same `PluginManager` build/install/uninstall flow without any changes to the manager itself.

### 2.1 Install command

```
studio-bridge install-plugin [--force]
```

This command applies to **persistent mode** only. In ephemeral mode, the plugin is injected automatically by the server (existing behavior) and no installation step is needed.

The command delegates to `PluginManager` using the studio-bridge plugin template:

1. Look up the `studio-bridge` template from the plugin registry.
2. Call `pluginManager.buildAsync(template)` to build the template into `StudioBridgePlugin.rbxm`. The build runs a two-step pipeline: first, Handlebars template substitution (via TemplateHelper) replaces placeholders in the Lua source; then Rojo builds the substituted sources into the `.rbxm`. The persistent-mode build uses the template's default `buildConstants` (which leave `{{PORT}}` and `{{SESSION_ID}}` as raw placeholders), causing the plugin to boot in persistent mode.
3. Call `pluginManager.installAsync(built, { force })` to copy the built file to the Studio plugins folder (discovered via `discoverPluginsDirAsync()`).
4. The install method checks for an existing installation:
   - If present and `--force` is not set, compare hashes. Skip if already up to date; overwrite if outdated.
   - If present and `--force` is set, overwrite unconditionally.
   - If absent, copy the built file.
5. Print confirmation with the installed version and the plugins folder path.
6. Call `built.cleanupAsync()` to remove the temp build directory.

### 2.2 Version tracking

The plugin embeds a version string as a constant in `StudioBridgePlugin.server.lua`:

```lua
local PLUGIN_VERSION = "1.0.0"
```

The `PluginManager` maintains a per-plugin sidecar file for version tracking. For studio-bridge, this is at `~/.nevermore/studio-bridge/plugin/studio-bridge/version.json`:

```json
{
  "pluginName": "studio-bridge",
  "version": "1.0.0",
  "installedAt": "2026-02-20T10:30:00Z",
  "templateHash": "sha256:abc123...",
  "outputFileName": "StudioBridgePlugin.rbxm"
}
```

The `installAsync` method computes a SHA-256 hash of the built `.rbxm` and compares it to the stored hash. If they match, the plugin is already up to date. The sidecar path uses the plugin name as a subdirectory, so multiple plugins have independent version tracking.

### 2.3 Uninstall command

```
studio-bridge uninstall-plugin
```

This command delegates to `pluginManager.uninstallAsync('studio-bridge')`:

1. Look up the installed plugin metadata from the sidecar file.
2. Remove `StudioBridgePlugin.rbxm` from the Studio plugins folder.
3. Remove the version tracking sidecar at `~/.nevermore/studio-bridge/plugin/studio-bridge/version.json`.
4. Print confirmation. Note that Studio must be restarted for uninstallation to take effect.

### 2.4 Plugin filename

Each plugin template specifies its `outputFileName` (e.g., `StudioBridgePlugin.rbxm`). Using a fixed name per plugin ensures that reinstallation replaces the previous version rather than accumulating copies. Different plugins use different filenames, so they coexist in the Studio plugins folder without conflict.

## 3. Discovery Mechanism

Discovery only runs in **persistent mode**. In ephemeral mode, the plugin has hardcoded `PORT` and `SESSION_ID` constants and connects directly -- it skips the entire discovery mechanism described in this section.

The persistent-mode plugin cannot read the file-based session registry (`~/.nevermore/studio-bridge/sessions/`) because Roblox Studio plugins have no filesystem access beyond `plugin:GetSetting`/`plugin:SetSetting`. Instead, it discovers servers by polling HTTP health endpoints.

### 3.0 Discovery model: many-to-one

Discovery is many-to-one, not many-to-many. There is exactly one bridge host. All plugins connect to it. All CLI/MCP processes either are the host or connect to it.

The bridge host is the single WebSocket server running on port 38741. It is the rendezvous point for the entire system. Every participant connects to it:

```
Studio A ─── edit context ──────┐
         ├── server context ────┤
         └── client context ────┤
                                ├──→ Bridge Host (:38741) ←──┬── CLI (host process)
Studio B ─── edit context ──────┤                             ├── CLI (client)
         ├── server context ────┤                             └── MCP server (client)
         └── client context ────┘
```

- **Left side (plugin instances)**: Any number of Roblox Studio instances, each running up to 3 plugin contexts (edit is always present; server and client appear during Play mode). Each plugin instance independently polls `localhost:38741/health` to discover the bridge host. When it responds, the plugin connects via WebSocket on the `/plugin` path.
- **Center (bridge host)**: Exactly one process owns port 38741. This is the first CLI process that started (`BridgeConnection.connectAsync()` tries to bind the port; success = host). The bridge host accepts plugin connections and client connections, tracks all sessions, and routes commands between them.
- **Right side (CLI/MCP clients)**: Any number of CLI or MCP processes that connect to the bridge host on the `/client` path. They send commands (e.g., "execute this script on session X"), and the bridge host forwards them to the correct plugin.

This topology means there is never a question of "which host should this plugin connect to?" -- there is only one. There is never a question of "which plugin handles this command?" -- the CLI specifies a session ID, and the bridge host looks it up in its session map.

#### Why not many-to-many?

A many-to-many model (multiple hosts, each with their own set of plugins) would require plugins to choose between hosts, hosts to coordinate session ownership, and CLI clients to know which host has their session. This adds complexity with no benefit:

- Multiple CLI processes already coordinate through the single bridge host (one is the host, the rest are clients).
- Multiple Studio instances already coordinate through the single bridge host (each gets a unique session ID).
- If the bridge host crashes, the hand-off protocol (section 7.2 in `00-overview.md`) ensures a client takes over the port. Plugins reconnect to the new host automatically. The system self-heals without any multi-host coordination.

#### Discovery flow (step-by-step)

When a persistent plugin instance starts in Studio, it enters this flow. Each context (edit, client, server) runs this flow independently:

1. **Poll health endpoint**: The plugin sends `HTTP GET localhost:38741/health` every 2 seconds. Each request has a 500ms timeout.
2. **Evaluate response**: If the response is HTTP 200 with valid JSON containing `status: "ok"`, the bridge host is alive.
3. **Open WebSocket**: The plugin connects to `ws://localhost:38741/plugin`.
4. **Send `register`**: On WebSocket open, the plugin generates a UUID (via `HttpService:GenerateGUID()`) and sends a `register` message with this UUID as the proposed `sessionId`, along with its instance ID, context (`"edit"`, `"client"`, or `"server"`), place name, place ID, game ID, Studio state, and capabilities.
5. **Receive `welcome`**: The bridge host accepts the plugin's proposed session ID (or overrides it if there is a collision), stores the session in its in-memory tracker, and responds with a `welcome` message containing the authoritative `sessionId` and negotiated capabilities. The plugin must use the `sessionId` from the `welcome` response for all subsequent messages.
6. **Enter connected state**: The plugin stops polling, adopts the `sessionId` from the `welcome` response, starts processing commands, and begins sending heartbeats.

If the bridge host is not running (no response to health checks), the plugin stays in step 1, polling indefinitely with the 2-second interval. When a CLI process eventually starts and binds port 38741, the plugin discovers it on the next poll cycle.

#### Race conditions

**Multiple plugin contexts connect simultaneously**: When Studio enters Play mode, 2 new plugin instances (server and client) are created alongside the already-connected edit instance. The 2 new instances may discover the bridge host and connect within the same poll cycle. Each plugin context generates its own UUID as the proposed session ID. The bridge host processes WebSocket connections serially (Node.js event loop) and accepts each proposed session ID (collisions are astronomically unlikely with UUIDs, but the server overrides on collision). All 3 enter the connected state independently. There is no conflict -- the bridge host's session tracker is a simple map keyed by session ID, and it uses the shared `instanceId` plus distinct `context` field to group them.

**Bridge host crashes (kill -9, unhandled exception)**: All plugins detect the WebSocket disconnect via the `Closed` or `Error` event. Each plugin enters the `reconnecting` state with exponential backoff, then returns to `searching` (polling the health endpoint). Meanwhile, a connected CLI client detects the disconnect, waits a random jitter (0-500ms), and attempts to bind port 38741 to become the new host. When the new host is up, plugins discover it on their next poll cycle, connect, and re-register. The bridge host treats them as new sessions -- previous session state (subscriptions, in-flight requests) is lost, which is correct because the host that held that state is gone.

**Bridge host restarts (graceful stop + new CLI start)**: The bridge host sends `shutdown` to all plugins before closing. Plugins receive `shutdown`, disconnect cleanly, and return to `searching` with no backoff (clean disconnect). When the new CLI process starts and binds the port, plugins discover it immediately on the next 2-second poll cycle.

**No bridge host is running**: Plugins poll `localhost:38741/health` every 2 seconds. Each health check is a lightweight HTTP GET with a 500ms timeout. The request fails immediately (connection refused). The plugin stays in `searching` state indefinitely, waiting for a CLI process to start. This is by design -- the plugin is dormant until someone starts a CLI.

#### Session disambiguation

Sessions are identified by session ID (a UUID generated by the plugin and proposed in the `register` message, then confirmed or overridden by the bridge host in the `welcome` response). The bridge host maintains a map of session ID to WebSocket connection. There is no routing ambiguity:

- When a CLI consumer calls `session.execAsync(...)`, the command includes the session ID.
- The bridge host looks up the session ID in its tracker and forwards the command over the corresponding plugin WebSocket.
- The plugin's response includes the same session ID, and the bridge host routes it back to the requesting CLI client.

If multiple Studios are connected, the CLI uses `bridge.listSessionsAsync()` to see all sessions and `bridge.getSession(id)` to target a specific one. Sessions can also be filtered by `context` (e.g., show only server contexts) or grouped by `instanceId` (show all contexts for a specific Studio installation). The auto-selection heuristic (if exactly one session exists, use it; if multiple, prompt) is in the CLI adapter, not the bridge host.

The plugin persists an **instance ID** (UUID stored in `plugin:SetSetting("StudioBridge_InstanceId")`) that survives across Studio restarts. This is sent in the `register` message along with the **context** (`"edit"`, `"client"`, or `"server"`). The bridge host uses `instanceId` to group contexts from the same Studio installation and `context` to distinguish them. For routing purposes, only the session ID matters -- `instanceId` and `context` are metadata for display and filtering.

#### Debugging discovery

When discovery is not working, use these tools:

- **`studio-bridge sessions`**: Shows all currently connected sessions (session ID, place name, Studio state, plugin version, connected duration). If no sessions appear, either no Studio is running or the plugin is not connecting.
- **`studio-bridge sessions --watch`**: Streams connection and disconnection events in real time. Useful for seeing whether a plugin connects and immediately disconnects (handshake failure) vs. never connects at all (network issue).
- **Health endpoint**: `curl localhost:38741/health` returns the bridge host status and connected session count. If this returns connection refused, no bridge host is running. If it returns 200 but shows 0 sessions, the bridge host is up but no plugins have connected.
- **Plugin output in Studio**: The plugin logs all state transitions to Studio's Output window with a `[StudioBridge]` prefix:
  - `[StudioBridge] Persistent mode, searching for server...` -- plugin started, polling for host
  - `[StudioBridge] searching -> connecting` -- health check succeeded, opening WebSocket
  - `[StudioBridge] connecting -> connected` -- handshake complete
  - `[StudioBridge] connected -> reconnecting` -- connection lost
  - `[StudioBridge] reconnecting -> searching` -- backoff expired, resuming poll
- **Bridge host debug logs**: The bridge host logs connection events at debug level. Set `DEBUG=studio-bridge:*` (or the equivalent log level flag) to see:
  - `plugin connected from /plugin (instanceId=xxx)` -- WebSocket opened
  - `session registered: sessionId=xxx, placeName=xxx` -- `register` processed
  - `plugin disconnected: sessionId=xxx` -- WebSocket closed
  - `client connected from /client` -- CLI client joined

Common issues:
- **Plugin says "searching" forever**: The bridge host is not running. Start a CLI process (`studio-bridge exec`, `studio-bridge terminal`, etc.) to create the host.
- **Plugin connects then immediately disconnects**: Check the Output window for errors. Common cause: protocol version mismatch (old server that does not understand `register`; the plugin should fall back to `hello` after 3 seconds).
- **Sessions show in CLI but commands time out**: The plugin is connected but not responding. Check Studio's Output for errors in the plugin's action handlers. The plugin may be blocked (e.g., a long-running script holding the Luau thread).
- **Health endpoint returns 200 but plugin is not connecting**: Check that Studio's `HttpService` is enabled (Game Settings > Security > Allow HTTP Requests). The persistent plugin uses `HttpService:RequestAsync` for health checks.

### 3.1 Health endpoint

The bridge host exposes an HTTP GET `/health` endpoint on port 38741. The response is JSON:

```json
{
  "status": "ok",
  "port": 38741,
  "protocolVersion": 2,
  "serverVersion": "0.5.0",
  "sessions": 2,
  "uptime": 45230
}
```

The plugin uses `HttpService:RequestAsync` to poll this endpoint. A successful 200 response with valid JSON indicates a live bridge host. Note: the health endpoint does not include a `sessionId` -- the plugin generates its own session ID when sending `register`.

### 3.2 Port scanning strategy

The plugin maintains an ordered list of candidate ports and tries them sequentially:

1. **Well-known port 38741** -- tried first. In split-server mode, the daemon binds to this port. In single-process mode, the server may also prefer this port if available.
2. **Known ports from plugin settings** -- `plugin:SetSetting("StudioBridge_KnownPorts")` stores a JSON-encoded array of ports that have previously been seen. The server tells the plugin about its port during the `welcome` handshake, and the plugin persists it for future discovery.
3. **Scan range** -- as a last resort, scan ports 38741-38760 (a 20-port window). This is narrow enough to complete quickly but wide enough to find multiple concurrent servers.

### 3.3 Discovery loop pseudocode

```lua
local WELL_KNOWN_PORT = 38741
local SCAN_RANGE_START = 38741
local SCAN_RANGE_END = 38760
local POLL_INTERVAL = 2 -- seconds

function Discovery.findServerAsync(plugin)
    local knownPorts = Discovery._getKnownPorts(plugin)
    local candidatePorts = Discovery._buildCandidateList(knownPorts)

    for _, port in ipairs(candidatePorts) do
        local health = Discovery._tryHealthCheck(port)
        if health and health.status == "ok" then
            return {
                port = port,
                protocolVersion = health.protocolVersion or 1,
            }
        end
    end

    return nil -- no server found this cycle
end

function Discovery._buildCandidateList(knownPorts)
    local seen = {}
    local list = {}

    -- Well-known port first
    table.insert(list, WELL_KNOWN_PORT)
    seen[WELL_KNOWN_PORT] = true

    -- Known ports from previous connections
    for _, port in ipairs(knownPorts) do
        if not seen[port] then
            table.insert(list, port)
            seen[port] = true
        end
    end

    -- Scan range for anything we haven't tried
    for port = SCAN_RANGE_START, SCAN_RANGE_END do
        if not seen[port] then
            table.insert(list, port)
            seen[port] = true
        end
    end

    return list
end

function Discovery._tryHealthCheck(port)
    local url = "http://localhost:" .. tostring(port) .. "/health"
    local ok, response = pcall(function()
        return HttpService:RequestAsync({
            Url = url,
            Method = "GET",
        })
    end)

    if not ok or not response or response.StatusCode ~= 200 then
        return nil
    end

    local decodeOk, health = pcall(function()
        return HttpService:JSONDecode(response.Body)
    end)

    if not decodeOk or type(health) ~= "table" then
        return nil
    end

    return health
end

function Discovery._getKnownPorts(plugin)
    local raw = plugin:GetSetting("StudioBridge_KnownPorts")
    if type(raw) ~= "string" then
        return {}
    end
    local ok, ports = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if ok and type(ports) == "table" then
        return ports
    end
    return {}
end

function Discovery._saveKnownPort(plugin, port)
    local ports = Discovery._getKnownPorts(plugin)
    -- Avoid duplicates, keep most recent first
    local filtered = { port }
    for _, p in ipairs(ports) do
        if p ~= port then
            table.insert(filtered, p)
        end
    end
    -- Cap at 20 entries
    if #filtered > 20 then
        filtered = { unpack(filtered, 1, 20) }
    end
    plugin:SetSetting("StudioBridge_KnownPorts", HttpService:JSONEncode(filtered))
end
```

### 3.4 Polling interval

- **Searching state**: Poll every 2 seconds. Each cycle iterates the full candidate list. Individual health checks time out after 500ms to avoid blocking.
- **Connected state**: Polling stops entirely. The connection is maintained via WebSocket events and heartbeat.
- **Reconnecting state**: Polling resumes after the backoff delay (see section 6).

## 4. Plugin State Machine

### 4.0 Boot mode detection

The state machine begins with a mode branch. The build pipeline substitutes an `IS_EPHEMERAL` boolean constant directly (Handlebars replaces the `{{IS_EPHEMERAL}}` placeholder, then Rojo builds the result), so the plugin checks it without any string comparison tricks:

```
idle → check IS_EPHEMERAL
  ├── IS_EPHEMERAL == true (PORT is a number, SESSION_ID is a UUID):
  │     connect directly to PORT/SESSION_ID → connected
  │     (no discovery, no reconnection -- plugin is deleted on stopAsync)
  │
  └── IS_EPHEMERAL == false (PORT is nil, SESSION_ID is nil):
        enter discovery loop → searching → connecting → connected
        (full state machine below)
```

In ephemeral mode, the plugin connects directly and enters the `connected` state. If the connection drops, the plugin does not reconnect -- it was injected for a single session. In persistent mode, the full state machine below governs the lifecycle.

### 4.1 States (persistent mode)

Each plugin instance (edit, client, server) has its own independent state machine. The edit instance's state machine is already running (and connected, if a bridge host is available) before Play mode starts. When Studio enters Play mode and creates the server and client plugin instances, each new instance starts its own state machine from `idle`, discovers the bridge host independently, and connects with its own WebSocket. The edit instance is unaffected by Play mode transitions -- it continues running with its existing connection. No coordination between instances is needed -- they are fully independent Luau environments.

| State | Description | Activity |
|-------|-------------|----------|
| `idle` | Plugin just loaded, not yet started | One-time initialization, mode detection |
| `searching` | Polling health endpoints for a server | Discovery loop running every 2s |
| `connecting` | Server found, WebSocket handshake in progress | Waiting for `Opened` event, then sending `register` |
| `connected` | Handshake complete, ready for actions | Processing messages, sending heartbeat |
| `reconnecting` | Connection lost, waiting before retry | Backoff timer, then return to `searching` |

### 4.2 Transitions (persistent mode)

```
    ┌─────────┐
    │  idle    │
    └────┬────┘
         │ RunService:IsStudio() == true
         │ AND mode == persistent
    ┌────▼────┐
    │searching│◄──────────────────────────────────┐
    └────┬────┘                                    │
         │ Discovery._tryHealthCheck() succeeds    │
    ┌────▼──────┐                                  │
    │ connecting │                                  │
    └────┬──┬───┘                                  │
         │  │ WebSocket open fails                 │
         │  └──────────────────────────────────────┘
         │ WebSocket opened + welcome received
    ┌────▼────┐
    │connected│
    └────┬──┬─┘
         │  │ shutdown message received ───────────┐
         │  │                                      │
         │  │ WebSocket closed / error      ┌──────▼──────┐
         │  └───────────────────────────────►│   searching │
         │                                  └─────────────┘
         │ WebSocket closed / error (NOT shutdown)
    ┌────▼───────┐
    │reconnecting│
    └────┬───────┘
         │ backoff timer expires
         │
         └─────────────────────────────────────────► searching
```

In ephemeral mode, the state machine is simplified: `idle → connected`. The `searching`, `connecting`, and `reconnecting` states are never entered.

Key transition rules:

- **idle to searching**: Immediate on plugin load, after verifying Studio environment.
- **searching to connecting**: When a health check returns a valid server.
- **connecting to connected**: When the WebSocket `Opened` event fires and the server responds to `register` (or `hello`) with `welcome`.
- **connecting to searching**: If the WebSocket fails to open within 5 seconds, or if the `Opened` event fires but no `welcome` arrives within 3 seconds of sending `register`.
- **connected to reconnecting**: On WebSocket `Closed` or `Error` event, unless the last received message was `shutdown`.
- **connected to searching**: On receiving a `shutdown` message. This is a clean disconnect -- no backoff needed.
- **reconnecting to searching**: After the backoff timer expires.

### 4.3 State machine pseudocode

```lua
local STATE_IDLE = "idle"
local STATE_SEARCHING = "searching"
local STATE_CONNECTING = "connecting"
local STATE_CONNECTED = "connected"
local STATE_RECONNECTING = "reconnecting"

local currentState = STATE_IDLE
local backoffSeconds = 0
local wsClient = nil
local sessionId = nil
local negotiatedVersion = 1

local function transitionTo(newState)
    local prev = currentState
    currentState = newState
    print("[StudioBridge] " .. prev .. " -> " .. newState)
end

local function runStateMachine(plugin)
    transitionTo(STATE_SEARCHING)

    while true do
        if currentState == STATE_SEARCHING then
            local server = Discovery.findServerAsync(plugin)
            if server then
                -- sessionId will be set by handleWelcome() after the server
                -- confirms or overrides the plugin-generated proposed ID
                transitionTo(STATE_CONNECTING)
                local success = attemptConnection(plugin, server)
                if not success then
                    transitionTo(STATE_SEARCHING)
                end
            else
                task.wait(POLL_INTERVAL)
            end

        elseif currentState == STATE_CONNECTED then
            -- Event-driven in this state; yield until disconnection
            task.wait(1)

        elseif currentState == STATE_RECONNECTING then
            task.wait(backoffSeconds)
            transitionTo(STATE_SEARCHING)
        end
    end
end
```

### 4.4 Context detection

Each plugin instance detects which context it is running in using `RunService` properties. In Play mode, Roblox creates separate DataModels for the server and client, each with its own plugin instance. The `RunService` properties differ per context:

| Context | `IsServer()` | `IsClient()` | `IsRunning()` |
|---------|:------------:|:------------:|:--------------:|
| Edit    | false        | false        | false          |
| Server  | true         | false        | true           |
| Client  | false        | true         | true           |

```lua
local RunService = game:GetService("RunService")

local function detectContext(): string
    -- In Play mode, RunService properties differ per context:
    -- Edit DataModel: IsServer()=false, IsClient()=false, IsRunning()=false
    -- Server context: IsServer()=true, IsRunning()=true
    -- Client context: IsClient()=true, IsRunning()=true
    if RunService:IsServer() and RunService:IsRunning() then
        return "server"
    elseif RunService:IsClient() and RunService:IsRunning() then
        return "client"
    else
        return "edit"
    end
end
```

This is a simplified heuristic. The exact detection may need refinement based on Studio's behavior (e.g., edge cases during Play mode transitions). The context is detected once at plugin startup and does not change for the lifetime of that plugin instance -- if Studio exits Play mode, the server and client plugin instances are destroyed entirely, and new ones are created if Play mode is entered again.

The detected context is included in the `register` message (section 5.2) so the bridge host knows which DataModel environment each session represents.

## 5. Connection Lifecycle

### 5.1 WebSocket connection

Once discovery finds a live server, the plugin opens a WebSocket:

```lua
local function attemptConnection(plugin, server)
    local url = "ws://localhost:" .. tostring(server.port) .. "/plugin"

    local ok, client = pcall(function()
        return HttpService:CreateWebStreamClient(
            Enum.WebStreamClientType.WebSocket,
            { Url = url }
        )
    end)

    if not ok or not client then
        warn("[StudioBridge] WebSocket creation failed: " .. tostring(client))
        return false
    end

    wsClient = client
    -- Wire up event handlers (see section 5.3)
    setupEventHandlers(plugin, client, server)
    return true
end
```

### 5.2 Handshake: register with hello fallback

After the WebSocket `Opened` event fires, the plugin generates a UUID (via `HttpService:GenerateGUID()`) as its proposed session ID and sends a `register` message. If the server is v1 and does not recognize `register`, it will ignore the message. The plugin waits 3 seconds for a `welcome` response. If none arrives, it falls back to sending `hello`. After receiving `welcome`, the plugin must use the `sessionId` from the `welcome` response for all subsequent messages (in case the server overrode the proposed ID).

```lua
local function performHandshake(client, server)
    local instanceId = getOrCreateInstanceId(plugin)

    -- Generate a proposed session ID
    local proposedSessionId = HttpService:GenerateGUID(false)

    -- Try register first (v2)
    Protocol.send(client, "register", proposedSessionId, {
        pluginVersion = PLUGIN_VERSION,
        instanceId = instanceId,
        context = detectContext(), -- "edit", "client", or "server"
        placeName = game.Name,
        placeId = game.PlaceId,
        gameId = game.GameId,
        placeFile = nil, -- not available from plugin context
        state = StateMonitor.getCurrentState(),
        capabilities = {
            "execute", "queryState", "captureScreenshot",
            "queryDataModel", "queryLogs", "subscribe", "heartbeat",
        },
    }, { protocolVersion = 2 })

    -- Wait for welcome
    local welcomeReceived = false
    local startTime = os.clock()

    while not welcomeReceived and (os.clock() - startTime) < 3 do
        task.wait(0.1)
        if negotiatedVersion > 0 then
            welcomeReceived = true
        end
    end

    if not welcomeReceived then
        -- Fallback to hello (v1)
        print("[StudioBridge] No response to register, falling back to hello")
        Protocol.send(client, "hello", proposedSessionId, {
            sessionId = proposedSessionId,
        })

        -- Wait again
        startTime = os.clock()
        while not welcomeReceived and (os.clock() - startTime) < 3 do
            task.wait(0.1)
            if negotiatedVersion > 0 then
                welcomeReceived = true
            end
        end
    end

    -- After welcome, sessionId is set from the welcome response (see handleWelcome).
    -- The server may have accepted or overridden our proposed ID.
    return welcomeReceived
end
```

### 5.3 Instance ID

The plugin generates a UUID on first run and persists it in plugin settings. This ID uniquely identifies this plugin installation across sessions and Studio restarts. It is not the session ID -- the plugin generates a proposed session ID on each connection via `HttpService:GenerateGUID()`, and the server confirms or overrides it in the `welcome` response.

```lua
local function getOrCreateInstanceId(plugin)
    local id = plugin:GetSetting("StudioBridge_InstanceId")
    if type(id) == "string" and #id > 0 then
        return id
    end
    id = HttpService:GenerateGUID(false)
    plugin:SetSetting("StudioBridge_InstanceId", id)
    return id
end
```

### 5.4 Session ID handling

Unlike the temporary plugin where SESSION_ID is baked in at build time, the persistent plugin generates its own proposed session ID (via `HttpService:GenerateGUID()`) and sends it in the `register` message. The server accepts this ID or overrides it (e.g., on collision). The `welcome` response contains the authoritative session ID, which the plugin must adopt. The plugin validates that every subsequent incoming message carries this authoritative session ID and drops messages that do not match.

### 5.5 Welcome processing

When the plugin receives a `welcome` message, it adopts the authoritative session ID from the response (which may differ from the proposed ID if the server overrode it), extracts the negotiated protocol version, and records the confirmed capabilities:

```lua
local function handleWelcome(msg)
    -- Adopt the authoritative session ID from the server's welcome response.
    -- This may be the same as the proposed ID, or the server may have overridden it.
    sessionId = msg.sessionId
    negotiatedVersion = msg.protocolVersion or 1

    if msg.payload and msg.payload.capabilities then
        confirmedCapabilities = msg.payload.capabilities
    else
        confirmedCapabilities = { "execute" }
    end

    transitionTo(STATE_CONNECTED)
    print("[StudioBridge] Connected (v" .. tostring(negotiatedVersion) .. ", session=" .. tostring(sessionId) .. ")")
end
```

### 5.6 Session ID lifecycle

The system uses two distinct identifiers with different lifetimes:

**`instanceId`** (persistent, per-installation):
- Generated once on first plugin run and stored in `plugin:SetSetting("StudioBridge_InstanceId")`.
- Survives Studio restarts, plugin updates, and reconnections.
- Shared across all 3 plugin contexts (edit, client, server) within the same Studio installation because `PluginSettings` are per-installation, not per-context.
- The bridge host uses `instanceId` to group contexts that belong to the same Studio installation.

**`sessionId`** (ephemeral, per-connection):
- Generated by the plugin (via `HttpService:GenerateGUID()`) and proposed in the `register` message. The bridge host accepts it or overrides it (on collision); the `welcome` response contains the authoritative value.
- Each context gets its own session ID. An edit context, a server context, and a client context from the same Studio installation will have 3 different session IDs.
- A new session ID is generated on every connection. If the plugin disconnects and reconnects (e.g., because the bridge host restarted), it generates a fresh UUID for the new connection.
- Session IDs are UUIDs used for routing commands to the correct plugin WebSocket.

The relationship between these identifiers:

```
instanceId "abc-123" (stored in PluginSettings, survives restarts)
  ├── sessionId "s1" (edit context, plugin-generated on connect, confirmed by server, lost on disconnect)
  ├── sessionId "s2" (server context, plugin-generated on connect, confirmed by server, lost on disconnect)
  └── sessionId "s3" (client context, plugin-generated on connect, confirmed by server, lost on disconnect)
```

When the bridge host receives a `register` message, it accepts or overrides the plugin's proposed `sessionId`, creates a new session entry keyed by that session ID, and records the `instanceId` and `context` as metadata. CLI clients can use this metadata to target specific contexts (e.g., "execute on the server context of Studio installation X").

## 6. Reconnection Strategy

### 6.1 Triggers

Reconnection is triggered by:
- WebSocket `Closed` event (server stopped, network interruption)
- WebSocket `Error` event (protocol error, abnormal close)
- Missing heartbeat acknowledgment is not a trigger (the plugin sends heartbeats, not the server)

Reconnection is NOT triggered by:
- Receiving a `shutdown` message -- the plugin disconnects cleanly and returns to `searching` with no backoff

### 6.2 Exponential backoff

```lua
local BACKOFF_INITIAL = 1
local BACKOFF_MULTIPLIER = 2
local BACKOFF_MAX = 30

local function enterReconnecting(wasShutdown)
    if wasShutdown then
        -- Clean disconnect, go straight to searching
        backoffSeconds = 0
        transitionTo(STATE_SEARCHING)
        return
    end

    -- Increase backoff
    if backoffSeconds == 0 then
        backoffSeconds = BACKOFF_INITIAL
    else
        backoffSeconds = math.min(backoffSeconds * BACKOFF_MULTIPLIER, BACKOFF_MAX)
    end

    transitionTo(STATE_RECONNECTING)
end

local function resetBackoff()
    backoffSeconds = 0
end
```

The backoff sequence is: 1s, 2s, 4s, 8s, 16s, 30s, 30s, 30s, ...

`resetBackoff()` is called on every successful connection (when `welcome` is received).

### 6.3 Behavior during reconnection

**Heartbeat coroutine note**: The heartbeat loop runs as a `task.spawn` coroutine. When the WebSocket disconnects, the loop must exit cleanly. Use a `connected` boolean flag that the disconnect handler sets to `false`; the heartbeat coroutine checks it each iteration and returns when false. Do not use `task.cancel` on the heartbeat thread -- that can leave partially-sent WebSocket frames. The pattern is: `while connected do task.wait(15); if connected then send heartbeat end end`.

While in the `reconnecting` or `searching` state:
- No action messages are processed (there is no WebSocket connection).
- The heartbeat timer is stopped.
- The log buffer continues to accumulate entries from `LogService.MessageOut` so that logs generated during the gap are not lost.
- The state monitor continues tracking Studio state so that a `stateChange` push can be sent after reconnection if the state changed while disconnected.

### 6.4 Server restart scenario

When a user stops and restarts `studio-bridge`, the plugin detects the server restart during the reconnection discovery loop: the `/health` endpoint responds again. The plugin treats this as a new connection -- it generates a fresh UUID as its proposed session ID, sends a new `register`, receives a `welcome` with the authoritative session ID, resets its internal state, and begins a new session. The old session's log buffer is cleared.

## 7. Action Handlers

Action handlers are **shared between both boot modes**. Whether the plugin is running in ephemeral mode (direct connect) or persistent mode (discovery loop), the same dispatch table and handler modules process incoming messages. This is the primary benefit of the unified plugin architecture: all action logic is validated once and works identically in both modes.

Each v2 capability is implemented as a handler module. The `ActionHandler` dispatch table routes incoming messages by type:

```lua
-- ActionHandler.lua
local handlers = {
    execute = require(script.Parent.Actions.ExecuteAction),
    queryState = require(script.Parent.Actions.StateAction),
    captureScreenshot = require(script.Parent.Actions.ScreenshotAction),
    queryDataModel = require(script.Parent.Actions.DataModelAction),
    queryLogs = require(script.Parent.Actions.LogAction),
    subscribe = require(script.Parent.Actions.SubscribeHandler),
    unsubscribe = require(script.Parent.Actions.SubscribeHandler),
}

function ActionHandler.dispatch(client, msg, context)
    if msg.sessionId ~= context.sessionId then
        warn("[StudioBridge] Session mismatch, ignoring")
        return
    end

    local handler = handlers[msg.type]
    if handler then
        local ok, err = xpcall(function()
            handler.handle(client, msg, context)
        end, debug.traceback)

        if not ok then
            Protocol.sendError(client, context.sessionId, msg.requestId, "INTERNAL_ERROR", tostring(err))
        end
    elseif msg.type == "welcome" then
        -- Handled by connection lifecycle, not dispatch
    elseif msg.type == "shutdown" then
        -- Handled by connection lifecycle
    else
        -- Unknown message type: ignore per protocol spec
    end
end
```

### 7.1 ExecuteAction

Runs a Luau string via `loadstring` + `xpcall`. Correlates with `requestId` if present.

```lua
-- Actions/ExecuteAction.lua
local ExecuteAction = {}

function ExecuteAction.handle(client, msg, context)
    local source = msg.payload and msg.payload.script
    if type(source) ~= "string" then
        Protocol.sendError(client, context.sessionId, msg.requestId, "INVALID_PAYLOAD", "Missing script field")
        return
    end

    local fn, loadErr = loadstring(source)
    if not fn then
        Protocol.send(client, "scriptComplete", context.sessionId, {
            success = false,
            error = "loadstring failed: " .. tostring(loadErr),
        }, { requestId = msg.requestId })
        return
    end

    local ok, runErr = xpcall(fn, debug.traceback)

    -- Let final prints flush through LogService
    task.wait(0.2)
    context.flushOutput()

    Protocol.send(client, "scriptComplete", context.sessionId, {
        success = ok,
        error = if ok then nil else tostring(runErr),
    }, { requestId = msg.requestId })
end

return ExecuteAction
```

Execute requests are serialized: if a script is already running, the next `execute` is queued via `task.spawn` ordering. This matches the concurrency rule from `01-protocol.md` section 4.4.

### 7.2 StateAction

Reads the current Studio run mode and place metadata.

```lua
-- Actions/StateAction.lua
local RunService = game:GetService("RunService")

local StateAction = {}

function StateAction.handle(client, msg, context)
    Protocol.send(client, "stateResult", context.sessionId, {
        state = StateMonitor.getCurrentState(),
        placeId = game.PlaceId,
        placeName = game.Name,
        gameId = game.GameId,
    }, { requestId = msg.requestId })
end

return StateAction
```

### 7.3 ScreenshotAction

Captures the 3D viewport using `CaptureService` and extracts image bytes via `EditableImage`.

The confirmed API call chain:
1. `CaptureService:CaptureScreenshot(callback)` -- callback receives a `contentId` string
2. Load the `contentId` into an `EditableImage` (e.g., `AssetService:CreateEditableImageAsync(contentId)`)
3. Read the pixel/image bytes from the `EditableImage` (e.g., `editableImage:ReadPixels(...)`)
4. Base64-encode the bytes
5. Read dimensions from `editableImage.Size`
6. Send over WebSocket as a base64 string in the `screenshotResult` message

**Note for implementer**: The exact `EditableImage` constructor and pixel-read method names should be verified against the Roblox API at implementation time. The method may be `ReadPixels`, `GetPixels`, or similar, and the factory may be `AssetService:CreateEditableImageAsync` or a different constructor.

```lua
-- Actions/ScreenshotAction.lua
local AssetService = game:GetService("AssetService")
local CaptureService = game:GetService("CaptureService")

local ScreenshotAction = {}

-- Base64 encoding helper (a simple implementation; may use a shared utility)
local BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function base64Encode(data)
    -- Implementation: encode raw bytes to base64 string
    -- (full implementation omitted for brevity; use a standard base64 encoder)
    return data -- placeholder
end

function ScreenshotAction.handle(client, msg, context)
    -- Step 1: Capture the screenshot. CaptureScreenshot is callback-based.
    -- We use a BindableEvent or coroutine to bridge the callback into the
    -- synchronous action handler flow.
    local captureComplete = false
    local capturedContentId = nil
    local captureError = nil

    local captureOk, captureErr = pcall(function()
        CaptureService:CaptureScreenshot(function(contentId)
            capturedContentId = contentId
            captureComplete = true
        end)
    end)

    if not captureOk then
        Protocol.sendError(client, context.sessionId, msg.requestId,
            "SCREENSHOT_FAILED", "CaptureService error: " .. tostring(captureErr))
        return
    end

    -- Wait for the callback to fire (with a timeout)
    local startTime = os.clock()
    while not captureComplete and (os.clock() - startTime) < 10 do
        task.wait(0.1)
    end

    if not captureComplete then
        Protocol.sendError(client, context.sessionId, msg.requestId,
            "SCREENSHOT_FAILED", "CaptureService callback did not fire within 10 seconds")
        return
    end

    -- Step 2: Load the contentId into an EditableImage
    -- NOTE: Verify exact method name at implementation time.
    local imageOk, editableImage = pcall(function()
        return AssetService:CreateEditableImageAsync(capturedContentId)
    end)

    if not imageOk or not editableImage then
        Protocol.sendError(client, context.sessionId, msg.requestId,
            "SCREENSHOT_FAILED", "Could not create EditableImage: " .. tostring(editableImage))
        return
    end

    -- Step 3: Read pixel bytes from the EditableImage
    -- NOTE: Verify exact method name (ReadPixels, GetPixels, etc.) at implementation time.
    local imageSize = editableImage.Size
    local readOk, pixelData = pcall(function()
        return editableImage:ReadPixels(Vector2.new(0, 0), imageSize)
    end)

    if not readOk then
        Protocol.sendError(client, context.sessionId, msg.requestId,
            "SCREENSHOT_FAILED", "Could not read image data: " .. tostring(pixelData))
        return
    end

    -- Step 4: Base64-encode the pixel data
    local base64Data = base64Encode(pixelData)

    -- Steps 5-6: Read dimensions and send the result
    Protocol.send(client, "screenshotResult", context.sessionId, {
        data = base64Data,
        format = "png",
        width = imageSize.X,
        height = imageSize.Y,
    }, { requestId = msg.requestId })
end

return ScreenshotAction
```

The CaptureService API is confirmed to work in Studio plugins. The call chain is: `CaptureScreenshot` delivers a `contentId` string via callback, which is loaded into an `EditableImage` to extract pixel bytes, then base64-encoded for transmission. If any step fails at runtime (capture, EditableImage creation, or pixel read), the handler returns an error with code `SCREENSHOT_FAILED` and a descriptive message.

### 7.4 DataModelAction

Resolves an instance path, reads properties, and optionally traverses children.

```lua
-- Actions/DataModelAction.lua
local DataModelAction = {}

function DataModelAction.handle(client, msg, context)
    local payload = msg.payload

    -- Handle listServices
    if payload.listServices then
        local services = {}
        for _, child in ipairs(game:GetChildren()) do
            table.insert(services, ValueSerializer.serializeInstance(child, 0, {}, false))
        end
        Protocol.send(client, "dataModelResult", context.sessionId, {
            instance = {
                name = "Game",
                className = "DataModel",
                path = "game",
                properties = {},
                attributes = {},
                childCount = #services,
                children = services,
            },
        }, { requestId = msg.requestId })
        return
    end

    -- Resolve path
    local instance, resolvedPath, failedSegment = DataModelAction._resolvePath(payload.path)
    if not instance then
        Protocol.sendError(client, context.sessionId, msg.requestId, "INSTANCE_NOT_FOUND",
            "No instance found at path: " .. tostring(payload.path), {
                resolvedTo = resolvedPath,
                failedSegment = failedSegment,
            })
        return
    end

    -- Handle find
    if payload.find then
        local target
        if payload.find.recursive then
            target = instance:FindFirstChild(payload.find.name, true)
        else
            target = instance:FindFirstChild(payload.find.name)
        end
        if not target then
            Protocol.sendError(client, context.sessionId, msg.requestId, "INSTANCE_NOT_FOUND",
                "Child not found: " .. payload.find.name)
            return
        end
        instance = target
    end

    local depth = payload.depth or 0
    local properties = payload.properties or { "Name", "ClassName" }
    local includeAttributes = payload.includeAttributes or false

    local serialized = ValueSerializer.serializeInstance(instance, depth, properties, includeAttributes)
    Protocol.send(client, "dataModelResult", context.sessionId, {
        instance = serialized,
    }, { requestId = msg.requestId })
end

function DataModelAction._resolvePath(path)
    -- Path format: "game.Workspace.SpawnLocation"
    local segments = string.split(path, ".")
    if segments[1] ~= "game" then
        return nil, "", segments[1]
    end

    local current = game
    local resolvedPath = "game"

    for i = 2, #segments do
        local child = current:FindFirstChild(segments[i])
        if not child then
            return nil, resolvedPath, segments[i]
        end
        current = child
        resolvedPath = resolvedPath .. "." .. segments[i]
    end

    return current, resolvedPath, nil
end

return DataModelAction
```

### 7.5 LogAction

Reads from the ring buffer maintained by `LogBuffer`.

```lua
-- Actions/LogAction.lua
local LogAction = {}

function LogAction.handle(client, msg, context)
    local payload = msg.payload
    local count = payload.count or 50
    local direction = payload.direction or "tail"
    local levels = payload.levels -- nil means all
    local includeInternal = payload.includeInternal or false

    local entries = context.logBuffer:query(count, direction, levels, includeInternal)

    Protocol.send(client, "logsResult", context.sessionId, {
        entries = entries,
        total = context.logBuffer:size(),
        bufferCapacity = context.logBuffer.capacity,
    }, { requestId = msg.requestId })
end

return LogAction
```

### 7.6 StateMonitor

Detects state transitions for this plugin context and pushes `stateChange` messages when subscribed.

Each plugin instance has its own `StateMonitor` that reports the state of its own context, not the state of the whole Studio. Because each context runs in a separate Luau environment with its own `RunService`, `getCurrentState()` naturally returns the correct state for that context:

- **Edit context**: Always reports `"Edit"`. The edit DataModel is never in a running state.
- **Server context**: Reports `"Run"` when the Play-mode server is active, or `"Paused"` if paused.
- **Client context**: Reports `"Play"` when the Play-mode client is active, or `"Paused"` if paused.

```lua
-- StateMonitor.lua
local RunService = game:GetService("RunService")

local StateMonitor = {}
StateMonitor._currentState = "Edit"
StateMonitor._onStateChanged = nil -- callback

-- Reports the state of THIS context's DataModel, not the whole Studio.
-- Each plugin instance (edit, client, server) has its own StateMonitor.
function StateMonitor.getCurrentState()
    if not RunService:IsRunning() then
        return "Edit"
    end

    -- We are in a running context (server or client).
    -- Detect pause state. Note: detecting Paused requires checking if
    -- the game is actively ticking, which may need refinement.
    if RunService:IsServer() then
        return "Run" -- or "Paused" if pause detection is available
    elseif RunService:IsClient() then
        return "Play" -- or "Paused" if pause detection is available
    else
        return "Edit"
    end
end

function StateMonitor.start(onStateChanged)
    StateMonitor._onStateChanged = onStateChanged
    StateMonitor._currentState = StateMonitor.getCurrentState()

    -- Poll periodically since there is no single event for all transitions
    task.spawn(function()
        while true do
            task.wait(0.5)
            local newState = StateMonitor.getCurrentState()
            if newState ~= StateMonitor._currentState then
                local prev = StateMonitor._currentState
                StateMonitor._currentState = newState
                if StateMonitor._onStateChanged then
                    StateMonitor._onStateChanged(prev, newState)
                end
            end
        end
    end)
end

return StateMonitor
```

The `onStateChanged` callback is wired by the main plugin script to send `stateChange` push messages via WebSocket push when the server has an active `stateChange` subscription. The bridge host forwards these push messages to all subscribed clients (see `07-bridge-network.md` section 5.3 for the subscription routing mechanism). Since each context has its own `StateMonitor`, state changes are reported per-context: the bridge host receives separate `stateChange` notifications for the edit, server, and client sessions.

Similarly, when a `logPush` subscription is active, the plugin pushes individual `logPush` messages for each new `LogService.MessageOut` entry as it occurs. Each `logPush` message contains a single `{ level, body, timestamp }` entry. The bridge host forwards these to subscribed clients. The `SubscribeHandler` module (section 8) manages the active subscription set and gates whether push messages are sent over the WebSocket.

## 8. Plugin Luau Module Structure

The unified plugin lives in the existing template directory. There is no separate `studio-bridge-plugin` directory.

```
templates/studio-bridge-plugin/                    (unified -- same directory as before, upgraded in-place)
  default.project.json
  src/
    StudioBridgePlugin.server.lua                  -- entry point, boot mode detection, state machine
    Discovery.lua                                   -- HTTP health polling, port scanning (persistent mode only)
    Protocol.lua                                    -- JSON encode/decode, send helpers
    ActionHandler.lua                               -- dispatch table, routes messages to handlers
    Actions/
      ExecuteAction.lua                             -- loadstring + xpcall, requestId correlation
      StateAction.lua                               -- RunService state query
      ScreenshotAction.lua                          -- CaptureService viewport capture
      DataModelAction.lua                           -- path resolution, property reading, depth traversal
      LogAction.lua                                 -- ring buffer query
      SubscribeHandler.lua                          -- subscribe/unsubscribe management
    LogBuffer.lua                                   -- ring buffer implementation (1000 entries)
    StateMonitor.lua                                -- RunService state change detection
    ValueSerializer.lua                             -- Roblox type to JSON serialization
```

### 8.1 Entry point structure

`StudioBridgePlugin.server.lua` is the top-level script. Each plugin instance (edit, client, server) runs the same entry point code independently. No special Play mode handling is needed -- the edit instance is already running and connected; when Studio enters Play mode and creates new server and client plugin instances, each new instance boots, detects its context, discovers the bridge host, and connects on its own.

The entry point:

1. Guards against non-Studio contexts.
2. Detects the boot mode by checking whether build-time constants are present.
3. Detects the plugin context (edit, client, or server) via `detectContext()`.
4. Requires all modules.
5. Initializes the log buffer and state monitor.
6. Hooks `LogService.MessageOut` to feed the log buffer (this runs continuously, independent of connection state).
7. Branches based on boot mode: ephemeral (direct connect) or persistent (discovery state machine).

```lua
-- StudioBridgePlugin.server.lua
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

if not RunService:IsStudio() then
    return
end

local PLUGIN_VERSION = "1.0.0"

-- ---------------------------------------------------------------------------
-- Context detection
--
-- Each plugin instance detects whether it is running in the edit, server, or
-- client context. See section 4.4 for details.
-- ---------------------------------------------------------------------------

local function detectContext(): string
    if RunService:IsServer() and RunService:IsRunning() then
        return "server"
    elseif RunService:IsClient() and RunService:IsRunning() then
        return "client"
    else
        return "edit"
    end
end

local PLUGIN_CONTEXT = detectContext()

-- ---------------------------------------------------------------------------
-- Boot mode detection
--
-- These constants are injected via a two-step build pipeline:
-- 1. Handlebars template substitution (TemplateHelper) replaces {{IS_EPHEMERAL}},
--    {{PORT}}, and {{SESSION_ID}} placeholders in the Lua source.
-- 2. Rojo builds the substituted sources into the .rbxm plugin file.
--
-- Result after substitution:
--   Ephemeral build: IS_EPHEMERAL = true,  PORT = <number>, SESSION_ID = "<uuid>"
--   Persistent build: IS_EPHEMERAL = false, PORT = nil,      SESSION_ID = nil
-- No string comparison needed -- IS_EPHEMERAL is a plain boolean.
-- ---------------------------------------------------------------------------

local IS_EPHEMERAL = {{IS_EPHEMERAL}}  -- replaced at build time with `true` or `false`
local PORT = {{PORT}}                   -- replaced with number (ephemeral) or nil (persistent)
local SESSION_ID = "{{SESSION_ID}}"     -- replaced with UUID (ephemeral) or nil/empty (persistent)

-- In ephemeral mode, validate the session ID guard (same as the old temporary plugin)
if IS_EPHEMERAL then
    if RunService:IsRunning() then
        return
    end
    local thisPlaceSessionId = Workspace:GetAttribute("StudioBridgeSessionId")
    if thisPlaceSessionId ~= SESSION_ID then
        return
    end
end

local Discovery = require(script.Parent.Discovery)
local Protocol = require(script.Parent.Protocol)
local ActionHandler = require(script.Parent.ActionHandler)
local LogBuffer = require(script.Parent.LogBuffer)
local StateMonitor = require(script.Parent.StateMonitor)

-- Initialize log buffer (persists across connections for this context)
local logBuffer = LogBuffer.new(1000)

-- Map Roblox MessageType enum to string levels
local LEVEL_MAP = {
    [Enum.MessageType.MessageOutput] = "Print",
    [Enum.MessageType.MessageInfo] = "Info",
    [Enum.MessageType.MessageWarning] = "Warning",
    [Enum.MessageType.MessageError] = "Error",
}

-- Always capture logs, even when not connected
LogService.MessageOut:Connect(function(message, messageType)
    local isInternal = string.sub(message, 1, 14) == "[StudioBridge]"
    local level = LEVEL_MAP[messageType] or "Print"
    logBuffer:push({
        level = level,
        body = message,
        timestamp = os.clock() * 1000,
        isInternal = isInternal,
    })
end)

-- Start state monitor (monitors this context's state only)
StateMonitor.start(function(prevState, newState)
    -- Push stateChange if connected and subscribed (wired in main loop)
end)

-- ---------------------------------------------------------------------------
-- Branch by boot mode
-- ---------------------------------------------------------------------------

if IS_EPHEMERAL then
    -- Ephemeral mode: connect directly to the known server, no discovery.
    -- This path behaves identically to the old temporary plugin.
    print("[StudioBridge] Ephemeral mode (port=" .. tostring(PORT) .. ", session=" .. tostring(SESSION_ID) .. ")")
    task.spawn(function()
        connectDirectly(PORT, SESSION_ID)
    end)
else
    -- Persistent mode: enter discovery loop, poll for servers.
    -- Each context (edit, client, server) runs this independently.
    print("[StudioBridge] Persistent mode (" .. PLUGIN_CONTEXT .. " context), searching for server...")
    task.spawn(function()
        runStateMachine(plugin)
    end)
end
```

The `connectDirectly` function opens a WebSocket to `ws://localhost:{PORT}/{SESSION_ID}`, sends `hello`, and enters the `connected` state. It reuses the same `Protocol`, `ActionHandler`, and output batching logic as the persistent mode's `connected` state. The `runStateMachine` function implements the full persistent-mode state machine described in section 4.

In persistent mode, the entry point does not guard against `RunService:IsRunning()`. Unlike ephemeral mode (which exits early if the game is running, since the ephemeral plugin is only meant for the edit DataModel), each persistent-mode plugin instance is expected to connect regardless of context. The edit instance connects during edit; the server and client instances connect during Play mode. Each instance runs the same state machine independently.

### 8.2 Protocol module

`Protocol.lua` handles JSON encoding, decoding, and typed message sending:

```lua
-- Protocol.lua
local HttpService = game:GetService("HttpService")

local Protocol = {}

function Protocol.send(client, msgType, sessionId, payload, options)
    options = options or {}
    local message = {
        type = msgType,
        sessionId = sessionId,
        payload = payload,
    }

    if options.requestId then
        message.requestId = options.requestId
    end
    if options.protocolVersion then
        message.protocolVersion = options.protocolVersion
    end

    local ok, err = pcall(function()
        client:Send(HttpService:JSONEncode(message))
    end)
    if not ok then
        warn("[StudioBridge] Send failed: " .. tostring(err))
    end
end

function Protocol.sendError(client, sessionId, requestId, code, message, details)
    Protocol.send(client, "error", sessionId, {
        code = code,
        message = message,
        details = details,
    }, { requestId = requestId })
end

function Protocol.decode(rawData)
    local ok, msg = pcall(function()
        return HttpService:JSONDecode(rawData)
    end)
    if not ok or type(msg) ~= "table" or type(msg.type) ~= "string" then
        return nil
    end
    return msg
end

return Protocol
```

### 8.3 LogBuffer module

A fixed-capacity ring buffer that stores log entries. Entries are never removed except by overflow (oldest entries are dropped when the buffer is full).

```lua
-- LogBuffer.lua
local LogBuffer = {}
LogBuffer.__index = LogBuffer

function LogBuffer.new(capacity)
    return setmetatable({
        capacity = capacity,
        _buffer = table.create(capacity),
        _head = 1,    -- next write position
        _count = 0,   -- number of entries currently stored
    }, LogBuffer)
end

function LogBuffer:push(entry)
    self._buffer[self._head] = entry
    self._head = (self._head % self.capacity) + 1
    if self._count < self.capacity then
        self._count = self._count + 1
    end
end

function LogBuffer:size()
    return self._count
end

function LogBuffer:query(count, direction, levels, includeInternal)
    local all = self:_toArray()

    -- Filter
    local filtered = {}
    for _, entry in ipairs(all) do
        if not includeInternal and entry.isInternal then
            continue
        end
        if levels then
            local match = false
            for _, level in ipairs(levels) do
                if entry.level == level then
                    match = true
                    break
                end
            end
            if not match then
                continue
            end
        end
        table.insert(filtered, {
            level = entry.level,
            body = entry.body,
            timestamp = entry.timestamp,
        })
    end

    -- Apply direction and count
    if direction == "head" then
        local result = {}
        for i = 1, math.min(count, #filtered) do
            table.insert(result, filtered[i])
        end
        return result
    else -- tail
        local result = {}
        local start = math.max(1, #filtered - count + 1)
        for i = start, #filtered do
            table.insert(result, filtered[i])
        end
        return result
    end
end

function LogBuffer:_toArray()
    local result = {}
    if self._count < self.capacity then
        for i = 1, self._count do
            table.insert(result, self._buffer[i])
        end
    else
        -- Ring buffer is full; read from head (oldest) to end, then start to head-1
        for i = self._head, self.capacity do
            table.insert(result, self._buffer[i])
        end
        for i = 1, self._head - 1 do
            table.insert(result, self._buffer[i])
        end
    end
    return result
end

function LogBuffer:clear()
    self._buffer = table.create(self.capacity)
    self._head = 1
    self._count = 0
end

return LogBuffer
```

### 8.4 ValueSerializer module

Serializes Roblox types to the JSON-compatible `SerializedValue` format defined in `01-protocol.md`. Primitive types (string, number, boolean) are passed through as bare values. Complex Roblox types use a `type` discriminant field and a flat `value` array containing the numeric components.

```lua
-- ValueSerializer.lua
local ValueSerializer = {}

local SERIALIZERS = {
    ["string"] = function(v) return v end,
    ["number"] = function(v) return v end,
    ["boolean"] = function(v) return v end,
    ["nil"] = function() return nil end,
}

function ValueSerializer.serialize(value)
    local luaType = typeof(value)

    -- Primitives pass through as bare values
    local simple = SERIALIZERS[luaType]
    if simple then
        return simple(value)
    end

    -- Roblox types use { type = "...", value = [...] } format
    if luaType == "Vector3" then
        return { type = "Vector3", value = { value.X, value.Y, value.Z } }
    elseif luaType == "Vector2" then
        return { type = "Vector2", value = { value.X, value.Y } }
    elseif luaType == "CFrame" then
        -- GetComponents() returns: x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22
        return { type = "CFrame", value = { value:GetComponents() } }
    elseif luaType == "Color3" then
        return { type = "Color3", value = { value.R, value.G, value.B } }
    elseif luaType == "UDim2" then
        return { type = "UDim2", value = { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset } }
    elseif luaType == "UDim" then
        return { type = "UDim", value = { value.Scale, value.Offset } }
    elseif luaType == "BrickColor" then
        return { type = "BrickColor", name = value.Name, value = value.Number }
    elseif luaType == "EnumItem" then
        return {
            type = "EnumItem",
            enum = tostring(value.EnumType),
            name = value.Name,
            value = value.Value,
        }
    elseif luaType == "Instance" then
        return {
            type = "Instance",
            className = value.ClassName,
            path = ValueSerializer.getInstancePath(value),
        }
    else
        return {
            type = "Unsupported",
            typeName = luaType,
            toString = tostring(value),
        }
    end
end

function ValueSerializer.getInstancePath(instance)
    local parts = {}
    local current = instance
    while current and current ~= game do
        table.insert(parts, 1, current.Name)
        current = current.Parent
    end
    return "game." .. table.concat(parts, ".")
end

function ValueSerializer.serializeInstance(instance, depth, propertyNames, includeAttributes)
    local properties = {}
    for _, propName in ipairs(propertyNames) do
        local ok, value = pcall(function()
            return (instance :: any)[propName]
        end)
        if ok then
            properties[propName] = ValueSerializer.serialize(value)
        end
    end

    local attributes = {}
    if includeAttributes then
        for key, value in pairs(instance:GetAttributes()) do
            attributes[key] = ValueSerializer.serialize(value)
        end
    end

    local children = nil
    if depth > 0 then
        children = {}
        for _, child in ipairs(instance:GetChildren()) do
            table.insert(children, ValueSerializer.serializeInstance(child, depth - 1, propertyNames, includeAttributes))
        end
    end

    return {
        name = instance.Name,
        className = instance.ClassName,
        path = ValueSerializer.getInstancePath(instance),
        properties = properties,
        attributes = attributes,
        childCount = #instance:GetChildren(),
        children = children,
    }
end

return ValueSerializer
```

## 9. Backward Compatibility

### 9.1 Unified plugin replaces the old temporary plugin

The unified plugin source at `templates/studio-bridge-plugin/` replaces the old single-purpose temporary plugin. There is no separate persistent plugin directory. In ephemeral mode (build-time constants present), the unified plugin behaves identically to the old temporary plugin:

- It checks `Workspace:GetAttribute("StudioBridgeSessionId")` against the hardcoded `SESSION_ID`.
- It connects directly to `ws://localhost:{PORT}/{SESSION_ID}`.
- It sends `hello`, receives `welcome`, processes `execute` and `shutdown` messages.
- It is deleted on `stopAsync()`.

All action handlers, protocol logic, and serialization are shared between modes, so ephemeral mode gains v2 capabilities (state queries, screenshots, DataModel inspection, log retrieval) for free.

### 9.2 Server-side mode detection

`StudioBridgeServer.startAsync()` checks whether the persistent plugin is installed before deciding which connection strategy to use. This check delegates to the universal `PluginManager`:

```typescript
// Pseudocode for mode selection in studio-bridge-server.ts
async startAsync(): Promise<void> {
    const usePersistent = this.options.preferPersistentPlugin !== false
        && await this._pluginManager.isInstalledAsync('studio-bridge');

    if (usePersistent) {
        // Start WebSocket server, expose /health endpoint, wait for plugin discovery
        await this.startPersistentModeAsync();
    } else {
        // Build unified plugin WITH PORT/SESSION_ID substitution (ephemeral mode),
        // inject into plugins folder using PluginManager.buildAsync with overrides
        await this.startTemporaryModeAsync();
    }
}
```

`pluginManager.isInstalledAsync('studio-bridge')` checks for the existence of the version tracking sidecar at `~/.nevermore/studio-bridge/plugin/studio-bridge/version.json`. It does not inspect the Studio plugins folder directly (which may be in a platform-specific location that the server process cannot easily verify).

### 9.3 Coexistence behavior

Both a persistent-mode and an ephemeral-mode copy of the unified plugin can technically be present in the Studio plugins folder at the same time (e.g., the persistent copy installed globally, and an ephemeral copy injected for a specific session). They will never both connect to the same server because:

1. The ephemeral copy's `SESSION_ID` is hardcoded and validated via `Workspace:GetAttribute("StudioBridgeSessionId")`. It connects only to the server that injected it.
2. The persistent copy discovers servers via health endpoints, generates its own session ID, and connects to the `/plugin` WebSocket path.
3. The WebSocket server accepts only one plugin connection per session. The first plugin to complete the handshake wins; subsequent connection attempts are rejected.

In practice, when the persistent plugin is installed, the server skips ephemeral injection entirely, so there is no overlap.

## 10. Security Considerations

### 10.1 Localhost only

The plugin only makes HTTP and WebSocket connections to `localhost`. Roblox Studio's `HttpService` enforces this for plugin contexts -- `CreateWebStreamClient` and `RequestAsync` are restricted to loopback addresses. No configuration in the plugin can override this.

### 10.2 Session ID as token

The session ID (UUIDv4) in the WebSocket URL path (`ws://localhost:{port}/{sessionId}`) acts as an unguessable token. A process on the same machine would need to guess the UUID to connect. The server rejects WebSocket upgrade requests with an incorrect session ID at the HTTP level.

### 10.3 Welcome validation

After connecting and sending `register` with a plugin-generated session ID, the plugin adopts the `sessionId` from the server's `welcome` response as authoritative. The server may confirm the plugin's proposed ID or override it. In either case, the plugin uses the `welcome.sessionId` for all subsequent messages. The plugin validates that the `welcome` response is well-formed (has a non-empty `sessionId`, valid JSON structure). If the `welcome` is malformed, the plugin disconnects immediately.

### 10.4 Dormancy when no servers exist

If the plugin completes a full scan of candidate ports and finds no health endpoints, it continues polling at the 2-second interval. However, the HTTP requests are lightweight (GET with 500ms timeout) and the scan covers at most ~20 ports, so the CPU and network cost is negligible.

If the user uninstalls studio-bridge entirely (removing `~/.nevermore/studio-bridge/`), the plugin continues polling but never finds a server. This is acceptable because the polling is cheap and because uninstallation of the plugin itself (`studio-bridge uninstall-plugin`) is the proper way to stop the plugin entirely.

### 10.5 No arbitrary code in discovery

The plugin never executes code from the health endpoint response. It only reads structured JSON fields (`sessionId`, `port`, `protocolVersion`). The `sessionId` is used as a URL path component and a string comparison target, never as executable input.

### 10.6 Settings versioning

The plugin uses `plugin:SetSetting` to persist `StudioBridge_InstanceId` and `StudioBridge_KnownPorts`. If future versions add or rename settings keys, the plugin must not crash on stale values left by an older version. Each setting key should be read with a safe default: if the value is `nil` or the wrong type, fall back to the default and overwrite the stale value. A `StudioBridge_SettingsVersion` integer key (starting at 1) should be stored alongside the other settings. On load, if the stored version is less than the current version, the plugin runs a migration function that clears or transforms incompatible keys. This keeps the migration logic forward-only and avoids silent data corruption from schema drift.
