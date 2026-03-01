# CLI Output Modes Plan

This document describes how to extend `@quenty/cli-output-helpers` with command-level output mode abstractions so that studio-bridge can reuse the same formatting infrastructure as nevermore-cli without duplicating code.

References:
- Existing package: `tools/cli-output-helpers/`
- Command system spec: `../tech-specs/02-command-system.md`
- Execution plan: `plan.md`

---

## 1. Goal

Studio-bridge commands need to output data in three modes:

- **Table mode**: Human-readable formatted tables for TTY output (e.g., `studio-bridge sessions` shows a table of active sessions)
- **JSON mode**: Machine-readable JSON for piping and scripting (e.g., `--json` flag)
- **Watch mode**: Continuously updating output for real-time monitoring (e.g., `--watch` flag on `sessions`, `--follow` on `logs`)

The existing `@quenty/cli-output-helpers` package (`tools/cli-output-helpers/`) already provides batch job reporting infrastructure used by both `nevermore-cli` and `studio-bridge`: `Reporter` lifecycle hooks, `SpinnerReporter` (TTY progress), `GroupedReporter` (CI output), `SummaryTableReporter` (final summary), `JsonFileReporter` (JSON output to file), `OutputHelper` (color/styling), and `CompositeReporter` (fan-out to multiple reporters).

However, the existing reporters are designed for **batch job progress** (packages moving through phases toward pass/fail). Studio-bridge commands need **command-level output formatting** -- taking a `CommandResult<T>` and rendering it as a table, JSON, or live-updating stream. These are complementary concerns, not conflicting ones.

The goal is to add command output mode abstractions to `@quenty/cli-output-helpers` so that the CLI adapter in studio-bridge (and potentially nevermore-cli in the future) can select an output mode based on flags and context, without each command implementing its own formatting logic.

## 2. Current State: What Already Exists

### 2.1 Package: `@quenty/cli-output-helpers` (`tools/cli-output-helpers/`)

Source modules:

| Module | Purpose | Reusable for command output? |
|--------|---------|------------------------------|
| `outputHelper.ts` | Color formatting (`formatError`, `formatInfo`, `formatDim`, etc.), box drawing, verbose/buffered output | Yes -- color/styling is general-purpose |
| `cli-utils.ts` | `formatDurationMs()`, `isCI()` | Yes -- utility functions |
| `reporting/reporter.ts` | `Reporter` interface, `BaseReporter`, `PackageResult`, `BatchSummary` types | No -- batch-job-specific lifecycle |
| `reporting/composite-reporter.ts` | Fan-out to multiple reporters | No -- batch-job-specific |
| `reporting/spinner-reporter.ts` | TTY spinner with live-updating package status lines | Partially -- the TTY rewrite technique is reusable |
| `reporting/summary-table-reporter.ts` | Final summary table after batch run | Partially -- table formatting logic is reusable |
| `reporting/json-file-reporter.ts` | Write JSON results to a file | No -- writes to file, not stdout |
| `reporting/simple-reporter.ts` | Single-package pass/fail output | No -- batch-job-specific |
| `reporting/grouped-reporter.ts` | CI grouped output with `::group::` | No -- batch-job-specific |
| `reporting/github/*` | GitHub PR comments, job summaries, annotations | No -- GitHub-specific |
| `reporting/state/*` | `IStateTracker`, `LiveStateTracker`, `LoadedStateTracker` | No -- batch state tracking |

### 2.2 What nevermore-cli uses

nevermore-cli consumes `@quenty/cli-output-helpers` for:
- `OutputHelper` for colored console output in all commands
- The full `Reporter` stack (`CompositeReporter` + `SpinnerReporter`/`GroupedReporter` + `SummaryTableReporter` + `JsonFileReporter` + GitHub reporters) for `nevermore batch test` and `nevermore batch deploy`
- `GithubCommentColumn` / `GithubCommentTableConfig` types for customizing GitHub PR comment tables

### 2.3 What studio-bridge uses today

studio-bridge currently imports `OutputHelper` from `@quenty/cli-output-helpers` for colored error/info messages in its CLI commands. It does not use any of the reporting infrastructure.

## 3. What to Add

Add a new `output-modes/` directory inside `cli-output-helpers/src/` with command-level output formatting:

