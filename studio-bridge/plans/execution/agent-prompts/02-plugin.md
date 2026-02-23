# Phase 2: Persistent Plugin -- Agent Prompts

**Phase reference**: [studio-bridge/plans/execution/phases/02-plugin.md](../phases/02-plugin.md)
**Validation**: [studio-bridge/plans/execution/validation/02-plugin.md](../validation/02-plugin.md)

Base path for all file references: `/workspaces/NevermoreEngine/tools/studio-bridge/`

## How to Use These Prompts

1. Copy the full prompt for a single task into a Claude Code sub-agent session.
2. The agent should read the "Read First" files, then implement the "Requirements" section.
3. The agent should run the acceptance criteria checks before reporting completion.
4. Do not give an agent a task whose dependencies have not been completed yet (see the dependency graph in [studio-bridge/plans/execution/phases/02-plugin.md](../phases/02-plugin.md)).

Key conventions that apply to every prompt:

- **TypeScript ESM** with `.js` extensions on all local imports (e.g., `import { Foo } from './foo.js';`)
- **`Async` suffix** on all async functions (e.g., `listSessionsAsync`, `resolveRequestAsync`)
- **Private `_` prefix** on all private fields and methods
- **vitest** for tests: `describe`/`it`/`expect`, test files named `*.test.ts` alongside source
- **No default exports** -- always use named exports
- **yargs `CommandModule` pattern** for CLI commands (class with `command`, `describe`, `builder`, `handler`)
- **`@quenty/` scoped packages** for workspace imports (e.g., `@quenty/cli-output-helpers`)
- **`OutputHelper`** from `@quenty/cli-output-helpers` for all user-facing output

---

## Task 2.3: Health Endpoint on WebSocket Server

**Prerequisites**: Task 1.3d5 (BridgeConnection barrel export) must be completed first.

**Context**: The persistent Roblox Studio plugin needs to discover running studio-bridge servers. Each server exposes a `GET /health` HTTP endpoint alongside its WebSocket endpoint. The plugin polls `localhost:{port}/health` to find active servers.

**Objective**: Add an HTTP server to `StudioBridgeServer` that responds to `GET /health` with session info JSON, while continuing to handle WebSocket upgrades.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/studio-bridge-server.ts` (the file you will modify)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/registry/types.ts` (SessionInfo shape)

**Files to Modify**:
- `src/server/studio-bridge-server.ts` -- replace bare `WebSocketServer` with `http.createServer` + `WebSocketServer({ noServer: true })`, add `/health` handler

**Requirements**:

1. Import `http` from Node.js: `import * as http from 'http';`

2. Replace the current `new WebSocketServer({ port: 0, path: ... })` with:
   - Create an `http.Server` that handles HTTP requests.
   - Create a `WebSocketServer` with `{ noServer: true }`.
   - On the HTTP server's `'upgrade'` event, check if the URL matches `/${sessionId}`, then call `wss.handleUpgrade`.
   - On the HTTP server's `'request'` event, handle `GET /health` and return 404 for everything else.

3. The `/health` endpoint returns:

```json
{
  "status": "ok",
  "sessionId": "<session-id>",
  "port": <port>,
  "protocolVersion": 2,
  "serverVersion": "<package version or '0.0.0'>"
}
```

Use `200 OK` with `Content-Type: application/json`.

4. Non-matching HTTP requests return `404 Not Found` with a plain text body.

5. WebSocket upgrade requests to wrong paths return 404 and destroy the socket.

6. Update `startWsServerAsync` (or the startup code) to listen the `http.Server` instead of the `WebSocketServer`.

7. Update `_cleanupResourcesAsync` to close both the HTTP server and the WebSocket server.

