# Phase 3: New Actions

Goal: Implement the four new plugin capabilities (state, screenshot, logs, DataModel query) end-to-end -- from plugin Luau handler to server dispatch to CLI command.

References:
- Command system: `studio-bridge/plans/tech-specs/02-command-system.md`
- Action specs: `studio-bridge/plans/tech-specs/04-action-specs.md`

Base path for all file references: `/workspaces/NevermoreEngine/tools/studio-bridge/`

Cross-references:
- Agent prompts: `studio-bridge/plans/execution/agent-prompts/03-commands.md`
- Validation: `studio-bridge/plans/execution/validation/03-commands.md`
- Depends on Tasks 1.6, 1.7, 2.1 -- see `01-bridge-network.md` and `02-plugin.md`

---

### Task 3.1: State query action

**Plugin side**:
- Create: `templates/studio-bridge-plugin/src/Actions/StateAction.lua` -- reads `RunService` state, place info from `DataModel`, returns `stateResult`.

**Server side**:
- Create: `src/server/actions/query-state.ts` -- typed wrapper around `performActionAsync` for `queryState`.

**Command handler** (single-handler pattern):
- Create: `src/commands/state.ts` -- ONE `CommandDefinition<StateInput, CommandResult<StateOutput>>` handler. Calls `session.queryStateAsync()`, formats result. The CLI command is generated from this handler via `createCliCommand(stateCommand)`. The terminal `.state` dot-command is registered from the same handler via the terminal adapter. The MCP `studio_state` tool (Phase 5) will also use this same handler. Do NOT create a separate `src/cli/commands/state-command.ts`.
- Modify: `src/commands/index.ts` -- add `stateCommand` export and add it to the `allCommands` array. Do NOT modify `cli.ts` -- it already loops over `allCommands` (established in Task 1.7b).

**Dependencies**: Tasks 1.6, 1.7, 2.1.

**Complexity**: S