### 3.1 Table formatter

A utility that takes structured data (array of objects) and renders it as an aligned, colored terminal table. This is NOT the same as `SummaryTableReporter` (which is a batch reporter that renders pass/fail results). This is a general-purpose table renderer for arbitrary structured data.

```typescript
// tools/cli-output-helpers/src/output-modes/table-formatter.ts

export interface TableColumn<T> {
  /** Column header label */
  header: string;
  /** Extract the cell value from a row */
  value: (row: T) => string;
  /** Minimum width (default: header length) */
  minWidth?: number;
  /** Alignment: 'left' | 'right' (default: 'left') */
  align?: 'left' | 'right';
  /** Optional color function for the cell value */
  format?: (value: string, row: T) => string;
}

export interface TableOptions {
  /** Whether to print column headers (default: true) */
  showHeaders?: boolean;
  /** Whether to print a separator line below headers (default: true) */
  showSeparator?: boolean;
  /** Indent prefix for each line (default: '') */
  indent?: string;
}

/**
 * Format an array of rows as an aligned terminal table.
 * Returns the formatted string (does not print it).
 */
export function formatTable<T>(
  rows: T[],
  columns: TableColumn<T>[],
  options?: TableOptions
): string;
```

Studio-bridge usage: the `sessions` command defines columns for Session ID, Place, State, Origin, Duration and calls `formatTable()` to produce the summary string in its `CommandResult`.

### 3.2 JSON formatter

A thin wrapper that standardizes JSON output for `--json` mode. Handles pretty-printing for TTY, compact for pipes, and consistent structure.

```typescript
// tools/cli-output-helpers/src/output-modes/json-formatter.ts

export interface JsonOutputOptions {
  /** Pretty-print with indentation (default: true for TTY, false for pipe) */
  pretty?: boolean;
}

/**
 * Format structured data as JSON for stdout.
 * Returns the formatted string.
 */
export function formatJson(data: unknown, options?: JsonOutputOptions): string;
```

This is intentionally simple. The value is consistency -- every command that supports `--json` produces output with the same formatting conventions.

### 3.3 Watch renderer

A utility for commands that support `--watch` or `--follow` mode. Handles the TTY rewrite loop (clear previous output, render updated state) and the non-TTY fallback (append new lines).

```typescript
// tools/cli-output-helpers/src/output-modes/watch-renderer.ts

export interface WatchRendererOptions {
  /** Render interval in ms (default: 1000) */
  intervalMs?: number;
  /** Whether to clear and rewrite (TTY) or append (non-TTY). Auto-detected if not set. */
  rewrite?: boolean;
}

/**
 * Create a watch renderer that periodically calls a render function
 * and updates the terminal output.
 *
 * For TTY: clears previous output and rewrites (like SpinnerReporter).
 * For non-TTY: appends only new/changed lines.
 */
export function createWatchRenderer(
  render: () => string,
  options?: WatchRendererOptions
): WatchRenderer;

export interface WatchRenderer {
  /** Start the render loop */
  start(): void;
  /** Force an immediate re-render */
  update(): void;
  /** Stop the render loop and show final state */
  stop(): void;
}
```

The TTY rewrite technique is extracted from `SpinnerReporter._render()` which already implements cursor-up + clear-to-end-of-screen for live-updating output.

### 3.4 Output mode selector

A utility that the CLI adapter uses to select the correct output mode based on flags and context.

```typescript
// tools/cli-output-helpers/src/output-modes/output-mode.ts

export type OutputMode = 'table' | 'json' | 'text';

/**
 * Determine the output mode based on CLI flags and environment.
 *
 * Priority chain (first match wins):
 * 1. --json flag -> 'json'
 * 2. STUDIO_BRIDGE_OUTPUT=json env var -> 'json'
 * 3. STUDIO_BRIDGE_OUTPUT=text env var -> 'text'
 * 4. Non-TTY (piped) -> 'text'
 * 5. TTY -> 'table'
 *
 * See section 8 for the full mode selection rules.
 */
export function resolveOutputMode(options: {
  json?: boolean;
  isTTY?: boolean;
  envOverride?: string;
}): OutputMode;
```

### 3.5 Barrel export