**Acceptance Criteria**:
- `GET http://localhost:{port}/health` returns 200 with the JSON body described above.
- WebSocket upgrades to `/{sessionId}` continue to work (existing handshake tests pass).
- Non-matching HTTP requests return 404.
- WebSocket upgrades to wrong paths are rejected.
- The health endpoint is available immediately after `startAsync` resolves.
- The HTTP server is closed during `_cleanupResourcesAsync`.

**Do NOT**:
- Add any npm dependencies (use Node.js built-in `http` module).
- Change the public API of `StudioBridgeServer`.
- Break the existing WebSocket handshake flow.
- Use default exports.
- Forget `.js` extensions on local imports.

---

## Task 2.4: Plugin Installer Command

**Prerequisites**: Task 2.1 (persistent plugin core) and Task 1.7b (barrel export pattern for commands) must be completed first.

**Context**: The persistent Studio plugin needs to be installed into Roblox Studio's plugins folder. This task implements `studio-bridge install-plugin` and `studio-bridge uninstall-plugin` CLI commands that build and manage the plugin file.

**Objective**: Implement CLI commands to install and uninstall the persistent plugin, plus a detection utility.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/cli.ts` (to see how commands are registered)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/commands/exec-command.ts` (pattern for yargs CommandModule)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/args/global-args.ts` (global args interface)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/plugin/plugin-injector.ts` (existing plugin build pattern with rojo, template helpers, findPluginsFolder)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/process/studio-process-manager.ts` (for `findPluginsFolder`)

**Files to Create**:
- `src/cli/commands/install-plugin-command.ts` -- `InstallPluginCommand` class
- `src/cli/commands/uninstall-plugin-command.ts` -- `UninstallPluginCommand` class
- `src/plugin/persistent-plugin-installer.ts` -- shared install/uninstall logic
- `src/plugin/plugin-discovery.ts` -- `isPersistentPluginInstalled(): boolean`

**Files to Modify**:
- `src/cli/cli.ts` -- register both commands

**Requirements**:

1. Implement `src/plugin/plugin-discovery.ts`:

```typescript
import * as fs from 'fs';
import * as path from 'path';
import { findPluginsFolder } from '../process/studio-process-manager.js';

const PERSISTENT_PLUGIN_FILENAME = 'StudioBridgePersistentPlugin.rbxm';

export function getPersistentPluginPath(): string {
  return path.join(findPluginsFolder(), PERSISTENT_PLUGIN_FILENAME);
}

export function isPersistentPluginInstalled(): boolean {
  return fs.existsSync(getPersistentPluginPath());
}
```

2. Implement `src/plugin/persistent-plugin-installer.ts`:
   - `async installPersistentPluginAsync(): Promise<string>` -- builds the persistent plugin template via rojo, copies the output `.rbxm` to the plugins folder as `StudioBridgePersistentPlugin.rbxm`. Returns the installed path.
   - `async uninstallPersistentPluginAsync(): Promise<void>` -- removes the plugin file. Throws if not installed.
   - Use `BuildContext`, `TemplateHelper`, and `resolveTemplatePath` from `@quenty/nevermore-template-helpers` (same pattern as `plugin-injector.ts`).
   - The template directory is `templates/studio-bridge-plugin/`. Note: this directory may not exist yet (Task 2.1 creates it). The installer code should be correct for when the template exists. If the template does not exist, the build will fail with a clear rojo error.

3. Implement `InstallPluginCommand` following the yargs CommandModule pattern:
   - Command: `install-plugin`
   - Description: `Install the persistent Studio Bridge plugin`
   - No additional arguments beyond global args.
   - Handler calls `installPersistentPluginAsync()`, prints the installed path on success.
   - On error, prints the error message and exits with code 1.

4. Implement `UninstallPluginCommand`:
   - Command: `uninstall-plugin`
   - Description: `Remove the persistent Studio Bridge plugin`
   - Handler calls `uninstallPersistentPluginAsync()`, prints confirmation on success.
   - If not installed, prints a message and exits cleanly.

5. Register both commands in `src/commands/index.ts` (NOT `cli.ts`):

```typescript
// In src/commands/index.ts, add:
export { installPluginCommand } from './install-plugin.js';
export { uninstallPluginCommand } from './uninstall-plugin.js';

