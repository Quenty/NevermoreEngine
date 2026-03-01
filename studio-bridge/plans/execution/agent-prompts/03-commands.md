# Phase 3: New Actions (Commands) -- Agent Prompts

**Phase reference**: [studio-bridge/plans/execution/phases/03-commands.md](../phases/03-commands.md)
**Validation**: [studio-bridge/plans/execution/validation/03-commands.md](../validation/03-commands.md)

Base path for all file references: `/workspaces/NevermoreEngine/tools/studio-bridge/`

## How to Use These Prompts

1. Copy the full prompt for a single task into a Claude Code sub-agent session.
2. The agent should read the "Read First" files, then implement the "Requirements" section.
3. The agent should run the acceptance criteria checks before reporting completion.
4. Do not give an agent a task whose dependencies have not been completed yet (see the dependency graph in [studio-bridge/plans/execution/phases/03-commands.md](../phases/03-commands.md)).

Key conventions that apply to every prompt:

- **TypeScript ESM** with `.js` extensions on all local imports (e.g., `import { Foo } from './foo.js';`)
- **`Async` suffix** on all async functions (e.g., `listSessionsAsync`, `resolveRequestAsync`)
- **Private `_` prefix** on all private fields and methods
- **vitest** for tests: `describe`/`it`/`expect`, test files named `*.test.ts` alongside source
- **No default exports** -- always use named exports
- **yargs `CommandModule` pattern** for CLI commands (class with `command`, `describe`, `builder`, `handler`)
- **`@quenty/` scoped packages** for workspace imports (e.g., `@quenty/cli-output-helpers`)
- **`OutputHelper`** from `@quenty/cli-output-helpers` for all user-facing output
- **Copy the `sessions` command pattern**: Every command follows the handler/wiring split established by `src/commands/sessions.ts` and `src/cli/commands/sessions-command.ts` (Task 1.7b). Use `resolveSession()` from `src/cli/resolve-session.ts` and `formatOutput()` from `src/cli/format-output.ts`.
- **Barrel export pattern for command registration**: When adding a new command, add its export to `src/commands/index.ts` and add it to the `allCommands` array. Do NOT modify `cli.ts` -- it already registers all commands via a loop over `allCommands` (established in Task 1.7b). This pattern prevents merge conflicts when multiple tasks add commands in parallel.

---

## Task 3.1: State Query Action

**Prerequisites**: Tasks 1.6 (action dispatch), 1.7b (barrel export pattern for commands), and 2.1 (persistent plugin core) must be completed first.

**Context**: Studio-bridge needs to query the current state of a connected Roblox Studio instance (edit mode vs. play mode, place info). This task implements the server-side handler and CLI command. The plugin-side handler (Luau) is a separate task.

**Objective**: Implement the server-side state query wrapper and the `studio-bridge state` CLI command, following the same structure as the `sessions` command.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/commands/sessions.ts` (the reference command handler -- copy this structure)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/commands/sessions-command.ts` (the reference CLI wiring -- copy this structure)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/resolve-session.ts` (session resolution utility)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/format-output.ts` (output formatting utility)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/studio-bridge-server.ts` (the server with `performActionAsync` from Task 1.6)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/web-socket-protocol.ts` (v2 types: `QueryStateMessage`, `StateResultMessage`, `StudioState`)

**Files to Create**:
- `src/commands/state.ts` -- command handler following the same structure as `src/commands/sessions.ts`
- `src/cli/commands/state-command.ts` -- CLI wiring following `src/cli/commands/sessions-command.ts`

**Files to Modify**:
- `src/commands/index.ts` -- add `stateCommand` export and add it to the `allCommands` array. Do NOT modify `cli.ts`.

**Requirements**:

1. Create `src/commands/state.ts` following the same structure as `src/commands/sessions.ts`:

