# Unified Command System: Technical Specification

This document describes how CLI commands, terminal dot-commands, and MCP tools share a single handler implementation. It is the companion document referenced from `00-overview.md` ("CLI command design, `connect` semantics, session selection heuristics").

## 1. Problem

Studio-bridge currently has two separate command surfaces:

1. **CLI commands** — yargs `CommandModule` classes in `src/cli/commands/` (`exec-command.ts`, `run-command.ts`, `terminal-command.ts`)
2. **Terminal dot-commands** — string-matched in `terminal-editor.ts` (lines 342-403): `.help`, `.exit`, `.run <file>`, `.clear`

These are completely separate implementations. Adding a new capability (state, screenshot, logs, query, sessions) would require:
- A new yargs `CommandModule` class for the CLI
- A new dot-command branch in the terminal editor
- A new MCP tool definition for AI agents
- Duplicated argument parsing, validation, error handling, and output formatting in each

With 7+ new commands planned, this duplication is unsustainable.

## 2. Golden Rule

**Every action is implemented EXACTLY ONCE as a handler function. The CLI, terminal, and MCP surfaces are thin adapters that parse input and format output -- they NEVER contain business logic.**

This is the single most important constraint in this spec. If you are writing code that calls `session.queryStateAsync()` in a CLI command file, a terminal handler, AND an MCP tool -- you are violating this rule. There is ONE handler. The three surfaces call it.

The handler:
- Receives typed, validated input and a `CommandContext`
- Performs the operation (calls session methods, reads files, etc.)
- Returns a structured result
- Knows nothing about which surface invoked it

The adapters:
- Parse surface-specific input (yargs argv, dot-command string, MCP JSON) into the handler's input type
- Call the handler
- Format the handler's structured output for their surface (terminal text, JSON, MCP response)
- Handle surface-specific concerns (exit codes, ANSI colors, MCP content blocks)

### 2.1 Anti-pattern: what NOT to do

This is what happens without the golden rule. Three files, three implementations, same logic:

```typescript
// BAD: src/cli/commands/state-command.ts
export class StateCommand implements CommandModule {
  handler = async (argv) => {
    const registry = new SessionRegistry();
    const session = await resolveSessionAsync(registry, { sessionId: argv.session });
    try {
      const result = await session.queryStateAsync();  // business logic HERE
      if (argv.json) {
        console.log(JSON.stringify(result));
      } else {
        console.log(`Place:    ${result.placeName}`);  // formatting HERE
        console.log(`Mode:     ${result.state}`);
      }
    } catch (err) {
      OutputHelper.error(err.message);                 // error handling HERE
      process.exit(1);
    } finally {
      await session.disconnectAsync();
    }
  };
}

// BAD: terminal-editor.ts (inside _handleDotCommand switch)
case '.state': {
  try {
    const result = await this._session.queryStateAsync();  // SAME business logic, copy-pasted
    console.log(`Place:    ${result.placeName}`);           // SAME formatting, copy-pasted
    console.log(`Mode:     ${result.state}`);
  } catch (err) {
    console.log(`Error: ${err.message}`);                   // DIFFERENT error handling (bug)
  }
  break;
}

// BAD: src/mcp/tools/studio-state-tool.ts
export const studioStateTool = {
  handler: async (input) => {
    const registry = new SessionRegistry();
    const session = await resolveSessionAsync(registry, { sessionId: input.sessionId });
    const result = await session.queryStateAsync();        // SAME business logic, third copy
    return { content: [{ type: 'text', text: JSON.stringify(result) }] };
    // BUG: forgot to disconnectAsync() — only the CLI version does cleanup
  },
};
```

Three copies of `queryStateAsync()` calling. Three copies of session resolution. Three different error-handling strategies. One of them has a cleanup bug. This is what happens when each surface implements the action itself.

### 2.2 Correct pattern: what TO do

One handler. Three thin adapters that call it.

```typescript
// GOOD: src/commands/state.ts — THE implementation (one file, one place)
export const stateCommand: CommandDefinition<StateInput, CommandResult<StateOutput>> = {
  name: 'state',
  description: 'Query Studio session state (run mode, place info)',
  requiresSession: true,
  args: [],
  handler: async (_input, context) => {
    const result = await context.session!.queryStateAsync();
    return {
      data: result,
      summary: [
        `Place:    ${result.placeName}`,
        `PlaceId:  ${result.placeId}`,
        `GameId:   ${result.gameId}`,
        `Mode:     ${result.state}`,
      ].join('\n'),
    };
  },
};

// GOOD: CLI — thin adapter (no business logic, generated from definition)
// src/cli/cli.ts:
yargs.command(createCliCommand(stateCommand));  // one line

// GOOD: Terminal — thin adapter (no separate file, dispatched via registry)
// terminal-mode.ts:
const dotHandler = createDotCommandHandler([stateCommand, /* ... */]);

// GOOD: MCP — thin adapter (no business logic, generated from definition)
// src/mcp/mcp-server.ts:
mcpServer.addTool(createMcpTool(stateCommand, connection));  // one line
```

The `queryStateAsync()` call appears in exactly ONE place: the handler in `src/commands/state.ts`. If the state query needs a timeout, a retry, or a new field -- you change one file.

## 3. Architectural Enforcement: File Structure as Registry

The golden rule (section 2) says every action is implemented once. This section describes how the file structure makes that rule **unbreakable**. You cannot accidentally create a command outside the pattern because the architecture rejects it structurally.

### 3.1 The `src/commands/` directory IS the command registry

Every `.ts` file in `src/commands/` (except `types.ts`, `session-resolver.ts`, `index.ts`) defines exactly one `CommandDefinition`. No exceptions. No command logic exists outside this directory. If a command handler is not in `src/commands/`, it does not exist.

### 3.2 The `src/commands/index.ts` barrel file IS the registration mechanism