// And add both to the allCommands array.
```

`cli.ts` already registers all commands via a loop over `allCommands` (established in Task 1.7b). Do NOT add per-command `.command()` calls to `cli.ts`.

**Acceptance Criteria**:
- `studio-bridge install-plugin` builds and writes `StudioBridgePersistentPlugin.rbxm` to the Studio plugins folder.
- Running it again overwrites the existing file.
- `studio-bridge uninstall-plugin` removes the file.
- `isPersistentPluginInstalled()` returns `true` when the file exists, `false` otherwise.
- `src/commands/index.ts` exports both commands and includes them in `allCommands`.
- Both commands print clear success/failure messages with the file path.
- Commands follow the same error handling pattern as `ExecCommand`.
- **PluginManager generality test**: The following concrete test must pass:

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

  The test fixture `fixtures/test-plugin-template/` must be created with a minimal `default.project.json` and a single `.lua` file sufficient for Rojo to produce a valid `.rbxm`. Example minimal structure:

  ```
  fixtures/test-plugin-template/
    default.project.json   # { "name": "TestPlugin", "tree": { "$path": "src" } }
    src/
      init.lua             # return {}
  ```

**Do NOT**:
- Modify `cli.ts` to register commands -- add them to `src/commands/index.ts` instead.
- Create the persistent plugin template directory (that is Task 2.1).
- Use default exports.
- Forget `.js` extensions on local imports.

---

## Handoff Notes for Tasks Requiring Orchestrator Coordination or Review

The following Phase 2 tasks benefit from orchestrator coordination, a review agent, or Studio validation. They can be implemented by a skilled agent but require additional verification. Brief handoff notes are provided instead of full prompts.

### Task 2.1: Persistent Plugin Core (Luau)

**Prerequisites**: Phase 0.5 (all plugin modules: 0.5.1-0.5.3) and Task 1.1 (protocol v2 types) must be completed first.

**Why requires review**: This is a complex Luau plugin with Studio-specific APIs (`HttpService:CreateWebStreamClient`, `RunService`, `LogService`). Code quality and structure can be reviewed by a review agent; however, runtime behavior (WebSocket connectivity, state machine transitions, reconnection) requires Studio validation (deferred to Phase 6 E2E). The Luau codebase uses a custom module loader, but Lune tests cover the Layer 1 modules.

**Handoff**: The plugin implements a state machine (idle -> searching -> connecting -> connected -> reconnecting) with HTTP discovery polling, WebSocket connection management, v2 handshake with capability advertisement, heartbeat sending, and exponential backoff reconnection. Reference the full spec in `studio-bridge/plans/tech-specs/03-persistent-plugin.md`. The plugin template goes in `templates/studio-bridge-plugin/`.

**Wiring sequence** (step-by-step guide for connecting Phase 0.5 Layer 1 modules to Roblox services):
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

After every change to files in `templates/studio-bridge-plugin/`, run `rojo build templates/studio-bridge-plugin/default.project.json -o dist/studio-bridge-plugin.rbxm` to verify the Rojo build still succeeds. This is your primary validation signal for Luau code structure. The output file `dist/studio-bridge-plugin.rbxm` must exist and be > 1KB.

**Lune test expectations**: Rojo build succeeds. Module structure matches `default.project.json` tree. All Luau modules required by the entry point are resolvable within the Rojo project.

---

## Task 2.2: Execute Action Handler in Plugin (Luau)

**Prerequisites**: Task 2.1 (persistent plugin core) must be completed first.

**Context**: The persistent plugin receives `execute` messages from the server containing Luau script code. This task implements the action handler that receives these messages, executes the code via `loadstring`, captures output, and sends back `scriptComplete` with the result. This is the Luau-side counterpart to the server's existing `executeAsync` method.

**Objective**: Create an execute action handler module that registers with the `ActionRouter` (from Phase 0.5), handles `requestId` correlation for v2 protocol, queues concurrent execute requests, and processes them sequentially.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/templates/studio-bridge-plugin/src/Shared/ActionRouter.luau` (from Phase 0.5 -- the router this handler registers with)
- `/workspaces/NevermoreEngine/tools/studio-bridge/templates/studio-bridge-plugin/src/Shared/Protocol.luau` (message encoding/decoding)
- `/workspaces/NevermoreEngine/tools/studio-bridge/templates/studio-bridge-plugin/src/StudioBridgePlugin.server.lua` (existing plugin entry point -- see how `execute` is handled in the temporary plugin for reference)
- `/workspaces/NevermoreEngine/studio-bridge/plans/tech-specs/04-action-specs.md` (execute action specification)

