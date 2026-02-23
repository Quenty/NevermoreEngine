# Phase 2: Persistent Plugin

Goal: Ship the permanent Luau plugin, the `install-plugin` CLI command, and the discovery mechanism so that a user who installs the plugin can connect to a running Studio without re-launching it.

References:
- Persistent plugin: `studio-bridge/plans/tech-specs/03-persistent-plugin.md`
- Action specs: `studio-bridge/plans/tech-specs/04-action-specs.md`

Base path for all file references: `/workspaces/NevermoreEngine/tools/studio-bridge/`

Cross-references:
- Agent prompts: `studio-bridge/plans/execution/agent-prompts/02-plugin.md`
- Validation: `studio-bridge/plans/execution/validation/02-plugin.md`
- Depends on Phase 0.5 (Layer 1 plugin modules) -- see `00.5-plugin-modules.md`
- Depends on Phase 1 core (especially Tasks 1.3, 1.6, 1.7a) -- see `01-bridge-network.md`

---

### Task 2.1: Unified plugin -- Layer 2 glue (upgrade existing template) -- REVIEW CHECKPOINT (requires Studio validation)

**Description**: Wire the Layer 1 pure Luau modules (built in Phase 0.5) to Roblox services via a thin glue layer (~100-150 LOC). Phase 0.5 already provides: `Protocol.luau` (message encoding/decoding), `DiscoveryStateMachine.luau` (connection lifecycle), `ActionRouter.luau` (action dispatch), and `MessageBuffer.luau` (log buffering). This task writes only the Roblox-specific entry point and service bindings.

Build constants are injected via a two-step pipeline: Handlebars template substitution (in TemplateHelper) replaces placeholders like `{{PORT}}`, `{{SESSION_ID}}`, and `{{IS_EPHEMERAL}}` in the Lua source, then Rojo builds the substituted sources into an `.rbxm` plugin file. The entry point detects whether build-time constants have been substituted: if yes, it connects directly (ephemeral mode); if no, it enters the discovery state machine (persistent mode).

**Files to create or modify**:
- Modify: `templates/studio-bridge-plugin/src/StudioBridgePlugin.server.lua` -- thin entry point (~100-150 LOC) that reads build constants, instantiates Layer 1 modules, and wires them to Roblox services (HttpService for HTTP polling, WebSocket for connections, RunService for state detection, LogService/CaptureService for action handlers). Boot mode detection: if build constants are substituted, connect directly (ephemeral); otherwise, call `DiscoveryStateMachine.start()` (persistent).
- Create: `templates/studio-bridge-plugin/src/Actions/` -- thin Roblox-specific action handler implementations that register with `ActionRouter`. Each handler calls Roblox APIs and returns response messages.
- Modify: `templates/studio-bridge-plugin/default.project.json` -- update Rojo project to include Layer 1 modules from `src/Shared/` and the new action handlers.

**Dependencies**: Phase 0.5 (Layer 1 modules), Task 1.1 (v2 message format).

**Complexity**: M

**Review agent verifies** (code quality and structure). **Requires Studio validation** for runtime behavior:
- [ ] Plugin enters `connected` state in Studio when bridge host is running (verify `[StudioBridge] Connected` appears in Studio output log)
- [ ] Plugin stays in `searching` state when no bridge host is running (no error spam in output log, only periodic `[StudioBridge] Searching...` messages)
- [ ] All Phase 0.5 modules are imported and wired (Protocol, DiscoveryStateMachine, ActionRouter, MessageBuffer all referenced in entry point with correct callback injection)
- [ ] Heartbeat loop runs independently from script execution (start a long `exec`, verify heartbeat messages continue arriving at the server every 15s)
- [ ] Edit plugin survives Play/Stop mode transitions (enter Play mode, stop Play mode, verify edit session remains connected and functional via `studio-bridge sessions`)