```typescript
// src/commands/index.ts — THE command registry
// Every command is imported and re-exported here.
// This is the single source of truth for all available commands.

export { sessionsCommand } from './sessions.js';
export { stateCommand } from './state.js';
export { screenshotCommand } from './screenshot.js';
export { logsCommand } from './logs.js';
export { queryCommand } from './query.js';
export { execCommand } from './exec.js';
export { runCommand } from './run.js';
export { connectCommand } from './connect.js';
export { disconnectCommand } from './disconnect.js';
export { launchCommand } from './launch.js';
export { installPluginCommand } from './install-plugin.js';
export { serveCommand } from './serve.js';

// This array is used by CLI, terminal, and MCP to register all commands.
// Adding a command = adding one line here + one file in this directory.
//
// Notes on special commands:
// - serveCommand: requiresSession=false because it IS the bridge host. mcpEnabled=false.
// - installPluginCommand: requiresSession=false, local setup only. mcpEnabled=false.
// - mcpCommand: requiresSession=false, starts the MCP server. mcpEnabled=false.
// - connectCommand/disconnectCommand: terminal session management. mcpEnabled=false.
// - launchCommand: explicitly launches Studio. mcpEnabled=false (agents discover sessions).
//
// The MCP adapter filters: allCommands.filter(c => c.mcpEnabled !== false)
// Only sessions, state, screenshot, logs, query, exec, and run are MCP-eligible.
export const allCommands: CommandDefinition<any, any>[] = [
  sessionsCommand,
  stateCommand,
  screenshotCommand,
  logsCommand,
  queryCommand,
  execCommand,
  runCommand,
  connectCommand,
  disconnectCommand,
  launchCommand,
  installPluginCommand,
  serveCommand,
];
```

### 3.3 All surfaces register from `allCommands`

Every surface -- CLI, terminal, MCP -- registers commands from the same `allCommands` array. No surface imports individual command files. No surface maintains its own list.

The three thin adapters, one for each surface:

```typescript
// Three thin adapters, one shared handler
createCliCommand(cmd: CommandDefinition): YargsCommand
createDotCommand(cmd: CommandDefinition): DotCommand
createMcpTool(cmd: CommandDefinition): McpTool
```

Registration:

```typescript
// src/cli/cli.ts — ALL commands registered in one loop
import { allCommands } from '../commands/index.js';
import { createCliCommand } from './adapters/cli-adapter.js';

for (const cmd of allCommands) {
  yargs.command(createCliCommand(cmd));
}

// src/cli/commands/terminal/terminal-mode.ts — same source, same loop
import { allCommands } from '../../../commands/index.js';
import { createDotCommandHandler } from '../../adapters/terminal-adapter.js';

const dotHandler = createDotCommandHandler(allCommands);

// src/mcp/mcp-server.ts — same source, filtered by mcpEnabled
import { allCommands } from '../commands/index.js';
import { createMcpTool } from './adapters/mcp-adapter.js';

for (const cmd of allCommands.filter(c => c.mcpEnabled !== false)) {
  mcpServer.addTool(createMcpTool(cmd, connection));
}
```

The CLI registers ALL commands (including `serve`, `install-plugin`, `mcp`). The terminal adapter receives ALL commands but some are filtered by the adapter itself (e.g., `serve` is not meaningful as a dot-command). The MCP adapter only registers commands where `mcpEnabled` is not `false` -- commands like `serve`, `install-plugin`, `mcp`, `connect`, `disconnect`, and `launch` are excluded because they are process-level or interactive-only actions that do not make sense as MCP tools.

### 3.4 Why this works

- **Adding a new command** = create one file in `src/commands/`, add one line to `index.ts`. That is it. All three surfaces pick it up automatically.
- **Forgetting to register?** The command does not appear in `allCommands`. It is not registered anywhere. Easy to catch in review -- a command file that is not in `index.ts` is dead code.
- **Putting command logic in `src/cli/`?** It will not be in `allCommands`. It cannot be registered through the standard path. The architecture rejects it.
- **The `allCommands` array is the definitive list.** CLI, terminal, and MCP all use the same list. There is no way for the surfaces to disagree about which commands exist.
- **Parallel execution safety.** Seven tasks (1.7b, 2.4, 2.6, 3.1, 3.2, 3.3, 3.4) all add commands. Because each task only appends an export line to `index.ts` (and creates its own handler file), parallel worktrees produce auto-mergeable changes. Without this pattern, all seven tasks would modify `cli.ts` at the same yargs chain, causing merge conflicts. See `../execution/TODO.md` ("Merge Conflict Mitigation") for the full rationale.

### 3.5 What is NOT in `src/commands/`

Not everything belongs in the commands directory. The following are explicitly excluded:

- **Adapters** (`src/cli/adapters/`, `src/mcp/adapters/`) -- these translate between surfaces and handlers. They are generic functions that operate on any `CommandDefinition`, not specific command logic.
- **Surface-specific entry points** (`src/cli/cli.ts`, `src/mcp/mcp-server.ts`) -- these call the adapters with `allCommands`. They are wiring, not logic.
- **Editor intrinsics** (`.help`, `.exit`, `.clear`) -- these are terminal-editor concerns that control the editor itself, not Studio. They do not go through the command system.

## 4. Where Business Logic Lives

Every concern has exactly one home. If you find yourself writing the same logic in two places, something is wrong.