**Files to Create**:
- `templates/studio-bridge-plugin/src/Actions/ExecuteAction.luau` -- the execute action handler module
- `templates/studio-bridge-plugin/test/execute-handler.test.luau` -- Lune tests

**Requirements**:

1. Create the execute action handler module:

```luau
local ExecuteAction = {}

-- Register this handler with the ActionRouter
function ExecuteAction.register(router, sendMessage)
    router:register("execute", function(payload, requestId, sessionId)
        return ExecuteAction._handleExecute(payload, requestId, sessionId, sendMessage)
    end)
end
```

2. **requestId handling** (critical for v2 protocol):
   - The incoming `execute` message MAY have a `requestId` (v2) or may NOT (v1).
   - If `requestId` is present, it MUST be echoed in the `scriptComplete` response message AND in all `output` messages generated during execution.
   - If `requestId` is absent (v1 fallback), send `scriptComplete` and `output` without a `requestId` field.
   - The `requestId` is how the server correlates the response back to the original request in the `PendingRequestMap`.

3. **Error handling** -- handle these distinct failure modes:
   - **`loadstring` failure** (syntax error in the script): `loadstring(code)` returns `nil, errorMessage`. Send `scriptComplete` with `success: false`, `error: errorMessage`, error code `SCRIPT_LOAD_ERROR`. Do NOT call the function.
   - **Runtime error** (script executes but throws): Wrap the function call in `pcall`. If `pcall` returns `false`, send `scriptComplete` with `success: false`, `error: errorString`, error code `SCRIPT_RUNTIME_ERROR`.
   - **Timeout**: If the script runs longer than the timeout specified in the payload (default 120 seconds), terminate execution and send `scriptComplete` with `success: false`, `error: "Script execution timed out after Ns"`, error code `TIMEOUT`.
   - **Success**: `pcall` returns `true`. Send `scriptComplete` with `success: true`.

4. **Output capture**: During script execution, capture `print()` / `warn()` / `error()` output by hooking `LogService.MessageOut`. Each captured line is sent as an `output` message with the matching `requestId` (if present). Output messages are sent as they are captured (streaming), not batched.

5. **Sequential execution**: Queue concurrent execute requests and process them one at a time. Use a simple FIFO queue. While one script is executing, incoming execute requests are queued. When execution completes (success or error), dequeue and execute the next request.

6. **Response message format**:

```luau
-- Success:
{
    type = "scriptComplete",
    sessionId = sessionId,
    requestId = requestId, -- only if present in the original request
    payload = { success = true }
}

-- Failure:
{
    type = "scriptComplete",
    sessionId = sessionId,
    requestId = requestId, -- only if present in the original request
    payload = {
        success = false,
        error = errorMessage,
        code = "SCRIPT_LOAD_ERROR" | "SCRIPT_RUNTIME_ERROR" | "TIMEOUT"
    }
}
```

