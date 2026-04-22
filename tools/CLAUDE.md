# TypeScript Conventions (tools/)

The `tools/` directory contains the CLI tools that power Nevermore's development workflow. All are TypeScript (ESM, Node 18+), built with pnpm workspaces.

## Tool Overview

| Package | Purpose |
|---------|---------|
| `nevermore-cli` | Main CLI (`nevermore test`, `nevermore deploy`, `nevermore init-package`, `nevermore batch`) |
| `studio-bridge` | WebSocket bridge for running Luau scripts in Roblox Studio (`studio-bridge exec`) |
| `cli-output-helpers` | Shared formatting and reporting (chalk, OutputHelper, Reporter) |
| `nevermore-cli-helpers` | Shared utilities (VersionChecker, semver handling) |
| `nevermore-template-helpers` | Scaffolding and template substitution for `init-package` |
| `nevermore-vscode` | VS Code extension (snippets, integration) |

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

Both CLIs define global args applied via middleware:

- **nevermore-cli**: `NevermoreGlobalArgs` — `--yes` (skip prompts), `--dryrun`, `--verbose`
- **studio-bridge**: `StudioBridgeGlobalArgs` — `--verbose`, `--place` (path to .rbxl), `--timeout`, `--logs`

## Error Handling

Two patterns, depending on whether failure is expected:

**`try/catch` with `OutputHelper.error()`** — for unexpected failures in command handlers:

```typescript
try {
	await deployAsync(args);
} catch (err) {
	OutputHelper.error(err instanceof Error ? err.message : String(err));
	process.exit(1);
}
```

**`try*` pattern** — for best-effort operations where failure is a normal outcome:

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

## Naming Conventions

- **Async suffix**: All async functions end in `Async` — `uploadPlaceAsync`, `pollTaskCompletionAsync`
- **`try*` prefix**: Best-effort functions — `tryRenamePlaceAsync`, `tryGetCookieAsync`
- **Private `_` prefix**: Same as Luau convention

## ESM Imports

All local imports use `.js` extensions, even though source files are `.ts`. This is required by Node's ESM module resolution — TypeScript compiles `.ts` to `.js`, and Node resolves the compiled output:

```typescript
import { OutputHelper } from "@quenty/cli-output-helpers";       // package import (no extension)
import { deployAsync } from "./utils/deploy.js";                 // local import (.js extension)
```

## Testing

Tests use **Vitest** with standard `describe`/`it`/`expect`. Test files live alongside source:

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

Full guide: `docs/conventions/typescript.md`