```typescript
import type { BridgeConnection } from '../server/bridge-connection.js';
import type { CommandResult } from '../cli/types.js';
import type { StateResultMessage } from '../server/web-socket-protocol.js';

export interface StateOptions {
  session?: string;
  instance?: string;
  context?: string;
  json?: boolean;
  watch?: boolean;
}

export interface StateQueryResult {
  state: string;
  placeId: number;
  placeName: string;
  gameId: number;
}

export async function queryStateAsync(
  connection: BridgeConnection,
  options: StateOptions = {}
): Promise<CommandResult> {
  // 1. Use resolveSessionAsync() from src/cli/resolve-session.ts to find the target session
  // 2. Send queryState via performActionAsync on the resolved session's server
  // 3. Return { data: stateResult, summary: "Mode: Edit" }
}
```

2. Create `src/cli/commands/state-command.ts` following `src/cli/commands/sessions-command.ts`:
   - Command: `state`
   - Description: `Query the current Studio state`
   - Args: `--session` / `-s`, `--instance`, `--context`, `--json`, `--watch` / `-w`
   - Handler:
     - Use `resolveSessionAsync()` from `src/cli/resolve-session.ts` for session disambiguation
     - Call `queryStateAsync(connection, options)`
     - Use `formatOutput()` from `src/cli/format-output.ts` for output
     - If `--watch`, subscribe to `stateChange` events via the WebSocket push subscription protocol (`subscribe { events: ['stateChange'] }`) and print updates as `stateChange` push messages arrive. On Ctrl+C, send `unsubscribe { events: ['stateChange'] }`. See `01-protocol.md` section 5.2 and `07-bridge-network.md` section 5.3. (If subscribe is not available yet, log "watch not yet supported" and exit.)

3. Register in `src/commands/index.ts` (NOT `cli.ts`):

```typescript
// In src/commands/index.ts, add:
export { stateCommand } from './state.js';

// And add to the allCommands array:
import { stateCommand } from './state.js';
// ... stateCommand in the allCommands array
```

**Acceptance Criteria**:
- `queryStateAsync` returns a typed `CommandResult`.
- `src/commands/index.ts` exports `stateCommand` and includes it in `allCommands`.
- `studio-bridge state` prints state info in human-readable format.
- `--json` outputs structured JSON via `formatOutput`.
- Session resolution works via `--session`, `--instance`, `--context` flags.
- Timeout after 5 seconds produces a clear error.
- **Lune test plan**: Test file: `test/state-action.test.luau`. Required test cases: StudioState values are correct strings (e.g. `"Edit"`, `"Play"`, `"Run"`, `"Paused"`), `--watch` sends subscribe message with `stateChange` event, requestId is echoed in response.

**Do NOT**:
- Modify `cli.ts` to register the command -- add it to `src/commands/index.ts` instead.
- Implement the plugin-side Luau handler (separate task).
- Use default exports.
- Forget `.js` extensions on local imports.

---

## Task 3.3: Log Query Action

**Prerequisites**: Tasks 1.6 (action dispatch), 1.7b (barrel export pattern for commands), and 2.1 (persistent plugin core) must be completed first.

**Context**: Studio-bridge needs to retrieve buffered log history from the connected Studio plugin. Logs are stored in a ring buffer on the plugin side. The server sends a `queryLogs` request and receives a `logsResult` response.

**Objective**: Implement the server-side log query wrapper and the `studio-bridge logs` CLI command, following the same structure as the `sessions` command.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/commands/sessions.ts` (the reference command handler -- copy this structure)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/commands/sessions-command.ts` (the reference CLI wiring -- copy this structure)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/resolve-session.ts` (session resolution utility)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/cli/format-output.ts` (output formatting utility)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/studio-bridge-server.ts` (server with `performActionAsync`)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/web-socket-protocol.ts` (v2 types: `QueryLogsMessage`, `LogsResultMessage`, `OutputLevel`)

**Files to Create**:
- `src/commands/logs.ts` -- command handler following the same structure as `src/commands/sessions.ts`
- `src/cli/commands/logs-command.ts` -- CLI wiring following `src/cli/commands/sessions-command.ts`

**Files to Modify**:
- `src/commands/index.ts` -- add `logsCommand` export and add it to the `allCommands` array. Do NOT modify `cli.ts`.