**Acceptance Criteria**:
- Script execution returns success result with `success: true` in the payload.
- `loadstring` failure returns `scriptComplete` with `success: false` and error code `SCRIPT_LOAD_ERROR`.
- Runtime error (pcall failure) returns `scriptComplete` with `success: false` and error code `SCRIPT_RUNTIME_ERROR`.
- Timeout returns `scriptComplete` with `success: false` and error code `TIMEOUT`.
- `requestId` is echoed in the `scriptComplete` response when present in the original `execute` message.
- `requestId` is omitted from the response when absent in the original `execute` message (v1 compatibility).
- Output messages are sent with the matching `requestId` during execution.
- Concurrent execute requests are queued and processed sequentially.
- After every change, run `rojo build templates/studio-bridge-plugin/default.project.json -o dist/studio-bridge-plugin.rbxm` to verify the build.
- `lune run test/execute-handler.test.luau` passes all tests.

**Lune Test Cases** (file: `test/execute-handler.test.luau`):
- Script execution returns success/error result.
- `requestId` is echoed in response when present.
- `requestId` is omitted when absent (v1 mode).
- `loadstring` failure returns `SCRIPT_LOAD_ERROR` code.
- Runtime error returns `SCRIPT_RUNTIME_ERROR` code.
- Timeout behavior returns `TIMEOUT` error code.
- Sequential queueing: second request waits for first to complete.

**Do NOT**:
- Use any Roblox APIs directly in the module (inject via callbacks for testability where possible).
- Use default exports.
- Forget to echo `requestId` in both `output` and `scriptComplete` messages.

---

## Task 2.5: Persistent Plugin Detection and Fallback

**Prerequisites**: Tasks 2.3 (health endpoint) and 2.4 (plugin installer + plugin-discovery.ts) must be completed first.

**Context**: When the studio-bridge server starts, it needs to decide whether to inject the temporary plugin (the v1 behavior) or wait for the persistent plugin to connect on its own. If the persistent plugin is installed, the server should skip injection and wait for the plugin to discover the server via the health endpoint. If the persistent plugin is NOT installed, the server falls back to temporary injection. There is a grace period to handle the case where the persistent plugin is installed but has not yet discovered the server.