```typescript
// tools/cli-output-helpers/src/output-modes/index.ts

export { formatTable, type TableColumn, type TableOptions } from './table-formatter.js';
export { formatJson, type JsonOutputOptions } from './json-formatter.js';
export { createWatchRenderer, type WatchRenderer, type WatchRendererOptions } from './watch-renderer.js';
export { resolveOutputMode, type OutputMode } from './output-mode.js';
```

Add to the package's top-level exports so consumers can import from `@quenty/cli-output-helpers/output-modes` or re-export from the main barrel.

## 4. Package Structure After Changes

No new package is created. The changes are additive to `tools/cli-output-helpers/`:

```
tools/cli-output-helpers/
  package.json                                # unchanged (no new dependencies needed)
  tsconfig.json                               # unchanged
  src/
    outputHelper.ts                           # unchanged
    cli-utils.ts                              # unchanged
    reporting/                                # unchanged -- batch job reporting
      index.ts
      reporter.ts
      composite-reporter.ts
      spinner-reporter.ts
      summary-table-reporter.ts
      json-file-reporter.ts
      simple-reporter.ts
      grouped-reporter.ts
      state/
        state-tracker.ts
        live-state-tracker.ts
        loaded-state-tracker.ts
      github/
        index.ts
        formatting.ts
        comment-table-reporter.ts
        job-summary-reporter.ts
        github-api.ts
        annotations.ts
    output-modes/                             # NEW -- command-level output formatting
      index.ts                                # barrel export
      table-formatter.ts                      # general-purpose table rendering
      table-formatter.test.ts                 # unit tests
      json-formatter.ts                       # standardized JSON output
      json-formatter.test.ts                  # unit tests
      watch-renderer.ts                       # live-updating output (TTY rewrite)
      watch-renderer.test.ts                  # unit tests
      output-mode.ts                          # output mode selection utility
      output-mode.test.ts                     # unit tests
```

### 4.1 Why extend, not extract

The original task description assumed reporting code lived inside `nevermore-cli` and needed to be extracted into a new package. In reality:

1. **`@quenty/cli-output-helpers` already exists** as the shared reporting package, consumed by both `nevermore-cli` and `studio-bridge`.
2. **The batch reporting infrastructure is nevermore-cli-specific** in its domain (packages, phases, pass/fail) but not in its location -- it already lives in the shared package.
3. **Studio-bridge needs different abstractions** -- command output modes (table/JSON/watch) rather than batch job progress -- but they belong in the same shared package.
4. **Creating a second shared package** (`nevermore-cli-reporting`) would fragment the reporting surface and create confusion about which package to import from.

The right approach is to add a new `output-modes/` directory to the existing `@quenty/cli-output-helpers` package. This keeps all CLI output formatting in one place, avoids a new package, and both consumers already depend on it.

## 5. Integration with Studio-Bridge Command System

### 5.1 CommandDefinition output configuration

The `CommandDefinition` type (defined in `02-command-system.md` section 5) gains an optional `output` field that tells the CLI adapter how to format the handler's result:

```typescript
export interface CommandOutputConfig<T> {
  /** Table columns for table output mode. If not provided, falls back to summary text. */
  table?: TableColumn<T>[];
  /** Whether this command supports --watch mode */
  supportsWatch?: boolean;
  /** Custom watch render function (if different from re-running the handler) */
  watchRender?: (data: T) => string;
}

export interface CommandDefinition<TInput, TOutput> {
  name: string;
  description: string;
  requiresSession: boolean;
  args: ArgSpec[];
  handler: (input: TInput, context: CommandContext) => Promise<TOutput>;
  /** Optional output formatting configuration */
  output?: CommandOutputConfig<TOutput extends CommandResult<infer D> ? D : unknown>;
}
```

### 5.2 CLI adapter uses output modes

The CLI adapter (`src/cli/adapters/cli-adapter.ts`) uses the output mode utilities from `@quenty/cli-output-helpers/output-modes`:

```typescript
import { formatTable, formatJson, resolveOutputMode, createWatchRenderer } from '@quenty/cli-output-helpers/output-modes';

// In the handler:
const mode = resolveOutputMode({
  json: argv.json,
  isTTY: !!process.stdout.isTTY,
  envOverride: process.env.STUDIO_BRIDGE_OUTPUT,
});

if (mode === 'json') {
  console.log(formatJson(result.data));
} else if (mode === 'table' && definition.output?.table) {
  const rows = Array.isArray(result.data) ? result.data : [result.data];
  console.log(formatTable(rows, definition.output.table));
} else {
  console.log(result.summary);
}
```