**Requirements**:

1. Create `src/commands/logs.ts` following the same structure as `src/commands/sessions.ts`:

```typescript
import type { BridgeConnection } from '../server/bridge-connection.js';
import type { CommandResult } from '../cli/types.js';
import type { LogsResultMessage, OutputLevel } from '../server/web-socket-protocol.js';

export interface LogsOptions {
  session?: string;
  instance?: string;
  context?: string;
  json?: boolean;
  count?: number;
  direction?: 'head' | 'tail';
  levels?: OutputLevel[];
  includeInternal?: boolean;
  follow?: boolean;
}

export interface LogEntry {
  level: OutputLevel;
  body: string;
  timestamp: number;
}

export interface LogsQueryResult {
  entries: LogEntry[];
  total: number;
  bufferCapacity: number;
}

export async function queryLogsAsync(
  connection: BridgeConnection,
  options: LogsOptions = {}
): Promise<CommandResult> {
  // 1. Use resolveSessionAsync() from src/cli/resolve-session.ts to find the target session
  // 2. Send queryLogs via performActionAsync on the resolved session's server
  // 3. Return { data: logsResult, summary: "N entries (M total in buffer)" }
}
```

2. Create `src/cli/commands/logs-command.ts` following `src/cli/commands/sessions-command.ts`:
   - Command: `logs`
   - Description: `Retrieve and stream output logs from Studio`
   - Args: `--session` / `-s`, `--instance`, `--context`, `--json`, `--tail` (number, default 50), `--head` (number), `--follow` / `-f`, `--level` / `-l` (string, comma-separated), `--all`
   - Handler:
     - Determine `direction` and `count`: if `--head` is provided use `direction: 'head'` with that count. Otherwise use `direction: 'tail'` with `--tail` value (default 50).
     - Parse `--level` into an array of `OutputLevel` strings.
     - Use `resolveSessionAsync()` from `src/cli/resolve-session.ts` for session disambiguation
     - Call `queryLogsAsync(connection, options)`
     - Use `formatOutput()` from `src/cli/format-output.ts` for output
     - If `--follow`, after printing the initial batch, subscribe to `logPush` events via the WebSocket push subscription protocol (`subscribe { events: ['logPush'] }`) and print new log entries as `logPush` push messages arrive. Continue until Ctrl+C, then send `unsubscribe { events: ['logPush'] }`. Note: `logPush` is distinct from `output` (which is batched and scoped to a single `execute` request). See `01-protocol.md` section 5.2 and `07-bridge-network.md` section 5.3. (If subscribe is not available yet, print a message and exit.)

3. Register in `src/commands/index.ts` (NOT `cli.ts`):

```typescript
// In src/commands/index.ts, add:
export { logsCommand } from './logs.js';

// And add to the allCommands array:
import { logsCommand } from './logs.js';
// ... logsCommand in the allCommands array
```

**Acceptance Criteria**:
- `queryLogsAsync` returns a typed `CommandResult`.
- `src/commands/index.ts` exports `logsCommand` and includes it in `allCommands`.
- `studio-bridge logs` prints the last 50 log lines by default.
- `--tail 100` prints the last 100.
- `--head 20` prints the first 20.
- `--level Error,Warning` filters correctly.
- `--all` includes internal messages.
- `--json` outputs JSON lines via `formatOutput`.
- Session resolution works via `--session`, `--instance`, `--context` flags.
- Timeout after 10 seconds with a clear error.
- **Lune test plan**: Test file: `test/log-action.test.luau`. Required test cases: returns entries array with correct shape, `--follow` sends subscribe message with `logPush` event, level filter works (filters entries by OutputLevel), ring buffer respects count limit and evicts oldest entries, requestId is echoed in response.

**Do NOT**:
- Modify `cli.ts` to register the command -- add it to `src/commands/index.ts` instead.
- Implement the plugin-side ring buffer (separate Luau task).
- Use default exports.
- Forget `.js` extensions on local imports.

---

## Handoff Notes for Tasks Requiring Orchestrator Coordination or Review