**Objective**: Modify `StudioBridgeServer.startAsync()` to check `isPersistentPluginInstalled()` and either wait for the persistent plugin or fall back to temporary injection. Add a `preferPersistentPlugin` option.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/studio-bridge-server.ts` (the file you will modify)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/plugin/plugin-discovery.ts` (from Task 2.4 -- `isPersistentPluginInstalled()`)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/plugin/plugin-injector.ts` (existing temporary injection logic)

**Files to Modify**:
- `src/server/studio-bridge-server.ts` -- modify `startAsync` to check for persistent plugin

**Requirements**:

1. Add `preferPersistentPlugin?: boolean` to `StudioBridgeServerOptions`:

```typescript
export interface StudioBridgeServerOptions {
  // ... existing options ...
  preferPersistentPlugin?: boolean;  // Default: true
}
```

2. Modify `startAsync` to add persistent plugin detection:

```typescript
async startAsync(): Promise<void> {
  // ... existing setup (WebSocket server, health endpoint, etc.) ...

  const preferPersistent = this._options.preferPersistentPlugin ?? true;

  if (preferPersistent && isPersistentPluginInstalled()) {
    // Persistent plugin is installed. Skip injection and wait for the
    // plugin to discover us via the health endpoint.
    // Start a grace period timer: if the plugin does not connect within
    // the grace period, fall back to temporary injection.
    const graceMs = 3_000;  // 3 seconds
    const connected = await this._waitForPluginConnectionAsync(graceMs);
    if (!connected) {
      // Grace period expired. Plugin may not be running in Studio.
      // Fall back to temporary injection.
      await this._injectPluginAsync();
    }
  } else {
    // No persistent plugin or preference disabled (CI mode).
    // Use temporary injection (existing v1 behavior).
    await this._injectPluginAsync();
  }
}
```

3. Implement `_waitForPluginConnectionAsync(graceMs: number): Promise<boolean>`:
   - Start listening for plugin connections on the WebSocket server.
   - If a plugin connects (sends `hello` or `register`) within `graceMs`, return `true`.
   - If the grace period expires without a connection, return `false`.
   - This is a non-blocking wait with a timeout, not a blocking sleep.

4. The default grace period is **3 seconds**. This is long enough for a running Studio instance with the persistent plugin to discover the server (plugin polls every 2 seconds), but short enough that users do not perceive a significant delay when the plugin is not running.

5. When `preferPersistentPlugin` is set to `false`, the server always uses temporary injection, regardless of whether the persistent plugin is installed. This is the behavior for CI environments.

**Acceptance Criteria**:
- When persistent plugin is installed and running: server waits, plugin connects within 3 seconds, no temporary injection occurs.
- When persistent plugin is installed but NOT running: server waits 3 seconds, then falls back to temporary injection.
- When persistent plugin is NOT installed: server immediately uses temporary injection.
- When `preferPersistentPlugin: false`: server immediately uses temporary injection regardless of plugin installation.
- Grace period is exactly 3 seconds (not configurable externally, but clear in the code).
- Existing `startAsync` behavior is unchanged when `preferPersistentPlugin` is not set and the persistent plugin is not installed.
- `StudioBridgeServerOptions` type includes the new field.

**Test Cases**:
- Grace period expiry: mock `isPersistentPluginInstalled` to return `true`, do NOT connect a plugin, verify that temporary injection is called after 3 seconds.
- Plugin connects within grace period: mock `isPersistentPluginInstalled` to return `true`, connect a mock plugin after 1 second, verify no temporary injection.
- `preferPersistentPlugin: false`: mock `isPersistentPluginInstalled` to return `true`, verify temporary injection is called immediately.
- Plugin not installed: `isPersistentPluginInstalled` returns `false`, verify temporary injection is called immediately.

**Do NOT**:
- Change any existing public method signatures on `StudioBridgeServer`.
- Make the grace period configurable via the public API (keep it as an internal constant).
- Use default exports.
- Forget `.js` extensions on local imports.

### Task 2.6: Session Selection for Existing Commands

**Prerequisites**: Tasks 1.3d5 (BridgeConnection), 1.4 (StudioBridge wrapper), 1.7a (shared CLI utilities), and 1.7b (barrel export pattern) must be completed first.

**Why requires review**: Session resolution UX and handler pattern consistency benefit from review agent verification to ensure patterns match the reference command. The full CLI flow can be tested programmatically.

**Handoff**: Add `--session` / `-s` global option to `cli.ts` (global options only, not per-command registration). Use `resolveSessionAsync()` from `src/cli/resolve-session.ts` for session disambiguation (created in Task 1.7a). Follow the `sessions` command pattern established in `src/commands/sessions.ts` and `src/cli/commands/sessions-command.ts` (Task 1.7b) for the handler/wiring split. Create `src/commands/exec.ts`, `src/commands/run.ts`, and `src/commands/launch.ts` command handlers. Add all three to `src/commands/index.ts` barrel file and `allCommands` array. Do NOT add per-command `.command()` calls to `cli.ts` -- it already loops over `allCommands`. Update `terminal` commands to use `resolveSessionAsync()` and `formatOutput()` from `src/cli/format-output.ts`. Reference the session resolution table in `studio-bridge/plans/tech-specs/02-command-system.md` section 4.1.

---

## Cross-References

- Phase plan: [studio-bridge/plans/execution/phases/02-plugin.md](../phases/02-plugin.md)
- Validation: [studio-bridge/plans/execution/validation/02-plugin.md](../validation/02-plugin.md)
- Tech specs: `studio-bridge/plans/tech-specs/03-persistent-plugin.md`, `studio-bridge/plans/tech-specs/04-action-specs.md`