For watch mode:

```typescript
if (argv.watch && definition.output?.supportsWatch) {
  const renderer = createWatchRenderer(() => {
    // Re-fetch and re-render
    return definition.output!.watchRender?.(latestData) ?? result.summary;
  });
  renderer.start();
  // Stop on Ctrl+C
}
```

### 5.3 MCP adapter skips formatting

The MCP adapter always returns raw structured data -- it never uses table formatting, JSON formatting, or watch mode. It imports nothing from `output-modes/`.

```typescript
// MCP adapter -- no formatting, just raw data
return {
  content: [{ type: 'text', text: JSON.stringify(result.data) }],
};
```

### 5.4 Terminal adapter uses summary text

The terminal adapter prints `result.summary` (which may include inline table formatting if the handler used `formatTable` to compose it). It does not use `--json` or `--watch`.

### 5.5 Example: sessions command with output config

```typescript
// src/commands/sessions.ts
import { formatTable, type TableColumn } from '@quenty/cli-output-helpers/output-modes';

const sessionColumns: TableColumn<SessionInfo>[] = [
  { header: 'Session ID', value: (s) => s.sessionId.slice(0, 8) },
  { header: 'Place', value: (s) => s.placeName },
  { header: 'State', value: (s) => s.state, format: (v) => colorizeState(v) },
  { header: 'Origin', value: (s) => s.origin },
  { header: 'Connected', value: (s) => formatDuration(s.connectedAt) },
];

export const sessionsCommand: CommandDefinition<SessionsInput, CommandResult<SessionsOutput>> = {
  name: 'sessions',
  description: 'List active Studio sessions',
  requiresSession: false,
  args: [],
  output: {
    table: sessionColumns,
    supportsWatch: true,
  },
  handler: async (_input, context) => {
    const sessions = await context.connection.listSessionsAsync();
    return {
      data: { sessions },
      summary: sessions.length > 0
        ? formatTable(sessions, sessionColumns)
        : 'No active sessions.',
    };
  },
};
```

## 6. Implementation Tasks

### Task R.1: Table formatter

**Description**: Implement `formatTable()` in `tools/cli-output-helpers/src/output-modes/table-formatter.ts`. Auto-sizes columns based on content width (respecting ANSI escape codes via `OutputHelper.stripAnsi`). Handles empty rows gracefully.

**Complexity**: S

**Acceptance criteria**:
- Columns auto-size to content width, with minimum width from `minWidth` or header length.
- ANSI escape codes in cell values do not break alignment (stripped for width calculation, preserved in output).
- Empty rows array produces empty string (no headers, no separator).
- Right-aligned columns pad on the left.
- Unit tests cover: basic table, empty data, ANSI colors, right alignment, custom indent.

### Task R.2: JSON formatter

**Description**: Implement `formatJson()` in `tools/cli-output-helpers/src/output-modes/json-formatter.ts`. Thin wrapper around `JSON.stringify` with TTY-aware pretty-printing.

**Complexity**: XS

**Acceptance criteria**:
- TTY output is pretty-printed with 2-space indentation.
- Non-TTY output is compact (single line).
- `pretty` option overrides auto-detection.
- Unit tests cover: pretty, compact, explicit override.

### Task R.3: Watch renderer

**Description**: Implement `createWatchRenderer()` in `tools/cli-output-helpers/src/output-modes/watch-renderer.ts`. Extract the TTY rewrite technique from `SpinnerReporter._render()` into a reusable utility.

**Complexity**: S

**Acceptance criteria**:
- TTY mode: clears previous output and rewrites on each interval.
- Non-TTY mode: appends only new content (no cursor manipulation).
- `update()` forces immediate re-render.
- `stop()` clears the interval and shows the cursor.
- Hides cursor on `start()`, shows cursor on `stop()`.
- Unit tests cover: start/stop lifecycle, update trigger, non-TTY fallback.

### Task R.4: Output mode selector

**Description**: Implement `resolveOutputMode()` in `tools/cli-output-helpers/src/output-modes/output-mode.ts`.