**Wiring sequence** (numbered steps for connecting Phase 0.5 Layer 1 modules to Roblox services):
1. Import `Protocol` module from `src/Shared/Protocol.luau` (Phase 0.5)
2. Import `DiscoveryStateMachine` from `src/Shared/DiscoveryStateMachine.luau` (Phase 0.5)
3. Import `ActionRouter` from `src/Shared/ActionRouter.luau` (Phase 0.5)
4. Import `MessageBuffer` from `src/Shared/MessageBuffer.luau` (Phase 0.5)
5. Read build constants (`{{PORT}}`, `{{SESSION_ID}}`, `{{IS_EPHEMERAL}}`). Detect ephemeral vs persistent mode using the following explicit check:

```lua
-- Build constants are Handlebars templates before substitution
local IS_EPHEMERAL = (PORT ~= "{{PORT}}")
if IS_EPHEMERAL then
    -- Connect directly using substituted build constants
else
    -- Enter discovery state machine (persistent mode)
end
```

If `IS_EPHEMERAL` is true (build constants were substituted by Handlebars), the plugin connects directly to the known port. If false (build constants are still literal template strings), the plugin enters the discovery state machine.

6. In plugin init, create `DiscoveryStateMachine` with injected callbacks:
   - `onHttpPoll = function(url) return HttpService:GetAsync(url) end`
   - `onWebSocketConnect = function(url) return HttpService:CreateWebStreamClient(url) end`
   - `onStateChange = function(old, new) -- log transition end`
7. On discovery success (or immediate connect in ephemeral mode), create WebSocket connection.
8. Wire `WebSocket.OnMessage` -> `Protocol.decode()` -> `ActionRouter:dispatch()` for incoming messages.
9. Wire `ActionRouter` responses through `Protocol.encode()` -> `WebSocket:Send()` for outgoing messages.
10. Start heartbeat coroutine: `task.spawn(function() while stateMachine:isConnected() do ... task.wait(15) end end)` using the pattern from `studio-bridge/plans/tech-specs/03-persistent-plugin.md` section 6.3. Do NOT use `task.cancel`.
11. Wire `LogService.MessageOut:Connect()` -> `MessageBuffer:push()` for log buffering.
12. Wire `RunService` state detection: check `RunService:IsRunMode()`, `RunService:IsStudio()`, `RunService:IsRunning()` to determine context (`edit`, `client`, `server`).
13. Send `register` message with all capabilities and session identity fields.