**Acceptance criteria**:
- The handler is defined once in `src/commands/state.ts` and registered with both the CLI and terminal adapters.
- `src/commands/index.ts` exports `stateCommand` and includes it in `allCommands`.
- `studio-bridge state` prints: Place, PlaceId, GameId, Mode, Context.
- `--context <edit|client|server>` targets a specific context within a Studio instance. When a Studio instance is in Play mode and `--session` resolves to an instance with multiple contexts, `--context` selects which one to query. Defaults to `edit` if not specified and multiple contexts exist.
- `--json` outputs structured JSON (handled by the CLI adapter's standard `--json` support).
- `--watch` subscribes to `stateChange` events via the WebSocket push subscription protocol (`subscribe { events: ['stateChange'] }`) and prints updates as `stateChange` push messages arrive from the plugin through the bridge host. On Ctrl+C, sends `unsubscribe { events: ['stateChange'] }`. See `01-protocol.md` section 5.2 and `07-bridge-network.md` section 5.3.
- Timeout after 5 seconds with clear error.
- **Lune test plan**: Test file: `test/state-action.test.luau`. Required test cases: StudioState values are correct strings (e.g. `"Edit"`, `"Play"`, `"Run"`, `"Paused"`), `--watch` sends subscribe message with `stateChange` event, requestId is echoed in response.

### Task 3.2: Screenshot capture action

**Plugin side**:
- Create: `templates/studio-bridge-plugin/src/Actions/ScreenshotAction.lua` -- uses `CaptureService:CaptureScreenshot(callback)` (confirmed working in Studio plugins). The callback receives a `contentId` string, which is loaded into an `EditableImage` via `AssetService:CreateEditableImageAsync(contentId)`. Pixel bytes are read from the `EditableImage` (e.g., `ReadPixels`), then base64-encoded. Dimensions come from `editableImage.Size`. Returns `screenshotResult`. Note: implementer should verify exact `EditableImage` method names against the Roblox API at implementation time.

**Server side**:
- Create: `src/server/actions/capture-screenshot.ts` -- typed wrapper, writes base64 data to temp PNG file.

**Command handler** (single-handler pattern):
- Create: `src/commands/screenshot.ts` -- ONE `CommandDefinition<ScreenshotInput, CommandResult<ScreenshotOutput>>` handler. Calls `session.captureScreenshotAsync()`, handles `--output`/`--base64`/`--open` logic. The CLI command is generated from this handler via `createCliCommand(screenshotCommand)`. The terminal `.screenshot` dot-command is registered from the same handler via the terminal adapter. The MCP `studio_screenshot` tool (Phase 5) will also use this same handler. Do NOT create a separate `src/cli/commands/screenshot-command.ts`.
- Modify: `src/commands/index.ts` -- add `screenshotCommand` export and add it to the `allCommands` array. Do NOT modify `cli.ts` -- it already loops over `allCommands` (established in Task 1.7b).

**Dependencies**: Tasks 1.6, 1.7, 2.1.

**Complexity**: M

**Acceptance criteria**:
- The handler is defined once in `src/commands/screenshot.ts` and registered with both the CLI and terminal adapters.
- `studio-bridge screenshot` writes a PNG to a temp directory and prints the path.
- `--context <edit|client|server>` targets a specific context for the screenshot (e.g., `--context client` captures the client viewport during Play mode).
- `--output /path/to/file.png` writes to the specified path.
- `--base64` prints raw base64 to stdout.
- `--open` opens the file in the default viewer (using `open` on macOS, `xdg-open` on Linux).
- Timeout after 15 seconds with clear error.
- Error message if CaptureService call fails at runtime (e.g., Studio minimized, rendering error).
- **Lune test plan**: Test file: `test/screenshot-action.test.luau`. Required test cases: returns base64 data with dimensions, error on CaptureService failure returns protocol error message, requestId is echoed in response.

### Task 3.3: Log query action

**Plugin side**:
- Create: `templates/studio-bridge-plugin/src/Actions/LogAction.lua` -- maintains a ring buffer (capacity: 1000) of `{ level, body, timestamp }` entries. Responds to `queryLogs` by slicing the buffer per the `count`/`offset`/`levels` params. Supports continuous `logPush` push via the WebSocket push subscription protocol (when the server subscribes to `logPush` events, the plugin pushes individual `logPush` messages for each new LogService entry).
- Modify: `templates/studio-bridge-plugin/src/StudioBridgePlugin.server.lua` -- integrate the ring buffer with the LogService connection (entries go into both the buffer and the real-time batch).

**Server side**:
- Create: `src/server/actions/query-logs.ts` -- typed wrapper.

**Command handler** (single-handler pattern):
- Create: `src/commands/logs.ts` -- ONE `CommandDefinition<LogsInput, CommandResult<LogsOutput>>` handler. Calls `session.queryLogsAsync()`, handles `--tail`/`--head`/`--follow`/`--level`/`--all` logic. The CLI command is generated from this handler via `createCliCommand(logsCommand)`. The terminal `.logs` dot-command is registered from the same handler via the terminal adapter. The MCP `studio_logs` tool (Phase 5) will also use this same handler. Do NOT create a separate `src/cli/commands/logs-command.ts`.
- Modify: `src/commands/index.ts` -- add `logsCommand` export and add it to the `allCommands` array. Do NOT modify `cli.ts` -- it already loops over `allCommands` (established in Task 1.7b).

**Dependencies**: Tasks 1.6, 1.7, 2.1.

**Complexity**: M

**Acceptance criteria**:
- The handler is defined once in `src/commands/logs.ts` and registered with both the CLI and terminal adapters.
- `studio-bridge logs` prints the last 50 log lines (default `--tail 50`).
- `--context <edit|client|server>` targets a specific context's log buffer. Defaults to `edit` context (read-only command; see the context default table in `tech-specs/04-action-specs.md`). Use `--context server` to query server-side gameplay logs during Play mode.
- `--tail 100` prints the last 100.
- `--head 20` prints the first 20 since plugin connected.
- `--follow` streams new lines in real time via the WebSocket push subscription protocol (`subscribe { events: ['logPush'] }`). The plugin pushes individual `logPush` messages for each new LogService entry, and the bridge host forwards them to subscribed clients. On Ctrl+C, sends `unsubscribe { events: ['logPush'] }`. Note: `logPush` is distinct from `output` (which is batched and scoped to a single `execute` request). See `01-protocol.md` section 5.2 and `07-bridge-network.md` section 5.3.
- `--level Error,Warning` filters to only those levels.
- `--all` includes `[StudioBridge]` internal messages (filtered by default).
- `--json` outputs each line as `{ timestamp, level, body }` (handled by the CLI adapter's standard `--json` support).
- Ring buffer handles more than 1000 entries by evicting the oldest.
- **Lune test plan**: Test file: `test/log-action.test.luau`. Required test cases: returns entries array with correct shape, `--follow` sends subscribe message with `logPush` event, level filter works (filters entries by OutputLevel), ring buffer respects count limit and evicts oldest entries, requestId is echoed in response.

### Task 3.4: DataModel query action

**Plugin side**:
- Create: `templates/studio-bridge-plugin/src/Actions/DataModelAction.lua` -- resolves dot-separated path from `game` (split on `.`, walk `FindFirstChild` from `game`), reads properties/attributes, serializes Roblox types to the `SerializedValue` format, traverses children up to `depth`.
- Create: `templates/studio-bridge-plugin/src/ValueSerializer.lua` -- reusable Luau module for converting Roblox values (Vector3, CFrame, Color3, UDim2, UDim, etc.) to JSON-compatible tables with `type` discriminant and flat `value` arrays. Primitives (string, number, boolean) pass through as bare values. See `04-action-specs.md` section 6 for the full SerializedValue format.

**Server side**:
- Create: `src/server/actions/query-datamodel.ts` -- typed wrapper.

**Command handler** (single-handler pattern):
- Create: `src/commands/query.ts` -- ONE `CommandDefinition<QueryInput, CommandResult<QueryOutput>>` handler. Calls `session.queryDataModelAsync()`, handles expression-to-path translation and `--children`/`--descendants`/`--properties`/`--attributes`/`--depth` logic. The CLI command is generated from this handler via `createCliCommand(queryCommand)`. The terminal `.query` dot-command is registered from the same handler via the terminal adapter. The MCP `studio_query` tool (Phase 5) will also use this same handler. Do NOT create a separate `src/cli/commands/query-command.ts`.
- Modify: `src/commands/index.ts` -- add `queryCommand` export and add it to the `allCommands` array. Do NOT modify `cli.ts` -- it already loops over `allCommands` (established in Task 1.7b).

**Dependencies**: Tasks 1.6, 1.7, 2.1.

**Complexity**: L

**Acceptance criteria**:
- The handler is defined once in `src/commands/query.ts` and registered with both the CLI and terminal adapters.
- `studio-bridge query Workspace.SpawnLocation` returns JSON with name, className, path, properties, childCount.
- `--context <edit|client|server>` targets a specific context's DataModel. This is important because the server and client DataModels differ during Play mode (server has ServerStorage/ServerScriptService; client has LocalPlayer, PlayerGui).
- `studio-bridge query Workspace --children` lists immediate children with name and className.
- `studio-bridge query Workspace --descendants --depth 2` traverses 2 levels deep.
- `--properties Position,Anchored,Size` returns only those properties.
- `--attributes` includes all attributes.
- Properties with Roblox types (Vector3, CFrame, Color3, UDim2, UDim, etc.) serialize correctly with `type` discriminant and flat `value` arrays (e.g., `{ "type": "Vector3", "value": [1, 2, 3] }`).
- Path `game.Workspace.NonExistent` returns a clear error: "No instance found at path: game.Workspace.NonExistent".
- Timeout after 10 seconds.
- **Lune test plan**: Test file: `test/datamodel-action.test.luau`. Required test cases: dot-path resolution walks FindFirstChild correctly, SerializedValue format is correct for each type (Vector3 as `{ type, value: [x,y,z] }`, CFrame as flat 12-element array, Color3, UDim2, UDim, EnumItem, Instance ref, primitives as bare values), error cases return protocol error messages for invalid paths, requestId is echoed in response.

### Task 3.5: Wire terminal adapter registry into terminal-mode.ts

**Description**: Wire the terminal adapter registry (from Task 1.7) into the terminal REPL so that all command handlers registered via `createDotCommandHandler` are available as dot-commands. This task does NOT create new dot-command handlers -- those already exist from tasks 2.6, 2.7, 3.1-3.4 as `CommandDefinition`s in `src/commands/`. This task replaces the hard-coded dot-command dispatch in `terminal-editor.ts` with the adapter-based registry, adds the `connect` and `disconnect` commands, and updates `.help`.

**Files to create**:
- `src/commands/connect.ts` -- `CommandDefinition` handler for switching sessions within terminal mode.
- `src/commands/disconnect.ts` -- `CommandDefinition` handler for disconnecting without killing Studio.

**Files to modify**:
- `src/cli/commands/terminal/terminal-mode.ts` -- import all command definitions from `src/commands/index.ts`, create the dot-command dispatcher via `createDotCommandHandler([sessionsCommand, stateCommand, screenshotCommand, logsCommand, queryCommand, execCommand, runCommand, connectCommand, disconnectCommand])`, and wire it into the input handler.
- `src/cli/commands/terminal/terminal-editor.ts` -- replace the hard-coded if/else dot-command chain (lines 342-403) with the adapter registry. Keep `.help`, `.exit`, `.clear` as built-in commands. The `.help` output is auto-generated from the registered command definitions.

**Dependencies**: Tasks 1.7, 2.6, 2.7, 3.1, 3.2, 3.3, 3.4.

**Complexity**: S

**Wiring sequence** (numbered steps for connecting the terminal adapter registry to terminal-mode.ts):
1. Import all command definitions from `src/commands/index.ts` (the barrel file: `sessionsCommand`, `stateCommand`, `screenshotCommand`, `logsCommand`, `queryCommand`, `execCommand`, `runCommand`).
2. Create `connectCommand` in `src/commands/connect.ts` -- handler calls `connection.resolveSession(sessionId)` and stores the result as the active session in terminal state.
3. Create `disconnectCommand` in `src/commands/disconnect.ts` -- handler clears the active session reference without killing Studio (for persistent sessions).
4. Import `connectCommand` and `disconnectCommand` into `terminal-mode.ts`.
5. Build the dot-command dispatcher: `const dotCommands = createDotCommandHandler([sessionsCommand, stateCommand, screenshotCommand, logsCommand, queryCommand, execCommand, runCommand, connectCommand, disconnectCommand])`.
6. In `terminal-editor.ts`, replace the hard-coded if/else dot-command chain (lines 342-403) with: `if (input.startsWith('.')) { const result = await dotCommands.dispatch(input, connection, activeSession); if (result) { formatOutput(result, terminalOutputStream); } }`.
7. Keep `.help`, `.exit`, `.clear` as built-in commands handled before the adapter dispatch.
8. Auto-generate `.help` output from the registered command definitions: `dotCommands.listCommands().map(cmd => \`.${cmd.name}\` + '  ' + cmd.description)`.
9. Wire the implicit REPL execution path: when input does NOT start with `.`, delegate to the `execCommand` handler with the current `activeSession`.
10. Ensure all dot-command output goes through `formatOutput()` from `src/cli/format-output.ts` for consistent formatting.

**Concrete output specs for each dot-command**:

```
Input: .state
Expected output (connected, Edit mode):
  Mode:    Edit
  Place:   MyGame
  PlaceId: 12345
  GameId:  67890

Input: .sessions
Expected output (two sessions):
  ID         Context  Place           State  Connected
  abc-123    edit     MyGame (12345)  ready  2m ago
  def-456    server   MyGame (12345)  ready  1m ago

Input: .screenshot
Expected output:
  Screenshot saved to /tmp/studio-bridge/screenshot-2026-02-23-1430.png

Input: .logs
Expected output (default --tail 50):
  [14:30:01] [Print]   Hello from server
  [14:30:02] [Warning] Something suspicious
  [14:30:03] [Error]   Script error at line 5
  (50 entries, 342 total in buffer)

Input: .query Workspace.SpawnLocation
Expected output:
  Name:       SpawnLocation
  ClassName:  SpawnLocation
  Path:       game.Workspace.SpawnLocation
  Properties:
    Position:  { type: "Vector3", value: [0, 5, 0] }
    Anchored:  true
    Size:      { type: "Vector3", value: [4, 1.2, 4] }
  Children: 0

Input: .connect abc-123
Expected output:
  Connected to session abc-123 (edit, MyGame)

Input: .disconnect
Expected output:
  Disconnected from session abc-123

Input: .help
Expected output:
  .state        Query the current Studio state
  .sessions     List active sessions
  .screenshot   Capture a screenshot
  .logs         Retrieve output logs
  .query <path> Query the DataModel
  .connect <id> Switch to a different session
  .disconnect   Disconnect from current session
  .clear        Clear the terminal
  .exit         Exit terminal mode
```

**Acceptance criteria**:
- `.state` prints the current session state (dispatched to the handler from `src/commands/state.ts`).
- `.screenshot` captures and prints the file path (dispatched to handler from `src/commands/screenshot.ts`).
- `.logs` prints recent logs (dispatched to handler from `src/commands/logs.ts`).
- `.query <expr>` queries the DataModel (dispatched to handler from `src/commands/query.ts`).
- `.sessions` lists all sessions (dispatched to handler from `src/commands/sessions.ts`).
- `.connect <id>` switches to a different session.
- `.disconnect` disconnects without killing Studio (when connected to a persistent session).
- `.help` lists all commands including the new ones (auto-generated from definitions).
- No command handler logic exists in `terminal-mode.ts` or `terminal-editor.ts` -- all dispatch goes through the adapter.
- **E2e test spec**: Spawn the terminal as a subprocess, send stdin commands, assert stdout patterns. Test file: `src/test/e2e/terminal-dot-commands.test.ts`. Required test cases:

```typescript
describe('terminal dot-commands e2e', () => {
  // Setup: start a bridge host with a mock plugin connected,
  // then spawn `studio-bridge terminal --session <id>` as a subprocess.

  it('.state prints studio state', async () => {
    await sendStdin('.state\n');
    const output = await readStdoutUntil('Mode:');
    expect(output).toContain('Mode:');
    expect(output).toMatch(/Mode:\s+(Edit|Play|Run|Paused)/);
    expect(output).toContain('Place:');
    expect(output).toContain('PlaceId:');
  });

  it('.sessions prints session table', async () => {
    await sendStdin('.sessions\n');
    const output = await readStdoutUntil('session(s) connected');
    expect(output).toContain('ID');
    expect(output).toContain('Context');
    expect(output).toContain('Place');
  });

  it('.screenshot prints saved path', async () => {
    await sendStdin('.screenshot\n');
    const output = await readStdoutUntil('.png');
    expect(output).toMatch(/Screenshot saved to .+\.png/);
  });

  it('.logs prints log entries', async () => {
    await sendStdin('.logs\n');
    const output = await readStdoutUntil('total in buffer');
    expect(output).toMatch(/\[Print\]|\[Warning\]|\[Error\]/);
    expect(output).toContain('total in buffer');
  });

  it('.query prints DataModel node', async () => {
    await sendStdin('.query Workspace\n');
    const output = await readStdoutUntil('ClassName:');
    expect(output).toContain('Name:');
    expect(output).toContain('ClassName:');
    expect(output).toContain('Workspace');
  });

  it('.connect switches session', async () => {
    await sendStdin('.connect def-456\n');
    const output = await readStdoutUntil('Connected to');
    expect(output).toContain('Connected to session def-456');
  });

  it('.disconnect disconnects from session', async () => {
    await sendStdin('.disconnect\n');
    const output = await readStdoutUntil('Disconnected');
    expect(output).toContain('Disconnected');
  });

  it('.help lists all commands', async () => {
    await sendStdin('.help\n');
    const output = await readStdoutUntil('.exit');
    expect(output).toContain('.state');
    expect(output).toContain('.sessions');
    expect(output).toContain('.screenshot');
    expect(output).toContain('.logs');
    expect(output).toContain('.query');
    expect(output).toContain('.connect');
    expect(output).toContain('.disconnect');
  });

  it('unknown dot-command prints error', async () => {
    await sendStdin('.notacommand\n');
    const output = await readStdoutUntil('Unknown');
    expect(output).toContain('Unknown command');
  });
});
```

### Phase 3 Gate -- REVIEW CHECKPOINT

**Phase 3 gate reviewer checklist**:
- [ ] All four commands (`state`, `screenshot`, `logs`, `query`) are defined once in `src/commands/` and registered via `src/commands/index.ts` barrel -- no per-command `cli.ts` modifications exist
- [ ] `studio-bridge state --json` returns valid JSON with Place, PlaceId, GameId, Mode, Context fields (verify with mock plugin test)
- [ ] `studio-bridge logs --follow` subscribes to `logPush` events via WebSocket push protocol and streams output (verify subscribe/unsubscribe messages in mock plugin test)
- [ ] `studio-bridge query Workspace.NonExistent` returns a clear error message "No instance found at path: game.Workspace.NonExistent" (not a stack trace or unhandled rejection)
- [ ] `cd tools/studio-bridge && npm run test` passes with zero failures (all Phase 1 + 2 + 3 tests)

### Parallelization within Phase 3

Tasks 3.1, 3.2, 3.3, and 3.4 are independent of each other -- they each implement a self-contained action end-to-end (plugin handler + server action + command handler in `src/commands/`). All four can proceed in parallel. All four depend on Task 1.7 (command handler infrastructure) for the `CommandDefinition` types and adapters. Task 3.5 depends on all four being complete and is now a smaller wiring task.

```
1.7 (command handler infra) --> 3.1 (state) --------+
                            --> 3.2 (screenshot) ----+
                            --> 3.3 (logs) ----------+--> 3.5 (wire terminal adapter)
                            --> 3.4 (query) ---------+
```

---

## Testing Strategy (Phase 3)

**Per-action unit tests** (mock WebSocket plugin):
- State query returns valid `StudioState`.
- Screenshot action returns base64 data, CLI writes to file.
- Log query respects `count`, `direction`, `levels` params.
- DataModel query resolves paths correctly, serializes types.
- DataModel query returns `INSTANCE_NOT_FOUND` for invalid paths.

**Integration tests** (mock plugin client):
- Full lifecycle: connect, query state, execute script, query logs, capture screenshot, query DataModel, disconnect.
- Concurrent requests: send state query and log query simultaneously, verify both resolve.
- Subscription: subscribe to `stateChange`, trigger a state change, verify push message arrives.

---

## Failure Modes

Default policy: **escalate integration issues to review agent, self-fix isolated issues.**

| Task | Likely Failure | Recovery Action |
|------|---------------|-----------------|
| 3.1 (state query) | `RunService` state detection returns unexpected values in some Studio modes (e.g., team test) | Self-fix: add the unexpected state to the `StudioState` enum and handle it gracefully. |
| 3.1 (state query) | `--watch` subscription never receives `stateChange` events because the push protocol is not wired | Self-fix: if subscribe is not available yet, print "watch not yet supported" and exit cleanly. Wire when push protocol is ready. |
| 3.2 (screenshot) | `CaptureService:CaptureScreenshot` callback never fires (Studio is minimized or viewport is not rendering) | Self-fix: add a timeout (15s) and return `SCREENSHOT_FAILED` with a descriptive error. |
| 3.2 (screenshot) | `EditableImage` API has different method names than expected (Roblox API changes) | Escalate: check Roblox API documentation at implementation time. If the API has changed, update the action handler. |
| 3.2 (screenshot) | Base64-encoded image data is too large for a single WebSocket frame | Self-fix: verify WebSocket frame size limits (16MB configured). If exceeded, compress or chunk. |
| 3.3 (log query) | Ring buffer ordering is wrong after wrap-around | Self-fix: add unit tests for wrap-around scenarios (buffer full, push N more, verify oldest are evicted and order is correct). |
| 3.3 (log query) | `--follow` mode leaks memory because log entries accumulate without limit on the server side | Self-fix: `--follow` streams individual `logPush` messages to stdout and does not buffer them. Ensure no accumulation on the server. |
| 3.4 (DataModel query) | Instance names containing dots break path resolution (known limitation) | Self-fix: document the limitation. Do not attempt to fix with escaping in this phase. |
| 3.4 (DataModel query) | Some Roblox property types are not serializable (e.g., `RBXScriptSignal`, `RBXScriptConnection`) | Self-fix: return `{ type: "Unsupported", typeName: "...", toString: "..." }` for unserializable types. |
| 3.4 (DataModel query) | `FindFirstChild` traversal hits a locked/inaccessible instance (e.g., CoreGui) | Self-fix: wrap each `FindFirstChild` call in `pcall`. Return `INSTANCE_NOT_FOUND` with a note about access restrictions. |
| 3.5 (terminal adapter) | Hard-coded dot-command chain in `terminal-editor.ts` has been modified since the plan was written (line numbers shifted) | Self-fix: search for the if/else chain by content pattern rather than line number. Replace the entire block. |
| 3.5 (terminal adapter) | `createDotCommandHandler` type signature does not match the `CommandDefinition` array | Escalate: this is a cross-task interface issue with Task 1.7. Review the adapter type with the command handler infrastructure owner. |