**Complexity**: XS

**Acceptance criteria**:
- `--json` flag returns `'json'` regardless of TTY.
- TTY without `--json` returns `'table'`.
- Non-TTY without `--json` returns `'text'`.
- Unit tests cover all three cases.

### Task R.5: Barrel export and package integration

**Description**: Create `output-modes/index.ts`, add exports to the cli-output-helpers package entry point. Ensure the new modules are included in the TypeScript build.

**Complexity**: XS

**Acceptance criteria**:
- `import { formatTable } from '@quenty/cli-output-helpers/output-modes'` works.
- All new modules are included in the build output.
- Existing imports from `@quenty/cli-output-helpers` and `@quenty/cli-output-helpers/reporting` are unchanged.

### Task R.6: Add `output` field to CommandDefinition

**Description**: Add the `CommandOutputConfig` type and optional `output` field to `CommandDefinition` in `src/commands/types.ts`. Update the CLI adapter in `src/cli/adapters/cli-adapter.ts` to use output mode utilities from `@quenty/cli-output-helpers/output-modes`.

**Complexity**: S

**Dependencies**: Tasks R.1, R.2, R.4, and execution plan Task 1.7 (command handler infrastructure).

**Acceptance criteria**:
- `CommandDefinition` has an optional `output` field.
- CLI adapter selects output mode based on `--json` flag and TTY detection.
- Commands without an `output` field still work (fall back to `summary` text).
- MCP adapter ignores the `output` field entirely.

## 7. Sequencing and Dependencies

These tasks are **prerequisites for studio-bridge commands that need structured output** (specifically `sessions` in Task 2.6) but are **independent of the bridge networking infrastructure** (Phase 1 tasks 1.1-1.6).

Recommended sequencing:

1. **Tasks R.1-R.5** can be done in parallel with Phase 1 tasks (they modify `cli-output-helpers`, not `studio-bridge`).
2. **Task R.6** depends on Task 1.7 (command handler infrastructure) because it modifies `CommandDefinition`.
3. **Task 2.6** (sessions command) is the first command that benefits from `formatTable`. It can use table formatting from the handler's `summary` field even before Task R.6 integrates output modes into the CLI adapter.

```
R.1 (table) ────────┐
R.2 (json) ─────────┤
R.3 (watch) ────────┼──→ R.5 (barrel) ──→ R.6 (CommandDefinition output field)
R.4 (output mode) ──┘                         ↑
                                               │
1.7 (command handler infra) ───────────────────┘
```

Tasks R.1-R.5 are independent of the studio-bridge execution plan and can be completed at any time before Phase 2. Task R.6 is part of Phase 2 and should be done alongside Task 1.7 or immediately after it.

## 8. Mode Selection Rules

The output mode is determined by a priority chain. The first matching rule wins:

| Priority | Condition | Selected Mode | Rationale |
|----------|-----------|---------------|-----------|
| 1 | `--json` flag is set | `json` | Explicit user request for machine-readable output |
| 2 | `STUDIO_BRIDGE_OUTPUT=json` environment variable | `json` | CI/automation environments that always want JSON |
| 3 | `STUDIO_BRIDGE_OUTPUT=text` environment variable | `text` | Force plain text even on TTY |
| 4 | stdout is NOT a TTY (pipe detection via `process.stdout.isTTY`) | `text` | Piped output should not contain ANSI codes or table formatting |
| 5 | stdout IS a TTY | `table` | Human-friendly formatted output with colors |

The `resolveOutputMode` function implements this chain:

```typescript
export function resolveOutputMode(options: {
  json?: boolean;
  isTTY?: boolean;
  envOverride?: string; // from STUDIO_BRIDGE_OUTPUT
}): OutputMode {
  if (options.json) return 'json';
  if (options.envOverride === 'json') return 'json';
  if (options.envOverride === 'text') return 'text';
  if (!options.isTTY) return 'text';
  return 'table';
}
```

The `--watch` flag is orthogonal to the output mode. It controls whether the command runs once or subscribes to live updates. Watch mode uses the `WatchRenderer` which adapts its behavior based on TTY detection (rewrite on TTY, append on non-TTY).

There is no `--quiet` flag. The `text` mode serves this purpose -- it strips colors and table formatting, producing plain lines suitable for piping to `grep`, `jq`, or log files. Commands that output nothing on success (like `install-plugin`) simply print nothing in `text` mode.