The following Phase 3 tasks benefit from orchestrator coordination, a review agent, or Studio validation. They can be implemented by a skilled agent but require additional verification. Brief handoff notes are provided instead of full prompts.

All handoff tasks should follow the `sessions` command pattern:
- Create `src/commands/<name>.ts` following the same structure as `src/commands/sessions.ts`
- Create `src/cli/commands/<name>-command.ts` following `src/cli/commands/sessions-command.ts`
- Add the command export to `src/commands/index.ts` and add it to the `allCommands` array. Do NOT modify `cli.ts`.
- Use `resolveSession()` from `src/cli/resolve-session.ts` and `formatOutput()` from `src/cli/format-output.ts`

### Task 3.2: Screenshot Capture Action

**Prerequisites**: Tasks 1.6 (action dispatch), 1.7b (barrel export pattern for commands), and 2.1 (persistent plugin core) must be completed first.

**Why requires review**: `CaptureService` is confirmed working in Studio plugins. Code quality and mock tests can be verified by a review agent; runtime edge cases (minimized window, rendering errors) require Studio validation.

**Handoff**: Create `src/commands/screenshot.ts` following the same structure as `src/commands/sessions.ts`. Create `src/cli/commands/screenshot-command.ts` following `src/cli/commands/sessions-command.ts`. Use `resolveSession()` from `src/cli/resolve-session.ts` and `formatOutput()` from `src/cli/format-output.ts`. Plugin side uses the confirmed CaptureService call chain: (1) `CaptureService:CaptureScreenshot(function(contentId) ... end)` to capture the viewport (callback receives a `contentId` string), (2) `AssetService:CreateEditableImageAsync(contentId)` to load the content into an `EditableImage`, (3) `editableImage:ReadPixels(...)` to extract raw pixel bytes, (4) base64-encode the bytes, (5) read dimensions from `editableImage.Size`. Each step is wrapped in `pcall` with error handling for runtime failures. Note: implementer should verify exact `EditableImage` method names against the Roblox API at implementation time. Server side writes base64 to temp PNG file. CLI has `--output`, `--open`, `--base64` flags. The `captureScreenshot` capability is always advertised (CaptureService is available in plugin context).

**Lune test plan**: Test file: `test/screenshot-action.test.luau`. Required test cases: returns base64 data with dimensions, error on CaptureService failure returns protocol error message, requestId is echoed in response.

### Task 3.4: DataModel Query Action

**Prerequisites**: Tasks 1.6 (action dispatch), 1.7b (barrel export pattern for commands), and 2.1 (persistent plugin core) must be completed first.

**Why requires review**: Complex Roblox type serialization (`Vector3`, `CFrame`, `Color3`, etc.). Code quality and serialization logic can be verified by a review agent using mock tests; full type coverage requires Studio validation against actual Roblox property types.

**Handoff**: Create `src/commands/query.ts` following the same structure as `src/commands/sessions.ts`. Create `src/cli/commands/query-command.ts` following `src/cli/commands/sessions-command.ts`. Use `resolveSession()` from `src/cli/resolve-session.ts` and `formatOutput()` from `src/cli/format-output.ts`. Plugin resolves dot-separated paths from `game` by splitting on `.` and calling `FindFirstChild` at each segment. Reads properties and serializes to `SerializedValue` format: primitives (string, number, boolean) pass as bare JSON values; Roblox types use `{ type: "...", value: [...] }` with flat arrays (e.g., Vector3 as `{ "type": "Vector3", "value": [1, 2, 3] }`, CFrame as `{ "type": "CFrame", "value": [x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22] }`, EnumItem as `{ "type": "EnumItem", "enum": "Material", "name": "Plastic", "value": 256 }`, Instance ref as `{ "type": "Instance", "className": "Part", "path": "game.Workspace.Part1" }`). See `04-action-specs.md` section 6 for the full SerializedValue format and path documentation. CLI accepts paths without `game.` prefix and prepends it. Support `--children`, `--descendants`, `--properties`, `--attributes`, `--depth`, `--json` flags. Note: instance names containing dots are an edge case -- the dot is treated as a path separator, so names with literal dots will not resolve correctly (known limitation, may be addressed with escaping in a future version).

