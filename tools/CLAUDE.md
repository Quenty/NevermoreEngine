# TypeScript Conventions (tools/)

The `tools/` directory holds the CLI tools that drive Nevermore's development workflow. Everything here is TypeScript (ESM, Node 18+) built with pnpm workspaces.

## Tool Overview

| Package | Purpose |
|---------|---------|
| `nevermore-cli` | Main CLI (`nevermore test`, `nevermore deploy`, `nevermore init package`, `nevermore batch`) |
| `studio-bridge` | WebSocket bridge for running Luau scripts in Roblox Studio (`studio-bridge exec`) |
| `cli-output-helpers` | Shared formatting and reporting (chalk, OutputHelper, Reporter) |
| `nevermore-cli-helpers` | Shared utilities (VersionChecker, semver handling) |
| `nevermore-deploy` | Sole owner of `deploy.nevermore.json` and `deploy.nevermore.lock.json`: schema, validation, base place version resolution, target selectors (`integration.places.hub`), and watch policy. Schema and policy only — no network, no yargs — so lock semantics can't drift between commands. Reaches the outside world through three ports, all implemented in the CLI: `PlaceVersionSource` (satisfied structurally by `OpenCloudClient`), `WatchRegistry` (`HttpWatchRegistry`), and `WatchStream` (`WebSocketWatchStream`). |
| `nevermore-template-helpers` | Scaffolding and template substitution for `init package` |
| `nevermore-vscode` | VS Code extension (snippets, integration) |
| `nevermore-claude` | Claude Code plugin (ships the `strict-typing-luau` skill). Not TypeScript — see below. |

`nevermore-claude` is not a TypeScript tool. It's a Claude Code plugin (Markdown skills + JSON manifests). The monorepo is its marketplace: `.claude-plugin/marketplace.json` at the repo root lists the plugin (`source: ./tools/nevermore-claude`). Projects register it via a `github` source with `sparsePaths` to avoid cloning the whole monorepo. Merging to `main` publishes it — no separate publish action. (The catalog must stay at the repo root: a source `path` field to a nested catalog exists but breaks `marketplace update` on Claude Code 2.1.211.) See `tools/nevermore-claude/README.md`.

## Command Pattern

Commands use yargs `CommandModule<T, Args>`. Each command is a class with `command`, `describe`, `builder`, and `handler`:

```typescript
export interface TestProjectArgs extends NevermoreGlobalArgs {
	cloud?: boolean;
	apiKey?: string;
	placeId?: number;
}

export class TestProjectCommand<T> implements CommandModule<T, TestProjectArgs> {
	public command = "test";
	public describe = "Run tests for a single package";

	public builder = (args: Argv<T>) => {
		args.option("cloud", { describe: "Run in Roblox cloud", type: "boolean", default: false });
		return args as Argv<TestProjectArgs>;
	};

	public handler = async (args: TestProjectArgs) => {
		// Implementation
	};
}
```

Both CLIs apply global args via middleware:

- `nevermore-cli` uses `NevermoreGlobalArgs`: `--yes` (skip prompts), `--dryrun`, `--verbose`.
- `studio-bridge` uses `StudioBridgeGlobalArgs`: `--verbose`, `--place` (path to .rbxl), `--timeout`, `--logs`.

## CLI Output

All CLI output goes through `cli-output-helpers/reporting`. Don't build parallel formatting modules.

Inside `reporting/`, `format/` holds the pure string formatters, `batch/` the `Reporter` side, and `result/` the `ResultReporter` side.

There are two reporter shapes, for two output situations:

- `Reporter` handles batch lifecycle. Many packages, phases (`onPackageStart`, `onPackagePhaseChange`, `onPackageProgressUpdate`, `onPackageResult`), aggregated `BatchSummary`. Used by `nevermore-cli batch`. Fan out via `CompositeReporter`. Concrete reporters: `SimpleReporter`, `SpinnerReporter`, `SummaryTableReporter`, `JsonFileReporter`, `GroupedReporter`, `github/*`.
- `ResultReporter<T>` handles single-result output (one-shot or polled). `startAsync` → repeated `onResult` → `stopAsync`. Used by `studio-bridge` commands. Fan out via `CompositeResultReporter`. Concrete reporters: `StdoutResultReporter`, `FileResultReporter` (handles binary), `WatchResultReporter` (TTY redraw).

```typescript
import {
	StdoutResultReporter,
	FileResultReporter,
	WatchResultReporter,
	type ResultReporter,
} from "@quenty/cli-output-helpers/reporting";
```

Shared formatting primitives also live in `reporting/`. Command handlers can use them when they need a string from data:

```typescript
import {
	formatTable,
	formatTree,
	formatCount,
	formatJson,
	formatCsv,
	type TableColumn,
	type TreeNode,
} from "@quenty/cli-output-helpers/reporting";
```

`formatCount(n, "match", "matches")` gives `1 match` / `1,532 matches` instead of `match(es)`.