## 9. Exact Format Strings and Example Output

### 9.1 Table mode (TTY, human-readable)

Table mode uses the `formatTable` utility with column alignment and optional ANSI color formatting. The table format follows this structure:

```
{header1}  {header2}  {header3}  ...
{sep1}     {sep2}     {sep3}     ...
{value1}   {value2}   {value3}   ...
```

- **Header row**: column headers, left-aligned by default, separated by 2 spaces minimum
- **Separator row**: dashes (`-`) matching the column width
- **Data rows**: cell values aligned to column width, separated by 2 spaces minimum
- **Column width**: `max(header.length, minWidth, max(cellValue.length for all rows))`
- **Padding character**: space (` `)
- **Column gap**: 2 spaces between columns

**Color codes used by studio-bridge commands** (via `OutputHelper` from `@quenty/cli-output-helpers`):

| Semantic | chalk function | ANSI code | Used for |
|----------|---------------|-----------|----------|
| Error | `chalk.redBright` | `\x1b[91m` | Error-level log entries, failed states, error messages |
| Warning | `chalk.yellowBright` | `\x1b[93m` | Warning-level log entries, `Paused` state |
| Info | `chalk.cyanBright` | `\x1b[96m` | `Edit` state, informational messages |
| Success | `chalk.greenBright` | `\x1b[92m` | `connected` state, `Play`/`Run` states, success messages |
| Dim | `chalk.dim` | `\x1b[2m` | Timestamps, durations, secondary metadata |
| Hint | `chalk.magentaBright` | `\x1b[95m` | Session IDs (truncated) |

**Example: `studio-bridge sessions`**

```
Session ID  Context  Place           State  Origin   Connected
----------  -------  --------------  -----  ------   ---------
a1b2c3d4    edit     MyGame (12345)  Edit   user     5m ago
e5f6g7h8    server   MyGame (12345)  Run    user     2m ago
i9j0k1l2    client   MyGame (12345)  Play   user     2m ago
```

With colors: `State` column values are colorized (`Edit` = cyan, `Run`/`Play` = green, `Paused` = yellow). `Session ID` is magenta. `Connected` duration is dim.

**Example: `studio-bridge state`**

```
Mode:    Edit
Place:   MyGame
PlaceId: 12345
GameId:  67890
Context: edit
```

This command uses key-value formatting (not a table), with keys left-padded to align the values. The `Mode` value is colorized by state (same color mapping as sessions).

**Example: `studio-bridge logs`**

```
[14:30:01] [Print]   Hello from server
[14:30:02] [Warning] Something suspicious happened
[14:30:03] [Error]   Script error at line 5: attempt to index nil
(showing 3 of 342 entries)
```

Log entries use the format: `[{timestamp}] [{level}] {body}`. Timestamps are dim. Level labels are colorized: `[Print]` = default, `[Warning]` = yellow, `[Error]` = red. The summary line at the bottom is dim.

**Example: `studio-bridge query Workspace.SpawnLocation`**

```
Name:       SpawnLocation
ClassName:  SpawnLocation
Path:       game.Workspace.SpawnLocation
Properties:
  Position:  { type: "Vector3", value: [0, 5, 0] }
  Anchored:  true
  Size:      { type: "Vector3", value: [4, 1.2, 4] }
Children: 0
```

**Example: `studio-bridge screenshot`**

```
Screenshot saved to /tmp/studio-bridge/screenshot-2026-02-23-143052.png (1920x1080)
```

### 9.2 JSON mode (`--json`)

JSON mode outputs the raw `CommandResult.data` object serialized as JSON. On TTY, it is pretty-printed with 2-space indentation. When piped (non-TTY), it is compact (single line).

**Format string**:
- TTY: `JSON.stringify(data, null, 2)` + newline
- Non-TTY: `JSON.stringify(data)` + newline

No ANSI color codes are ever included in JSON output, regardless of TTY status.

**Example: `studio-bridge sessions --json` (TTY)**