**Lune test plan**: Test file: `test/datamodel-action.test.luau`. Required test cases: dot-path resolution walks FindFirstChild correctly, SerializedValue format is correct for each type (Vector3 as `{ type, value: [x,y,z] }`, CFrame as flat 12-element array, Color3, UDim2, UDim, EnumItem, Instance ref, primitives as bare values), error cases return protocol error messages for invalid paths, requestId is echoed in response.

### Task 3.5: Terminal Mode Dot-Commands for New Actions

**Prerequisites**: Tasks 1.7b (barrel export pattern), 2.6 (exec/run refactor), 3.1, 3.2, 3.3, and 3.4 (all action commands) must be completed first.

**Why requires review**: Interactive REPL wiring to adapter registry. Review agent verifies dispatch pattern and dot-command coverage. E2e test spec (below) provides automated validation of the terminal behavior.

**Handoff**: Add `.state`, `.screenshot`, `.logs`, `.query`, `.sessions`, `.connect`, `.disconnect` to the terminal REPL. Wire to the shared command handlers in `src/commands/`. Each dot-command calls the same handler function as the CLI command (e.g., `.state` calls `queryStateAsync` from `src/commands/state.ts`), using `formatOutput()` from `src/cli/format-output.ts` for consistent output. Reference the terminal adapter design in `studio-bridge/plans/tech-specs/02-command-system.md` section 6.

**Wiring sequence** (step-by-step guide for connecting the terminal adapter registry):
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

**E2e test spec**: Spawn the terminal as a subprocess, send stdin commands, assert stdout patterns. Test file: `src/test/e2e/terminal-dot-commands.test.ts`. Required test cases:

```typescript
describe('terminal dot-commands e2e', () => {
  // Setup: start a bridge host with a mock plugin connected,
  // then spawn `studio-bridge terminal --session <id>` as a subprocess.

  it('.state prints studio state', async () => {
    await sendStdin('.state\n');
    const output = await readStdoutUntil('Mode:');
    expect(output).toContain('Mode:');
    expect(output).toMatch(/Mode:\s+(Edit|Play|Run|Paused)/);
  });

  it('.sessions prints session table', async () => {
    await sendStdin('.sessions\n');
    const output = await readStdoutUntil('session(s) connected');
    expect(output).toContain('ID');
    expect(output).toContain('Context');
  });

  it('.screenshot prints saved path', async () => {
    await sendStdin('.screenshot\n');
    const output = await readStdoutUntil('.png');
    expect(output).toMatch(/Screenshot saved to .+\.png/);
  });

  it('.logs prints log entries', async () => {
    await sendStdin('.logs\n');
    const output = await readStdoutUntil('total in buffer');
    expect(output).toContain('total in buffer');
  });

  it('.query prints DataModel node', async () => {
    await sendStdin('.query Workspace\n');
    const output = await readStdoutUntil('ClassName:');
    expect(output).toContain('ClassName:');
  });

  it('.connect switches session', async () => {
    await sendStdin('.connect def-456\n');
    const output = await readStdoutUntil('Connected to');
    expect(output).toContain('Connected to session def-456');
  });

  it('.disconnect disconnects', async () => {
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

---

## Cross-References

- Phase plan: [studio-bridge/plans/execution/phases/03-commands.md](../phases/03-commands.md)
- Validation: [studio-bridge/plans/execution/validation/03-commands.md](../validation/03-commands.md)
- Reference command pattern: `src/commands/sessions.ts` + `src/cli/commands/sessions-command.ts` (Task 1.7b)
- Shared utilities: `src/cli/resolve-session.ts`, `src/cli/format-output.ts`, `src/cli/types.ts` (Task 1.7a)
- Tech specs: `studio-bridge/plans/tech-specs/02-command-system.md`, `studio-bridge/plans/tech-specs/04-action-specs.md`