In `studio-bridge`, a command's `cli.body` renders only the body of its text output. Every result has a `summary`, and the CLI adapter alone places it: last and dim for `report` commands, or on stderr for `data` commands (`cli.output: 'data'`), whose stdout is the payload someone would pipe.

Single-result commands usually don't need to construct reporters by hand. Pass argv-style flags to `buildResultReporter({ outputPath, watch, render, binary? })` and it picks the right concrete reporter.

A few rules:

- If a new output need fits one of the existing reporters, use it.
- For a new output shape, extend `BaseReporter` (batch) or `BaseResultReporter` (single-result). Put the new reporter in `cli-output-helpers/src/reporting/batch/` or `reporting/result/`.
- For primitives (table, JSON, watch redraw), use the ones in `reporting/`. Don't add a new formatting module elsewhere.
- If you find yourself about to write a "format-output utility module" for your tool, you're rolling parallel infra. Use `ResultReporter` instead.

### SpinnerReporter and stdout

While a `SpinnerReporter` is active (between `startAsync()` and `stopAsync()`), direct stdout/stderr writes (`console.log`, `OutputHelper.info`, hints, etc.) are captured into a buffer and flushed during `stopAsync()` rather than emitted live. The spinner repaints every 80ms via a cursor-rewind (`\x1b[NA\x1b[0J`), which would otherwise clobber any text written into the render region. The captured output appears below the final spinner frame.

So: don't expect real-time progress messages from outside the reporter to show up on TTY. End-of-run summaries can be printed before or after `stopAsync` and will surface either way.

## Error Handling

Two patterns, depending on whether failure is expected.

`try/catch` with `OutputHelper.error()` is for unexpected failures in command handlers:

```typescript
try {
	await deployAsync(args);
} catch (err) {
	OutputHelper.error(err instanceof Error ? err.message : String(err));
	process.exit(1);
}
```

The `try*` pattern is for best-effort operations where failure is a normal outcome:

```typescript
export interface RenamePlaceResult {
	success: boolean;
	reason?: "no_cookie" | "api_error";
}

export async function tryRenamePlaceAsync(
	placeId: number,
	placeName: string
): Promise<RenamePlaceResult> {
	let cookie: string;
	try {
		cookie = await getRobloxCookieAsync();
	} catch {
		return { success: false, reason: "no_cookie" };
	}

	const response = await fetchWithCsrfAsync(/* ... */);
	if (response.ok) {
		return { success: true };
	}
	return { success: false, reason: "api_error" };
}
```

### studio-bridge messages

Every message a `studio-bridge` user sees follows one standard. It says what happened in the user's terms, then the consequence if that isn't obvious, then one concrete action. No internals (command lines, stacks, build hashes, raw execa output); those go in `cause`, shown only under `--verbose`.

- Throw an expected failure as `StudioBridgeError({ code, message, fix?, cause? })` (`src/messages/studio-bridge-error.ts`), or `invalidInput(message, fix)` for bad flags and arguments. The CLI adapter alone renders it: the message, then the fix on its own line, or `{ success: false, code, error, fix }` in JSON. Anything else renders as `Unexpected error: <first line>. Run with --verbose for details.`, so a plain `Error` means a bug.
- Warn through `warnUser({ code, message, fix?, cause?, oncePerMs? })` (`src/messages/warn-user.ts`). A warning that would repeat on every command, like auto-host failing, sets `oncePerMs: ONE_DAY_MS`. It is remembered in the state directory, and `--verbose` always shows it.
- Pushed Luau actions return `ActionReply.failure(code, message)`. They put their action inside the message, since the plugin relays only `code`, `message` and `details`.
- `src/messages/message-channels.test.ts` fails if a source file prints a warning or error directly.

## Naming Conventions

- Async functions end in `Async` (`uploadPlaceAsync`, `pollTaskCompletionAsync`).
- Best-effort functions use the `try*` prefix (`tryRenamePlaceAsync`, `tryGetCookieAsync`).
- Private fields and methods use a leading `_`, matching the Luau convention.

## ESM Imports

Local imports use `.js` extensions even though source files are `.ts`. Node's ESM module resolution requires this: TypeScript compiles `.ts` to `.js`, and Node resolves the compiled output.

```typescript
import { OutputHelper } from "@quenty/cli-output-helpers";       // package import (no extension)
import { deployAsync } from "./utils/deploy.js";                 // local import (.js extension)
```

## Testing

Tests use Vitest with standard `describe`/`it`/`expect`. Test files live alongside source:

```
src/MyModule.ts
src/MyModule.test.ts
```

Run tests with `npm run test` from within a tool's directory.

## Build

Each tool has its own `tsconfig.json` extending the root config. Tools reference each other as TypeScript project references for incremental builds.

```bash
cd tools/nevermore-cli && npm run build       # Build one tool
cd tools/nevermore-cli && npm run build:watch  # Watch mode
```

Always use `npm run build`, never `tsc` directly.

Full guide: `docs/conventions/typescript.md`.