| Concern | Where it lives | NOT where it lives |
|---------|---------------|-------------------|
| Calling session methods (`queryStateAsync`, `execAsync`, etc.) | Handler (`src/commands/*.ts`) | CLI adapter, terminal adapter, MCP adapter |
| Argument validation (required fields, value ranges) | Handler (throws typed errors) | Adapters (they parse, not validate) |
| Session resolution | Shared utility (`resolveSessionAsync`) | Each command individually |
| Session cleanup (disconnect/stop) | Adapters (via `CommandContext.session` ownership) | Handler (it does not know about lifecycle) |
| Error handling (catch + format) | Adapters catch handler errors and format for their surface | Handler throws, does not catch-and-format |
| Output formatting (ANSI, JSON, MCP content blocks) | Adapters | Handler (returns structured `CommandResult`) |
| Human-readable summary text | Handler (returns `summary` string) | Adapters (they print it, they don't compose it) |
| Timeout enforcement | Handler (part of the operation) | Adapters |
| Exit codes, `process.exit()` | CLI adapter only | Handler, terminal adapter, MCP adapter |
| ANSI color codes | Terminal/CLI adapter formatting | Handler |

The key insight: the handler returns a `CommandResult<T>` with both structured `data` and a human-readable `summary`. The CLI adapter prints `summary` (or `JSON.stringify(data)` with `--json`). The terminal adapter prints `summary`. The MCP adapter returns `data` as JSON. No adapter needs to understand the business logic to format output.

## 5. Command Handler Interface

```typescript
// src/commands/types.ts

import type { TableColumn } from '@quenty/cli-output-helpers/output-modes';

/**
 * Optional output formatting configuration for a command.
 * Used by the CLI adapter to select table/JSON/watch output modes.
 * The MCP adapter ignores this entirely (it always returns raw data).
 */
export interface CommandOutputConfig<T> {
  /** Table columns for table output mode. If not provided, CLI falls back to summary text. */
  table?: TableColumn<T>[];
  /**
   * Whether this command supports --watch mode (continuously updating output).
   * Watch/follow modes use the WebSocket push subscription protocol: the handler
   * sends `subscribe { events: [...] }` to the plugin, and the plugin pushes
   * updates (`stateChange`, `logPush`) through the bridge host to subscribed
   * clients. See `01-protocol.md` section 5.2 and `07-bridge-network.md`
   * section 5.3 for the subscription routing mechanism.
   */
  supportsWatch?: boolean;
  /** Custom watch render function (if different from re-running the handler) */
  watchRender?: (data: T) => string;
}

/**
 * A command handler that works across CLI, terminal, and MCP surfaces.
 * TInput: the parsed arguments. TOutput: the structured result.
 */
export interface CommandDefinition<TInput, TOutput> {
  /** Machine-readable name, matches CLI command and dot-command (e.g., 'state', 'screenshot') */
  name: string;

  /** Human-readable description for help text */
  description: string;

  /** Whether this command requires an active session (most do, `sessions` and `install-plugin` don't) */
  requiresSession: boolean;

  /** Argument specification for all surfaces */
  args: ArgSpec[];

  /** The handler. Receives parsed input and a session (if requiresSession is true). */
  handler: (input: TInput, context: CommandContext) => Promise<TOutput>;

  /**
   * Optional output formatting configuration.
   * Tells the CLI adapter how to render the handler's result in table, JSON, or watch mode.
   * See `output-modes-plan.md` for the full output modes design.
   */
  output?: CommandOutputConfig<TOutput extends CommandResult<infer D> ? D : unknown>;

  // -- MCP surface configuration --

  /**
   * Whether this command is exposed as an MCP tool. Default: true.
   * Set to false for commands that don't make sense as MCP tools:
   * - `serve` (process-level, starts a bridge host)
   * - `install-plugin` (local setup, requires user action)
   * - `mcp` (the MCP server itself)
   * - `connect` / `disconnect` (terminal session management)
   * - `launch` (explicitly launches Studio; agents should discover existing sessions)
   */
  mcpEnabled?: boolean;

  /** Override the MCP tool name. Default: `studio_${name}`. */
  mcpName?: string;

  /** Override the description for MCP context (may need different phrasing for AI agents). */
  mcpDescription?: string;
}

export interface ArgSpec {
  name: string;
  description: string;
  type: 'string' | 'number' | 'boolean';
  required: boolean;
  positional?: boolean;
  alias?: string;
  default?: unknown;
}

type SessionContext = 'edit' | 'client' | 'server';

export interface CommandContext {
  /** The connected session, or undefined if requiresSession is false.
   *  This is a BridgeSession from the bridge network module (src/bridge/). */
  session?: BridgeSession;
  /** The bridge connection, always available */
  connection: BridgeConnection;
  /** Whether the caller is interactive (terminal) or non-interactive (CLI pipe, MCP) */
  interactive: boolean;
  /** The resolved session context, if applicable. Set by session resolution when --context is used or auto-detected. */
  context?: SessionContext;
}
```

### 5.1 Result formatting

Handlers return structured objects. Each surface formats them differently:

```typescript
export interface CommandResult<T> {
  /** Structured data for programmatic consumers (MCP, --json) */
  data: T;
  /** Human-readable summary for CLI/terminal output */
  summary: string;
}
```

- **CLI**: prints `summary` by default, `JSON.stringify(data)` with `--json`
- **Terminal**: prints `summary` inline
- **MCP**: returns `data` as the tool response JSON

## 6. Complete Example: The `state` Command End-to-End

This is the full implementation of the `state` command across all four files. This is not pseudocode -- this is what the actual TypeScript will look like.

### 6.1 The handler (`src/commands/state.ts`)

This is THE implementation. All business logic for querying Studio state lives here and nowhere else.

```typescript
// src/commands/state.ts

import type { CommandDefinition, CommandResult, CommandContext } from './types.js';

// -- Input and output types --------------------------------------------------

export type StudioState = 'Edit' | 'Play' | 'Paused' | 'Run' | 'Server' | 'Client';

export interface StateInput {
  // state takes no arguments beyond session (handled by the framework)
}

export interface StateOutput {
  state: StudioState;
  placeName: string;
  placeId: number;
  gameId: number;
}

// -- Handler -----------------------------------------------------------------

export const stateCommand: CommandDefinition<StateInput, CommandResult<StateOutput>> = {
  name: 'state',
  description: 'Query Studio session state (run mode, place info)',
  requiresSession: true,
  args: [],

  handler: async (_input: StateInput, context: CommandContext): Promise<CommandResult<StateOutput>> => {
    const result = await context.session!.queryStateAsync();

    return {
      data: {
        state: result.state,
        placeName: result.placeName,
        placeId: result.placeId,
        gameId: result.gameId,
      },
      summary: [
        `Place:    ${result.placeName}`,
        `PlaceId:  ${result.placeId}`,
        `GameId:   ${result.gameId}`,
        `Mode:     ${result.state}`,
      ].join('\n'),
    };
  },
};
```

That is the entire implementation. 40 lines. Everything else is adapter wiring.

### 6.2 CLI adapter wiring (`src/cli/cli.ts`)

No separate `state-command.ts` file. The CLI registers ALL commands from `allCommands` in a single loop:

```typescript
// src/cli/cli.ts (updated excerpt)
import { allCommands } from '../commands/index.js';
import { createCliCommand } from './adapters/cli-adapter.js';

const cli = yargs(hideBin(process.argv))
  .scriptName('studio-bridge');
  // ... global options ...

for (const command of allCommands) {
  cli.command(createCliCommand(command));
}

// Legacy commands kept as-is during migration
cli.command(new TerminalCommand() as any);
```

`createCliCommand` is the generic adapter that generates a yargs `CommandModule` from any `CommandDefinition`. It handles session resolution, error formatting, cleanup, and `--json` output. See section 8 for its implementation.

Running `studio-bridge state` invokes:
1. yargs parses args (the generic adapter's `builder`)
2. The generic adapter's `handler` calls `resolveSessionAsync` to get a session
3. The generic adapter's `handler` calls `stateCommand.handler(argv, context)` -- the ONE handler
4. The generic adapter's `handler` prints `result.summary` (or `JSON.stringify(result.data)` with `--json`)

### 6.3 Terminal adapter wiring (`terminal-mode.ts`)

No separate file for terminal dot-commands. The terminal mode registers ALL commands from `allCommands` into a dispatcher:

```typescript
// In terminal-mode.ts (updated excerpt)
import { allCommands } from '../../../commands/index.js';
import { createDotCommandHandler } from '../../adapters/terminal-adapter.js';

const dotHandler = createDotCommandHandler(allCommands);
```

When the user types `.state` in the terminal, the flow is:
1. `terminal-editor.ts` detects the `.` prefix and delegates to `dotHandler`
2. `dotHandler` looks up `stateCommand` by name
3. `dotHandler` calls `stateCommand.handler({}, context)` -- the ONE handler
4. `dotHandler` prints `result.summary`

### 6.4 MCP adapter wiring (`src/mcp/mcp-server.ts`)

No separate `studio-state-tool.ts` file. The MCP server registers all MCP-eligible commands from `allCommands` via the generic adapter:

```typescript
// src/mcp/mcp-server.ts (excerpt)
import { allCommands } from '../commands/index.js';
import { createMcpTool } from './adapters/mcp-adapter.js';

for (const cmd of allCommands.filter(c => c.mcpEnabled !== false)) {
  mcpServer.addTool(createMcpTool(cmd, connection));
}
```

When an MCP client calls `studio_state`, the flow is:
1. The MCP server dispatches to the generated tool handler
2. The generated handler calls `resolveSessionAsync` to get a session
3. The generated handler calls `stateCommand.handler({}, context)` -- the ONE handler
4. The generated handler returns `{ content: [{ type: 'text', text: JSON.stringify(result.data) }] }`

Full MCP server design: `06-mcp-server.md`.

### 6.5 File layout for the `state` command

```
src/
  commands/
    index.ts                    ← allCommands array includes stateCommand
    state.ts                    ← THE implementation (handler + types)
  cli/
    cli.ts                      ← loops over allCommands (no per-command lines)
    (no state-command.ts)
  cli/commands/terminal/
    terminal-mode.ts            ← passes allCommands to createDotCommandHandler
    (no separate state handler)
  mcp/
    mcp-server.ts               ← loops over allCommands.filter(c => c.mcpEnabled !== false)
    (no studio-state-tool.ts)
```

One file contains the logic. One line in `index.ts` registers it. The three surface files never change when commands are added -- they all loop over `allCommands`.

## 7. Session Resolution

Session resolution is a shared utility, not duplicated per command. It is **instance-aware**: a single Studio instance produces 1-3 sessions that share an `instanceId`, differing by `context` (`'edit'`, `'client'`, `'server'`).

```typescript
// src/commands/session-resolver.ts

type SessionContext = 'edit' | 'client' | 'server';

export interface ResolvedSession {
  session: BridgeSession;
  source: 'explicit' | 'auto-selected' | 'launched';
  context: SessionContext;
}

/**
 * Resolves a session for command execution using instance-aware heuristics.
 *
 * 1. If sessionId is provided → find by ID in registry (error if not found)
 * 2. If no sessionId → group sessions by instanceId:
 *    a. 0 instances → launch new Studio (for exec/run) or error (for other commands)
 *    b. 1 instance, --context provided → select matching context within instance
 *    c. 1 instance, Edit mode, no --context → auto-select Edit session
 *    d. 1 instance, Play mode, no --context → default to Edit context
 *    e. N instances → error with grouped list (CLI) or prompt (interactive)
 */
export async function resolveSessionAsync(
  connection: BridgeConnection,
  options: {
    sessionId?: string;
    instanceId?: string;
    context?: SessionContext;
    interactive: boolean;
    placePath?: string;
    timeoutMs?: number;
  }
): Promise<ResolvedSession>;
```

The `--session` / `-s`, `--instance`, and `--context` global options feed into `resolveSessionAsync`. All commands that require a session use this same function. The adapters call it -- the handler never calls it directly (it receives the session via `CommandContext`).

- `--session <id>` / `-s <id>`: target a specific session by session ID.
- `--instance <id>`: target a specific Studio instance by instance ID. When multiple instances are connected, this selects the instance without requiring a full session ID. Context selection (step 5a-5c in the algorithm) still applies within the selected instance.
- `--context edit|client|server`: select which VM context to target within the resolved instance.

### 7.1 Auto-selection behavior (instance-aware)

Sessions are grouped by `instanceId` before applying the heuristic:

| Instances | `--session` flag | `--instance` flag | `--context` flag | Behavior |
|-----------|-----------------|-------------------|-----------------|----------|
| 0 | not set | not set | any | Launch new Studio (preserves current exec/run behavior) or error |
| 0 | set | any | any | Error: "Session not found: {id}" |
| 1 (Edit mode) | not set | not set | not set | Auto-select the Edit session |
| 1 (Edit mode) | not set | not set | `edit` | Select Edit session |
| 1 (Edit mode) | not set | not set | `server`/`client` | Error: "No server/client context. Studio is in Edit mode." |
| 1 (Play mode) | not set | not set | not set | Default to Edit context (safe default) |
| 1 (Play mode) | not set | not set | `server` | Select Server session |
| 1 (Play mode) | not set | not set | `client` | Select Client session |
| 1 | set | any | any | Use specified session directly |
| N > 1 | not set | not set | any | Error: "Multiple Studio instances connected. Use --session or --instance to specify." + grouped list |
| N > 1 | not set | set | any | Select that instance, apply context selection |
| N > 1 | not set, interactive | not set | any | Prompt user to choose instance, then apply context |
| N > 1 | set | any | any | Use specified session directly |

### 7.2 Connect vs. launch semantics

When session resolution selects an existing session, the command **connects** to it (no Studio launch, no plugin injection, no cleanup on exit). The session has origin `'user'`. When session resolution launches a new Studio, the command **owns** it (cleanup on exit, kill Studio on stop, remove temp plugin). The session has origin `'managed'`.

This distinction is tracked on the `BridgeSession` (from `src/bridge/index.ts` -- see `07-bridge-network.md` for the full interface):

```typescript
export type SessionOrigin = 'user' | 'managed';

export interface BridgeSession {
  /** Read-only metadata about this session. */
  readonly info: SessionInfo;
  /** Which Studio VM this session represents (edit, client, or server). */
  readonly context: SessionContext;
  /** Whether the session's plugin is still connected. */
  readonly isConnected: boolean;
  /** How this session was created: 'user' (manually opened) or 'managed' (launched by studio-bridge) */
  readonly origin: SessionOrigin;

  execAsync(code: string, timeout?: number): Promise<ExecResult>;
  queryStateAsync(): Promise<StateResult>;
  captureScreenshotAsync(): Promise<ScreenshotResult>;
  queryLogsAsync(options?: LogOptions): Promise<LogsResult>;
  queryDataModelAsync(options: QueryDataModelOptions): Promise<DataModelResult>;
  subscribeAsync(events: SubscribableEvent[]): Promise<void>;
  unsubscribeAsync(events: SubscribableEvent[]): Promise<void>;
  /** Closes the connection without killing Studio (safe for any session) */
  disconnectAsync(): Promise<void>;
  /** Sends shutdown, kills Studio if origin is 'managed', cleans up resources */
  stopAsync(): Promise<void>;
}
```

- `disconnectAsync()` — closes the connection without killing Studio (safe for any session)
- `stopAsync()` — sends shutdown, kills Studio if origin is `'managed'`, cleans up resources

## 8. CLI Adapter

Each command definition generates a yargs `CommandModule`. The adapter uses output mode utilities from `@quenty/cli-output-helpers/output-modes` to select between table, JSON, and text formatting. This is the full implementation of the adapter:

```typescript
// src/cli/adapters/cli-adapter.ts

import type { CommandModule, Argv } from 'yargs';
import type { CommandDefinition, CommandContext, CommandResult } from '../../commands/types.js';
import type { StudioBridgeGlobalArgs } from '../args/global-args.js';
import { resolveSessionAsync } from '../../commands/session-resolver.js';
import { BridgeConnection } from '../../bridge/index.js';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { formatTable, formatJson, resolveOutputMode, createWatchRenderer } from '@quenty/cli-output-helpers/output-modes';

export function createCliCommand<TInput, TOutput>(
  definition: CommandDefinition<TInput, TOutput>
): CommandModule<StudioBridgeGlobalArgs, StudioBridgeGlobalArgs & TInput> {
  return {
    command: buildYargsCommand(definition),   // e.g., 'state [session-id]'
    describe: definition.description,
    builder: (yargs) => {
      for (const arg of definition.args) {
        if (arg.positional) {
          yargs.positional(arg.name, { describe: arg.description, type: arg.type });
        } else {
          yargs.option(arg.name, {
            describe: arg.description,
            type: arg.type,
            alias: arg.alias,
            default: arg.default,
          });
        }
      }
      return yargs;
    },
    handler: async (argv) => {
      const connection = await BridgeConnection.connectAsync();
      const context: CommandContext = { connection, interactive: !!process.stdout.isTTY };

      if (definition.requiresSession) {
        const resolved = await resolveSessionAsync(connection, {
          sessionId: argv.session,
          instanceId: argv.instance, // --instance <id>
          context: argv.context,     // --context edit|client|server
          interactive: context.interactive,
          placePath: argv.place,
          timeoutMs: argv.timeout,
        });
        context.session = resolved.session;
        context.context = resolved.context;
      }

      try {
        const result = await definition.handler(argv as TInput, context);
        const commandResult = result as CommandResult<unknown>;

        // Output mode selection uses @quenty/cli-output-helpers/output-modes.
        // The CLI adapter is the ONLY place that decides how to format output.
        const mode = resolveOutputMode({ json: argv.json, isTTY: !!process.stdout.isTTY });

        if (mode === 'json') {
          console.log(formatJson(commandResult.data));
        } else if (mode === 'table' && definition.output?.table) {
          const rows = Array.isArray(commandResult.data) ? commandResult.data : [commandResult.data];
          console.log(formatTable(rows, definition.output.table as any));
        } else {
          console.log(commandResult.summary);
        }
      } catch (err) {
        // Adapters catch and format errors — the handler throws, it does not
        // call OutputHelper or process.exit.
        OutputHelper.error(err instanceof Error ? err.message : String(err));
        process.exit(1);
      } finally {
        if (context.session?.origin === 'managed') {
          await context.session.stopAsync();
        } else if (context.session) {
          await context.session.disconnectAsync();
        }
      }
    },
  };
}
```

### 8.1 Registration in cli.ts

```typescript
// src/cli/cli.ts (updated)
import { allCommands } from '../commands/index.js';
import { createCliCommand } from './adapters/cli-adapter.js';

for (const command of allCommands) {
  yargs.command(createCliCommand(command));
}

// Legacy commands (exec, run, terminal) can be migrated incrementally
yargs.command(new TerminalCommand());  // kept as-is initially
```

## 9. Terminal Adapter and terminal-mode.ts Changes

### 9.1 The adapter

Terminal dot-commands are generated from the same definitions:

```typescript
// src/cli/adapters/terminal-adapter.ts

import type { CommandDefinition, CommandContext, CommandResult } from '../../commands/types.js';
import type { BridgeSession } from '../../bridge/index.js';
import type { BridgeConnection } from '../../bridge/index.js';

/**
 * Creates a dispatcher that handles ALL dot-commands from a registry of
 * command definitions. Adding a new command = adding it to the definitions
 * array. No other code changes needed.
 */
export function createDotCommandHandler(
  definitions: CommandDefinition<any, any>[]
): (input: string, session: BridgeSession, connection: BridgeConnection) => Promise<string | null> {
  return async (input, session, connection) => {
    const [commandName, ...rawArgs] = input.slice(1).split(/\s+/);
    const definition = definitions.find(d => d.name === commandName);
    if (!definition) return null; // not a recognized dot-command

    const parsedArgs = parseDotCommandArgs(definition.args, rawArgs);
    const context: CommandContext = { session, connection, interactive: true };

    try {
      const result = await definition.handler(parsedArgs, context);
      return (result as CommandResult<unknown>).summary;
    } catch (err) {
      return `Error: ${err instanceof Error ? err.message : String(err)}`;
    }
  };
}
```

### 9.2 How terminal-editor.ts changes

The existing hard-coded dot-command switch in `terminal-editor.ts` (lines 342-403) is simplified. Only the commands that are intrinsic to the editor itself (`.help`, `.exit`, `.clear`) stay hard-coded. Everything else is dispatched to the adapter:

```typescript
// In terminal-editor.ts, the _handleDotCommand method becomes:

private _handleDotCommand(text: string): void {
  const parts = text.split(/\s+/);
  const cmd = parts[0].toLowerCase();

  switch (cmd) {
    // Editor-intrinsic commands stay here — they control the editor itself,
    // not Studio. They don't go through the command system.
    case '.help':
      this._clearEditor();
      console.log(this._generateHelpText());
      this._render();
      break;

    case '.exit':
      this._clearEditor();
      this.emit('exit');
      break;

    case '.clear':
      this._lines = [''];
      this._cursorRow = 0;
      this._cursorCol = 0;
      this._render();
      break;

    default:
      // All other dot-commands are dispatched to the adapter.
      // This is where .state, .screenshot, .logs, .sessions, etc. go.
      this._clearEditor();
      this.emit('dotcommand', text);
      break;
  }
}
```

### 9.3 How terminal-mode.ts changes

`terminal-mode.ts` currently has no dot-command awareness -- it only handles `submit` (execute Luau code) and `exit`. With the adapter, it gains a `dotcommand` event handler that dispatches to the registry:

```typescript
// terminal-mode.ts (updated)
import { allCommands } from '../../../commands/index.js';
import { createDotCommandHandler } from '../../adapters/terminal-adapter.js';

// Build the dot-command dispatcher from the same allCommands used by CLI and MCP.
// Adding a new dot-command = adding one entry to allCommands in src/commands/index.ts.
// No switch statement to update, no new file to create, no change to this file.
const dotHandler = createDotCommandHandler(allCommands);

// In runTerminalMode, after setting up the editor:
editor.on('dotcommand', async (buffer: string) => {
  const output = await dotHandler(buffer, currentSession, connection);
  if (output !== null) {
    console.log(output);
  } else {
    console.log(`Unknown command: ${buffer}. Type .help for available commands.`);
  }
  console.log('');
  editor._render();
});
```

The `.help` output is auto-generated from the definitions list plus the hard-coded editor commands:

```typescript
function generateHelpText(definitions: CommandDefinition<any, any>[]): string {
  const commandLines = definitions.map(d => `  .${d.name.padEnd(20)} ${d.description}`);
  return [
    '',
    'Commands:',
    '  .help                 Show this help message',
    '  .exit                 Exit terminal mode',
    '  .clear                Clear the editor buffer',
    '  .run <file>           Read and execute a Luau file',
    ...commandLines,
    '',
    'Keybindings:',
    '  Enter                 New line',
    '  Ctrl+Enter            Execute buffer',
    '  Ctrl+C                Clear buffer (or exit if empty)',
    '  Ctrl+D                Exit',
    '  Tab                   Insert 2 spaces',
    '  Arrow keys            Move cursor',
    '',
  ].join('\n');
}
```

### 9.4 Dot-command syntax

Terminal dot-commands use a minimal syntax: `.commandName [positional] [--flag value]`. The `parseDotCommandArgs` function in the terminal adapter handles this:

```
.state                          → { }
.state --watch                  → { watch: true }
.screenshot                     → { }
.screenshot --output /tmp/s.png → { output: '/tmp/s.png' }
.logs --tail 20                 → { tail: 20 }
.logs --follow                  → { follow: true }
.logs --follow --level warn     → { follow: true, level: 'warn' }
.query Workspace                → { expression: 'Workspace' }
.query Workspace.SpawnLocation --properties Position,Anchored
                                → { expression: 'Workspace.SpawnLocation', properties: 'Position,Anchored' }
.sessions                       → { }
.run path/to/file.lua           → { file: 'path/to/file.lua' }
```

The parser splits on whitespace, treats the first token (after `.`) as the command name, and maps remaining tokens to the command's `ArgSpec`. Positional arguments are consumed in order; `--flag` tokens are matched by name. Boolean flags (like `--watch`, `--follow`) do not consume the next token. This is intentionally simpler than yargs -- dot-commands do not need subcommands, aliases, or complex validation. If parsing fails, the adapter prints a one-line usage hint derived from the command's `ArgSpec`.

Quoting rules: single or double quotes around a value preserve spaces (`--output "my file.png"` works). Unquoted values are split on whitespace as expected. There is no shell-style variable expansion or escaping -- this is a REPL, not a shell.

## 10. MCP Adapter

MCP tools are generated from the same definitions. The adapter uses `mcpName` and `mcpDescription` from the `CommandDefinition` when available, falling back to defaults. Only commands where `mcpEnabled` is not `false` are registered. Full MCP server design: `06-mcp-server.md`.

```typescript
// src/mcp/adapters/mcp-adapter.ts

import type { CommandDefinition, CommandContext, CommandResult } from '../../commands/types.js';
import { resolveSessionAsync } from '../../commands/session-resolver.js';
import type { BridgeConnection } from '../../bridge/index.js';

export function createMcpTool<TInput, TOutput>(
  definition: CommandDefinition<TInput, TOutput>,
  connection: BridgeConnection
): McpToolDefinition {
  return {
    name: definition.mcpName ?? `studio_${definition.name}`,
    description: definition.mcpDescription ?? definition.description,
    inputSchema: buildJsonSchema(definition.args),
    handler: async (input: Record<string, unknown>) => {
      const context: CommandContext = { connection, interactive: false };

      if (definition.requiresSession) {
        const resolved = await resolveSessionAsync(connection, {
          sessionId: input.sessionId as string | undefined,
          context: input.context as SessionContext | undefined,
          interactive: false,
        });
        context.session = resolved.session;
        context.context = resolved.context;
      }

      try {
        const result = await definition.handler(input as TInput, context);
        return {
          content: [{
            type: 'text',
            text: JSON.stringify((result as CommandResult<unknown>).data),
          }],
        };
      } catch (err) {
        return {
          content: [{
            type: 'text',
            text: JSON.stringify({ error: err instanceof Error ? err.message : String(err) }),
          }],
          isError: true,
        };
      } finally {
        if (context.session && context.session.origin !== 'managed') {
          await context.session.disconnectAsync();
        }
      }
    },
  };
}
```

## 11. Adding a New Command: The Checklist

To add a new command (e.g., `logs`), you touch exactly TWO files:

1. **Create `src/commands/logs.ts`** -- define `LogsInput`, `LogsOutput`, and `logsCommand: CommandDefinition<...>` with the handler
2. **Add to `src/commands/index.ts`** -- import `logsCommand`, add it to the named exports and to the `allCommands` array

That is it. The CLI, terminal, and MCP surfaces all loop over `allCommands`. They never change when commands are added. No other files need to be touched.

You do NOT:
- Create a `logs-command.ts` yargs class
- Add a case to a switch statement in `terminal-editor.ts`
- Create a `studio-logs-tool.ts` MCP tool file
- Add a line to `cli.ts`, `terminal-mode.ts`, or `server.ts`
- Duplicate argument parsing, session resolution, error handling, or output formatting

If you find yourself doing any of those things, re-read sections 2 and 3.

## 12. File Layout

### The `src/commands/` directory -- ALL command logic lives here

```
src/
  commands/                           ← ALL command logic lives here
    index.ts                          ← barrel + allCommands registry (THE single source of truth)
    types.ts                          ← CommandDefinition, CommandContext, CommandResult, ArgSpec
    session-resolver.ts               ← shared session resolution utility
    sessions.ts                       ← one file per command
    state.ts
    screenshot.ts
    logs.ts
    query.ts
    exec.ts
    run.ts
    connect.ts
    disconnect.ts
    launch.ts
    install-plugin.ts
    serve.ts                          ← special: requiresSession=false, mcpEnabled=false
    mcp.ts                            ← special: requiresSession=false, mcpEnabled=false
```

### Surfaces -- consumers of `allCommands`, not owners of command logic

```
src/
  cli/
    adapters/
      cli-adapter.ts                  ← createCliCommand (generic, operates on any CommandDefinition)
      terminal-adapter.ts             ← createDotCommandHandler (generic, operates on any CommandDefinition)
    cli.ts                            ← registers allCommands via loop (never imports individual commands)
    commands/terminal/
      terminal-mode.ts                ← registers allCommands via loop (never imports individual commands)
      terminal-editor.ts              ← only .help/.exit/.clear (editor intrinsics, not commands)
  mcp/
    adapters/
      mcp-adapter.ts                  ← createMcpTool (generic, operates on any CommandDefinition)
    mcp-server.ts                     ← registers allCommands.filter(c => c.mcpEnabled !== false) via loop
```

### Other files

The `BridgeSession` class is defined in the bridge network module (`src/bridge/bridge-session.ts`).
See `07-bridge-network.md` section 2.3 for the full interface definition.

### Modified files

| File | Change |
|------|--------|
| `src/cli/cli.ts` | Register all commands via `for (const cmd of allCommands)` loop |
| `src/cli/args/global-args.ts` | Add `session?: string`, `instance?: string`, `context?: SessionContext`, `json?: boolean`, `remote?: string`, and `local?: boolean` to `StudioBridgeGlobalArgs` |
| `src/cli/commands/terminal/terminal-editor.ts` | Emit `dotcommand` event for non-intrinsic dot-commands |
| `src/cli/commands/terminal/terminal-mode.ts` | Wire up `dotcommand` event to `createDotCommandHandler(allCommands)` |
| `src/index.ts` | Export command types (BridgeSession is exported from `src/bridge/index.ts`) |

### What does NOT exist

To be explicit about what this design avoids:

- `src/cli/commands/state-command.ts` -- does not exist. No per-command CLI files for new commands.
- `src/cli/commands/logs-command.ts` -- does not exist. Same reason.
- `src/cli/commands/serve-command.ts` -- does not exist. The serve command lives in `src/commands/serve.ts` like all other commands.
- `src/server/daemon-server.ts`, `src/server/daemon-client.ts`, `src/server/daemon-protocol.ts` -- do not exist. The split server uses the same `bridge-host.ts` and `bridge-client.ts` from `src/bridge/internal/`. No separate daemon abstraction layer.
- `src/server/environment-detection.ts` -- does not exist at that path. Environment detection lives in `src/bridge/internal/environment-detection.ts` because it is part of the bridge connection logic.
- `src/mcp/tools/studio-state-tool.ts` -- does not exist. No per-command MCP files.
- `src/mcp/tools/studio-exec-tool.ts` -- does not exist. Same reason.
- `src/mcp/tools/index.ts` -- does not exist. Tools are registered in the loop in `mcp-server.ts`.
- Any dot-command logic in `terminal-editor.ts` beyond `.help`, `.exit`, `.clear` -- does not exist.
- Any individual command imports in `cli.ts`, `terminal-mode.ts`, or `mcp-server.ts` -- do not exist. These files import `allCommands` from `src/commands/index.js` and nothing else from that directory.

### Special commands and MCP eligibility

Several commands are excluded from the MCP surface via `mcpEnabled: false`:

| Command | `requiresSession` | `mcpEnabled` | Reason excluded from MCP |
|---------|-------------------|-------------|-------------------------|
| `serve` | `false` | `false` | Process-level command that starts a bridge host |
| `install-plugin` | `false` | `false` | Local setup, requires user to restart Studio |
| `mcp` | `false` | `false` | IS the MCP server; cannot expose itself |
| `connect` | `true` | `false` | Enters interactive terminal mode |
| `disconnect` | `true` | `false` | Terminal session management |
| `launch` | `false` | `false` | Explicitly launches Studio; agents discover sessions instead |

Commands without `mcpEnabled` set (or with `mcpEnabled: true`) are automatically exposed as MCP tools: `sessions`, `state`, `screenshot`, `logs`, `query`, `exec`, `run`.

### Global `--context` flag

All session-requiring commands (`requiresSession: true`) support the `--context edit|client|server` global flag. This flag selects which session context to target when a single Studio instance has multiple active sessions (i.e., during Play mode). The flag is passed through to `resolveSessionAsync` and is available on the MCP surface as an optional `context` parameter.

| Command | Supports `--context` | Notes |
|---------|---------------------|-------|
| `state` | yes | Query state of a specific context |
| `screenshot` | yes | Capture viewport of a specific context |
| `logs` | yes | Read logs from a specific context |
| `query` | yes | Query DataModel in a specific context |
| `exec` | yes | Execute in Server context is common for Play mode debugging |
| `run` | yes | Same as exec |
| `connect` | yes | Connect terminal to a specific context |
| `sessions` | no | Lists all sessions/contexts |
| `serve` | no | Not session-targeting |
| `install-plugin` | no | Not session-targeting |
| `launch` | no | Not session-targeting |

The `serve` command has `requiresSession: false` because it IS the bridge host. It does not go through session resolution. The terminal adapter and MCP adapter skip it (it is a process-level command that starts a long-running host, not a session-level action). The CLI adapter registers it normally but the adapter's session resolution branch is not entered because `requiresSession` is false.

## 13. Concrete Example: Screenshot Command

One more example to show the pattern scales. One handler, three surfaces:

```typescript
// src/commands/screenshot.ts

export interface ScreenshotInput {
  output?: string;
  open?: boolean;
  base64?: boolean;
}

export interface ScreenshotOutput {
  filePath?: string;
  base64Data?: string;
  width: number;
  height: number;
}

export const screenshotCommand: CommandDefinition<ScreenshotInput, CommandResult<ScreenshotOutput>> = {
  name: 'screenshot',
  description: 'Capture a screenshot of the Studio viewport',
  requiresSession: true,
  args: [
    { name: 'output', alias: 'o', type: 'string', required: false, description: 'Output file path' },
    { name: 'open', type: 'boolean', required: false, default: false, description: 'Open after capture' },
    { name: 'base64', type: 'boolean', required: false, default: false, description: 'Print base64 to stdout' },
  ],
  handler: async (input, context) => {
    const result = await context.session!.captureScreenshotAsync();

    if (input.base64) {
      return {
        data: { base64Data: result.data, width: result.width, height: result.height },
        summary: result.data,
      };
    }

    const filePath = input.output ?? generateTempScreenshotPath();
    await writeFileAsync(filePath, Buffer.from(result.data, 'base64'));

    if (input.open) {
      await openFileAsync(filePath);
    }

    return {
      data: { filePath, width: result.width, height: result.height },
      summary: `Screenshot saved to ${filePath} (${result.width}x${result.height})`,
    };
  },
};
```

**CLI usage**: `studio-bridge screenshot --output ./capture.png --open`
**Terminal usage**: `.screenshot ./capture.png`
**MCP tool**: `studio_screenshot` returns `{ filePath, width, height }` or `{ base64Data, width, height }`

## 14. Design Decision: Thin Adapters, Not a Framework

This design does **not** propose replacing yargs or the terminal editor with a new framework. Both are well-tested and appropriate for their context. Instead, the approach is:

- Each command has a **single handler function** with typed input and output
- **Adapters** for each surface (CLI, terminal, MCP) call the handler and format the result
- Adapters are thin -- they translate surface-specific concerns (yargs args, dot-command strings, MCP JSON) into a common input shape and the handler's output into surface-specific output

The handler does not know which surface invoked it.

## 15. Migration Path

The migration is incremental -- each command is refactored independently:

### Step 1: Infrastructure (Phase 1)
- Create `CommandDefinition`, `CommandContext`, `CommandResult` types
- Create `resolveSessionAsync`
- Create `BridgeSession` class in `src/bridge/bridge-session.ts` (see `07-bridge-network.md`)
- Create CLI and terminal adapters

### Step 2: New commands first (Phase 2-3)
- All new commands (`sessions`, `state`, `screenshot`, `logs`, `query`, `install-plugin`) use the handler pattern from day one
- No migration needed -- they're born into the new system

### Step 3: Existing commands (Phase 6, optional)
- `exec` and `run` can be refactored to extract their handler logic into `src/commands/exec.ts` and `src/commands/run.ts`
- The existing `ExecCommand` and `RunCommand` yargs classes become thin wrappers or are replaced by `createCliCommand`
- `terminal` is special (it's a mode, not a command) -- it stays as a yargs CommandModule but uses the adapter for dot-commands

This is deliberately not a big-bang rewrite. The existing commands continue to work through their current code paths until explicitly migrated.

## 16. Dependency: `@quenty/cli-output-helpers` Output Modes

The CLI adapter depends on output mode utilities from `@quenty/cli-output-helpers/output-modes` for table formatting, JSON output, watch/follow mode, and output mode selection. These utilities are added to the existing `@quenty/cli-output-helpers` package (which studio-bridge already depends on) -- no new package is needed.

The output modes provide:

| Utility | Purpose | Used by |
|---------|---------|---------|
| `formatTable(rows, columns)` | Render an array of objects as an aligned terminal table | CLI adapter (table mode), handlers (for `summary` text) |
| `formatJson(data)` | Render structured data as JSON (pretty for TTY, compact for pipe) | CLI adapter (`--json` flag) |
| `createWatchRenderer(render)` | Live-updating terminal output with TTY rewrite / non-TTY append | CLI adapter (`--watch` / `--follow` flags) |
| `resolveOutputMode(options)` | Select `'table'` / `'json'` / `'text'` based on flags and environment | CLI adapter |

The MCP adapter does NOT use any output mode utilities. It always returns raw structured data as JSON.

The terminal adapter does NOT use output mode utilities directly. It prints the handler's `summary` string, which the handler may compose using `formatTable` internally.

Full design: `../execution/output-modes-plan.md`