```json
{
  "sessions": [
    {
      "sessionId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "instanceId": "inst-abc-123",
      "context": "edit",
      "placeName": "MyGame",
      "placeId": 12345,
      "gameId": 67890,
      "state": "Edit",
      "origin": "user",
      "pluginVersion": "1.0.0",
      "capabilities": ["execute", "queryState", "captureScreenshot", "queryDataModel", "queryLogs", "subscribe", "heartbeat"],
      "connectedAt": "2026-02-23T14:25:00.000Z"
    }
  ]
}
```

**Example: `studio-bridge sessions --json` (piped)**

```
{"sessions":[{"sessionId":"a1b2c3d4-e5f6-7890-abcd-ef1234567890","instanceId":"inst-abc-123","context":"edit","placeName":"MyGame","placeId":12345,"gameId":67890,"state":"Edit","origin":"user","pluginVersion":"1.0.0","capabilities":["execute","queryState","captureScreenshot","queryDataModel","queryLogs","subscribe","heartbeat"],"connectedAt":"2026-02-23T14:25:00.000Z"}]}
```

**Example: `studio-bridge state --json`**

```json
{
  "state": "Edit",
  "placeName": "MyGame",
  "placeId": 12345,
  "gameId": 67890,
  "context": "edit"
}
```

**Example: `studio-bridge logs --json`**

```json
{
  "entries": [
    { "timestamp": "2026-02-23T14:30:01.000Z", "level": "Print", "body": "Hello from server" },
    { "timestamp": "2026-02-23T14:30:02.000Z", "level": "Warning", "body": "Something suspicious happened" },
    { "timestamp": "2026-02-23T14:30:03.000Z", "level": "Error", "body": "Script error at line 5: attempt to index nil" }
  ],
  "totalCount": 342,
  "returnedCount": 3
}
```

**Example: `studio-bridge screenshot --json`**

```json
{
  "filePath": "/tmp/studio-bridge/screenshot-2026-02-23-143052.png",
  "width": 1920,
  "height": 1080,
  "sizeBytes": 245760
}
```

### 9.3 Text mode (non-TTY / piped / quiet)

Text mode strips all ANSI color codes and table formatting. Output is plain lines, one per logical entry. This mode is designed for piping to `grep`, `awk`, `jq`, or redirecting to files.

**Format rules**:
- No ANSI escape codes
- No box-drawing characters
- No spinner/progress indicators
- Tab-separated values for tabular data (instead of space-padded columns)
- No separator row below headers
- Timestamps in ISO 8601 format (not relative "5m ago")

**Example: `studio-bridge sessions` (piped)**

```
Session ID	Context	Place	State	Origin	Connected
a1b2c3d4-e5f6-7890-abcd-ef1234567890	edit	MyGame (12345)	Edit	user	2026-02-23T14:25:00.000Z
e5f6g7h8-i9j0-1234-abcd-ef5678901234	server	MyGame (12345)	Run	user	2026-02-23T14:28:00.000Z
```

Note: full session ID (not truncated) and ISO timestamp (not relative).

**Example: `studio-bridge state` (piped)**

```
Mode: Edit
Place: MyGame
PlaceId: 12345
GameId: 67890
Context: edit
```

Key-value pairs, no padding alignment.

**Example: `studio-bridge logs` (piped)**

```
2026-02-23T14:30:01.000Z	Print	Hello from server
2026-02-23T14:30:02.000Z	Warning	Something suspicious happened
2026-02-23T14:30:03.000Z	Error	Script error at line 5: attempt to index nil
```

Tab-separated: timestamp, level, body. No brackets, no color, no summary line.

**Example: `studio-bridge screenshot` (piped)**

```
/tmp/studio-bridge/screenshot-2026-02-23-143052.png
```

Just the file path, nothing else. This allows `studio-bridge screenshot | xargs open`.

## 10. What This Does NOT Cover

- **Batch job reporting refactoring**: The existing `Reporter` / `SpinnerReporter` / `CompositeReporter` stack is not being changed. It continues to serve `nevermore batch test` and `nevermore batch deploy`.
- **GitHub reporters**: No changes to the GitHub comment/annotation/job-summary reporters.
- **A new package**: No new `nevermore-cli-reporting` package is created. Everything goes into the existing `@quenty/cli-output-helpers`.
- **nevermore-cli migration**: nevermore-cli does not need to change its imports or behavior. It can optionally adopt the `output-modes/` utilities for its own commands in the future, but that is not part of this plan.