**Acceptance criteria**:
- Plugin loads in Studio without errors when no server is running (goes to idle/searching, does not spam warnings).
- Plugin discovers a running server via HTTP health check and connects via WebSocket.
- Plugin sends `register` message with all capabilities (`execute`, `queryState`, `captureScreenshot`, `queryDataModel`, `queryLogs`, `subscribe`, `heartbeat`) plus session identity fields: `instanceId`, `context` (`'edit'` | `'client'` | `'server'`), `placeId`, and `gameId`.
- Plugin detects its context at startup by checking the DataModel environment: `edit` for the Edit-mode plugin instance, `client` for the LocalPlayer-side instance in Play mode, `server` for the server-side instance in Play mode. In Play mode, Studio has 3 concurrent plugin instances: the edit instance (which was already running and connected) plus the 2 new server and client instances, each connecting as a separate session.
- Plugin falls back to `hello` if `register` gets no response within 3 seconds (compatible with v1 servers).
- Plugin sends heartbeat every 15 seconds. The heartbeat loop runs as a `task.spawn` coroutine that checks a `connected` flag each iteration and exits cleanly on disconnect (do not use `task.cancel` -- it can leave partial WebSocket frames). See `studio-bridge/plans/tech-specs/03-persistent-plugin.md` section 6.3.
- Plugin reconnects automatically when the WebSocket drops, with exponential backoff (1s, 2s, 4s, 8s, max 30s). (Reconnection logic is in Layer 1's `DiscoveryStateMachine`; this task wires the injected callbacks.)
- Plugin detects state transitions (Edit/Play/Run/Paused) via RunService and sends `stateChange` push messages if subscribed.
- Plugin handles `shutdown` message by disconnecting cleanly (in persistent mode: returns to searching; in ephemeral mode: exits).
- In ephemeral mode (build-time constants present), the plugin connects directly to the hardcoded port and session ID, behaving identically to the old temporary plugin.
- The entry point is ~100-150 LOC of Roblox glue; all protocol logic, state machine logic, action routing, and message buffering are in Layer 1 modules from Phase 0.5.
- **Rojo build validation**: `rojo build templates/studio-bridge-plugin/default.project.json -o dist/studio-bridge-plugin.rbxm` succeeds and output file `dist/studio-bridge-plugin.rbxm` exists and is > 1KB. Agents should run this build command after every change to plugin source files.
- **Lune test plan**: Rojo build succeeds. Module structure matches `default.project.json` tree. All Luau modules required by the entry point are resolvable within the Rojo project.

### Task 2.2: Execute action handler in plugin

**Description**: Implement the execute action in the persistent plugin. This is a refactored version of the existing temporary plugin's execute logic, but integrated with the action dispatch table and supporting `requestId` correlation.

**Files to modify**:
- `templates/studio-bridge-plugin/src/Actions/ExecuteAction.lua`

**Dependencies**: Task 2.1.

**Complexity**: S

**Acceptance criteria**:
- Handles `execute` messages with or without `requestId`.
- Sends `output` messages during execution (batched, same as current plugin).
- Sends `scriptComplete` with matching `requestId` when present.
- Queues concurrent `execute` requests and processes them sequentially.
- `loadstring` failures return `scriptComplete` with `success: false`.
- **Lune test plan**: Test file: `test/execute-handler.test.luau`. Required test cases: script execution returns success/error result, requestId echoed in response, timeout behavior returns error.

### Task 2.3: Health endpoint on bridge host

**Description**: The `/health` HTTP endpoint is served by the bridge host's WebSocket server on port 38741 (already created in Task 1.3 as part of `bridge-host.ts`). This task ensures the endpoint returns the correct JSON shape and is used by the persistent plugin for discovery.

**Files to modify**:
- `src/bridge/bridge-host.ts` -- ensure the HTTP handler for `GET /health` on port 38741 returns host status and all connected session metadata.

**Dependencies**: Task 1.3.

**Complexity**: S

**Acceptance criteria**:
- `GET http://localhost:38741/health` returns `200 OK` with JSON body: `{ status, port, protocolVersion, serverVersion, sessions: SessionInfo[] }`.
- The `sessions` array lists all currently connected plugins with their metadata.
- Non-matching HTTP requests (not `/health`, `/plugin`, or `/client`) return `404`.
- The health endpoint is available immediately after `BridgeConnection.connectAsync()` resolves (when the process is the host).

### Task 2.4: Universal plugin management module + installer commands

**Description**: Build the universal `PluginManager` subsystem in `src/plugins/` and implement `studio-bridge install-plugin` / `studio-bridge uninstall-plugin` as commands that delegate to it. The plugin manager is a general-purpose utility -- not specific to studio-bridge. It operates on `PluginTemplate` descriptors and never hard-codes paths, filenames, or build constants for any specific plugin. studio-bridge registers its own template; future tools register theirs. See `03-persistent-plugin.md` section 2 for the full API design.

**Files to create**:
- `src/plugins/plugin-manager.ts` -- `PluginManager` class: `registerTemplate()`, `buildAsync()`, `installAsync()`, `uninstallAsync()`, `isInstalledAsync()`, `listInstalledAsync()`, `discoverPluginsDirAsync()`.
- `src/plugins/plugin-template.ts` -- `PluginTemplate` interface definition and validation.
- `src/plugins/plugin-discovery.ts` -- `discoverPluginsDirAsync()` platform-specific Studio plugins folder detection (extracted from `findPluginsFolder()` in `studio-process-manager.ts`).
- `src/plugins/types.ts` -- `InstalledPlugin`, `BuiltPlugin`, `BuildOverrides` types.
- `src/plugins/index.ts` -- barrel export for the plugin management subsystem.
- `src/commands/install-plugin.ts` -- `install-plugin` command handler delegating to `PluginManager`.
- `src/commands/uninstall-plugin.ts` -- `uninstall-plugin` command handler delegating to `PluginManager`.

**Files to modify**:
- `src/commands/index.ts` -- add `installPluginCommand` and `uninstallPluginCommand` exports to the barrel file and `allCommands` array. Do NOT modify `cli.ts` -- it already loops over `allCommands` (established in Task 1.7b).
- `src/plugin/plugin-injector.ts` -- refactor to delegate to `PluginManager.isInstalledAsync()` and `PluginManager.buildAsync()` with overrides for ephemeral builds.

**Dependencies**: Task 2.1 (needs the template to exist), Task 1.7b (barrel pattern must be established).

**Complexity**: M

**Acceptance criteria**:
- **PluginManager API is generic enough that a second plugin template could be added without modifying the manager.** This is the key design constraint. The manager operates on `PluginTemplate` values and never references studio-bridge by name in its implementation.
- `PluginManager.registerTemplate(template)` accepts any valid `PluginTemplate` and stores it in the registry.
- `PluginManager.buildAsync(template)` builds any registered template via Rojo and returns a `BuiltPlugin` with the .rbxm path and hash.
- `PluginManager.buildAsync(template, { constants: { PORT: '49201', SESSION_ID: 'abc' } })` produces an ephemeral build with overridden constants.
- `PluginManager.installAsync(built)` copies the .rbxm to the Studio plugins folder and writes a per-plugin version tracking sidecar.
- `PluginManager.isInstalledAsync('studio-bridge')` returns `true` when the studio-bridge plugin sidecar exists.
- `PluginManager.uninstallAsync('studio-bridge')` removes the .rbxm and sidecar.
- `PluginManager.listInstalledAsync()` returns metadata for all installed plugins (across all registered templates).
- `PluginManager.discoverPluginsDirAsync()` correctly resolves the Studio plugins folder on macOS and Windows.
- `studio-bridge install-plugin` builds the persistent plugin and writes it to the Studio plugins folder via `PluginManager`.
- `src/commands/index.ts` exports `installPluginCommand` and `uninstallPluginCommand` and includes them in `allCommands`.
- Running `install-plugin` again updates the existing plugin (hash comparison, overwrite if changed).
- `studio-bridge uninstall-plugin` removes the plugin file via `PluginManager`.
- Both commands print clear success/failure messages with the file path.
- Unit tests verify PluginManager generality with a concrete second-template test:

```typescript
describe('PluginManager generality', () => {
  it('registers and builds a second template without code changes', async () => {
    const manager = new PluginManager();
    manager.registerTemplate(studioBridgeTemplate);
    manager.registerTemplate({
      name: 'test-plugin',
      templateDir: path.join(__dirname, 'fixtures/test-plugin-template'),
      buildConstants: { TEST_VALUE: 'hello' },
      outputFilename: 'test-plugin.rbxm',
      version: '1.0.0',
    });
    const built = await manager.buildAsync('test-plugin');
    expect(built.filePath).toContain('test-plugin.rbxm');
    const installed = await manager.installAsync('test-plugin');
    expect(installed.name).toBe('test-plugin');
    const list = await manager.listInstalledAsync();
    expect(list).toHaveLength(2);
  });
});
```

  The test fixture `fixtures/test-plugin-template/` must contain a minimal `default.project.json` and a single `.lua` file sufficient for Rojo to produce a valid `.rbxm`.

### Task 2.5: Persistent plugin detection and fallback

**Description**: The bridge host always accepts plugin connections on `/plugin`. When a persistent plugin is installed, it will discover the host via the `/health` endpoint and connect automatically. If no persistent plugin connects within a timeout window, fall back to temporary plugin injection + Studio launch for backward compatibility and CI environments. Plugin detection uses the universal `PluginManager.isInstalledAsync()` API; ephemeral fallback uses `PluginManager.buildAsync()` with constant overrides.

**Files to modify**:
- `src/bridge/bridge-connection.ts` -- after becoming host (or connecting as client), wait for a plugin to connect. If none connects within a configurable grace period and `pluginManager.isInstalledAsync('studio-bridge')` returns `false`, trigger the legacy temporary injection path.
- `src/plugin/plugin-injector.ts` -- refactored in Task 2.4 to use `PluginManager.buildAsync(template, { constants: { PORT, SESSION_ID } })` for ephemeral builds.

**Dependencies**: Tasks 2.3, 2.4.

**Complexity**: S

**Acceptance criteria**:
- When persistent plugin is installed (per `PluginManager.isInstalledAsync()`): the bridge host waits for the plugin to discover it and connect via `/plugin`. No temporary injection occurs.
- When persistent plugin is NOT installed: after a brief grace period (e.g., 3 seconds), falls back to temporary plugin injection + Studio launch (current behavior). The ephemeral build is produced via `PluginManager.buildAsync(template, { constants: { PORT: String(port), SESSION_ID: sessionId } })`.
- A `BridgeConnectionOptions` field `preferPersistentPlugin?: boolean` (default: `true`). Setting it to `false` forces temporary injection even if the persistent plugin is installed (useful for CI).
- Timeout behavior is unchanged: if no plugin connects within `timeoutMs`, the connection attempt rejects.

### Task 2.6: Refactor exec/run to handler pattern + session selection + launch command

**Description**: Refactor `exec` and `run` into the single-handler pattern and add session selection support. This task has three parts:

1. **Extract exec/run handlers**: Create `src/commands/exec.ts` and `src/commands/run.ts` as `CommandDefinition` handlers that extract the core logic from the existing `exec-command.ts` and `run-command.ts`. The existing yargs command files become thin wrappers that call `createCliCommand` on these handlers. Do NOT leave exec and run as separate implementations outside the handler pattern -- they must use the same `CommandDefinition` / `resolveSessionAsync` / adapter infrastructure as all other commands.

2. **Session selection via resolveSession**: All session resolution uses the shared `resolveSession` utility from Task 1.7a. The `--session` / `-s` global flag feeds into this utility. No per-command session resolution logic.

3. **Launch command**: Create `src/commands/launch.ts` as a `CommandDefinition` handler that explicitly launches a new Studio session.

**Files to create**:
- `src/commands/exec.ts` -- `CommandDefinition<ExecInput, CommandResult<ExecResult>>` handler. Extracts core execution logic from `exec-command.ts` / `script-executor.ts`.
- `src/commands/run.ts` -- `CommandDefinition<RunInput, CommandResult<ExecResult>>` handler. Reads file, delegates to exec handler logic.
- `src/commands/launch.ts` -- `CommandDefinition<LaunchInput, CommandResult<LaunchResult>>` handler.

**Files to modify**:
- `src/cli/args/global-args.ts` -- add `session?: string` and `context?: SessionContext` to `StudioBridgeGlobalArgs`.
- `src/commands/index.ts` -- add `execCommand`, `runCommand`, and `launchCommand` exports to the barrel file and `allCommands` array. Do NOT add per-command `.command()` calls to `cli.ts` -- it already loops over `allCommands` (established in Task 1.7b).
- `src/cli/cli.ts` -- add `--session` / `-s` and `--context` / `-c` global options only. Do NOT add per-command registrations; the `allCommands` loop handles that.
- `src/cli/commands/exec-command.ts` -- replace with thin wrapper calling `createCliCommand(execCommand)`, or delete if redundant.
- `src/cli/commands/run-command.ts` -- same.
- `src/cli/commands/terminal/terminal-mode.ts` -- support attaching to an existing session via `BridgeSession`; register exec handler with terminal adapter for the implicit REPL execution path.

**Dependencies**: Tasks 1.3, 1.4, 1.7a.

**Complexity**: M

**Acceptance criteria**:
- The exec handler is defined once in `src/commands/exec.ts` and registered with both the CLI and terminal adapters. The MCP tool (Phase 5) will also use this same handler.
- The run handler is defined once in `src/commands/run.ts` and registered with the CLI adapter. The terminal `.run` dot-command uses the same handler.
- Session resolution in exec, run, and terminal all delegates to `resolveSessionAsync` -- no per-command resolution logic.
- `studio-bridge exec --session abc-123 'print("hi")'` connects to the bridge, resolves session `abc-123` via `resolveSessionAsync`, and executes.
- `studio-bridge exec --context server 'print("hi")'` targets the server context of the resolved instance. When a Studio instance is in Play mode, `--context` selects which of the 3 contexts to execute against. Defaults to `server` for Play mode (most useful for gameplay testing) or `edit` for Edit mode.
- `studio-bridge exec 'print("hi")'` with exactly one active instance auto-selects it (and picks the default context).
- `studio-bridge exec 'print("hi")'` with zero sessions falls back to launching Studio (current behavior).
- `studio-bridge exec 'print("hi")'` with multiple instances and no `--session` flag prints the list and errors.
- `studio-bridge terminal --session abc-123` enters REPL attached to the existing session.
- When connecting to an existing session, the session's origin is `user` (not `managed`). When launching a new Studio, the session's origin is `managed`.
- When connected to a session the CLI did not launch, `disconnectAsync` does not kill Studio.
- `studio-bridge launch ./MyGame.rbxl` explicitly launches a new Studio session and prints the session info.

### Parallelization within Phase 2

```
Phase 0.5 (Layer 1 modules) --+
                               +--> 2.1 (Layer 2 glue) --> 2.2 (execute action) --> 2.5 (detection + fallback)
Phase 1: 1.1 (protocol v2) ---+                        --> 2.4 (plugin manager) --> 2.5
                                                                                      ^
2.3 (health endpoint) -- needs 1.3 ---------------------------------------------------+

2.6 (exec/run refactor + session selection) -- needs 1.3 + 1.4 + 1.7a
```

Task 2.1 depends on Phase 0.5 (Layer 1 modules) and Task 1.1 (v2 message format). Tasks 2.3 and 2.6 can start as soon as their Phase 1 dependencies are met. Task 2.6 depends on Task 1.7a (shared CLI utilities). Task 2.4 (PluginManager module) should start as soon as Task 2.1 is ready.

Note: The `sessions` command (previously Task 2.6) has been moved to Phase 1 as Task 1.7b, where it serves as the reference command pattern.

---

## Phase 2 Gate

All unit tests pass. Plugin template builds successfully via Rojo. PluginManager API works for both persistent and ephemeral builds. Detection/fallback logic selects the correct path. Exec/run commands use session resolution.

Note: Manual Studio verification is deferred to Phase 6 (integration). Phase 2 gate is automated tests only.

**Phase 2 gate reviewer checklist**:
- [ ] `rojo build templates/studio-bridge-plugin/default.project.json -o dist/studio-bridge-plugin.rbxm` succeeds and output is > 1KB
- [ ] `cd tools/studio-bridge && npm run test` passes with zero failures (all Phase 1 + Phase 2 tests)
- [ ] `studio-bridge install-plugin` writes the `.rbxm` to the correct platform-specific plugins folder (verify path in output)
- [ ] `studio-bridge exec 'print("hello")'` with one active session auto-selects it and returns output
- [ ] PluginManager generality test passes: second template registers, builds, and installs without PluginManager code changes

---

## Testing Strategy (Phase 2)

**Unit tests**:
- `PluginManager.registerTemplate()` stores templates and `getTemplate()` retrieves them by name.
- `PluginManager.buildAsync()` produces a .rbxm with the correct build constants for persistent mode.
- `PluginManager.buildAsync()` with `BuildOverrides` produces a .rbxm with overridden constants for ephemeral mode.
- `PluginManager.installAsync()` writes the .rbxm to the correct path and creates a version tracking sidecar.
- `PluginManager.isInstalledAsync()` detects plugin presence via sidecar file.
- `PluginManager.uninstallAsync()` removes both the .rbxm and the sidecar.
- `PluginManager.listInstalledAsync()` returns metadata for all installed plugins across all registered templates.
- **Generality test**: Register a second `PluginTemplate` using the `fixtures/test-plugin-template/` test fixture (minimal `default.project.json` + single `.lua` file). Verify that `buildAsync`, `installAsync`, `isInstalledAsync`, `listInstalledAsync`, and `uninstallAsync` all work correctly for both templates without any PluginManager code changes. See the concrete test specification in Task 2.4 acceptance criteria.
- `install-plugin` command delegates to `PluginManager` and writes to correct path.
- Health endpoint returns correct JSON with connected sessions.
- Session selection logic via `resolveSession` (auto-select single session, error for multiple, error for none).

Note: Manual Studio testing (plugin loads, discovers server, reconnects) is deferred to Phase 6.

---

## Failure Modes

Default policy: **escalate integration issues to review agent, self-fix isolated issues.**

| Task | Likely Failure | Recovery Action |
|------|---------------|-----------------|
| 2.1 (plugin glue) | Layer 1 module API does not match expected callback signatures in Layer 2 glue | Escalate: this is a cross-phase interface issue between Phase 0.5 and Phase 2. Review Layer 1 API with Phase 0.5 task owner before adapting. |
| 2.1 (plugin glue) | `HttpService:CreateWebStreamClient` is unavailable or behaves differently than expected in current Studio build | Self-fix: wrap in `pcall`, log error, fall back to retry. Document the Studio build version requirement. |
| 2.1 (plugin glue) | Rojo build fails due to incorrect `default.project.json` tree structure | Self-fix: run `rojo build` after every change. Fix the project file to match the actual directory structure. |
| 2.1 (plugin glue) | Context detection (`edit`/`client`/`server`) is wrong in Play mode | Escalate: context detection logic requires real Studio testing. Document the detection algorithm and verify manually. |
| 2.2 (execute action) | `loadstring` is disabled in the plugin security context | Escalate: this is a platform constraint. If `loadstring` is unavailable, the entire execute capability is blocked. Investigate alternative approaches (e.g., `require` with dynamic modules). |
| 2.2 (execute action) | Concurrent execute requests cause state corruption | Self-fix: ensure the sequential queue implementation is correct. Add a test that sends 3 concurrent executes and verifies they complete in order. |
| 2.3 (health endpoint) | HTTP handler conflicts with WebSocket upgrade handler on the same port | Self-fix: ensure the `noServer: true` WebSocket pattern is implemented correctly. The HTTP server handles requests, the upgrade event routes to WebSocket. |
| 2.4 (plugin manager) | `findPluginsFolder()` returns wrong path on a platform | Self-fix if the path logic is a simple bug. Escalate if the platform is unsupported (e.g., Linux/Wine). |
| 2.4 (plugin manager) | Rojo is not installed or not found in PATH | Self-fix: check for rojo before build and provide a clear error message with installation instructions. |
| 2.5 (detection + fallback) | Race condition between persistent plugin connection and fallback timeout | Escalate: timing-sensitive integration between plugin discovery and fallback. Requires manual testing with real Studio to verify the grace period is sufficient. |
| 2.6 (exec/run refactor) | Refactored exec/run breaks existing `studio-bridge exec` behavior | Self-fix: existing tests catch regressions. Ensure all existing exec-command tests pass after refactoring. |
| 2.6 (exec/run refactor) | Session resolution in exec does not work with the `resolveSessionAsync` utility | Self-fix: verify that `resolveSessionAsync` returns a `BridgeSession` that has `execAsync`. If the types do not match, adapt the exec handler's session usage. |
