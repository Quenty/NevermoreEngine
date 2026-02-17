---
title: TypeScript Conventions
sidebar_position: 2
---

# TypeScript Conventions

CLI tools under `tools/` are TypeScript ESM packages using yargs for command parsing. This guide covers the patterns and conventions for working on these tools.

## Project structure

Each CLI tool is a standalone package under `tools/`:

```
tools/
  nevermore-cli/
    src/
      commands/          # yargs CommandModule classes
      utils/             # exported helper functions
    package.json         # defines build, build:watch, build:clean scripts
    tsconfig.json
```

### Building

Always use npm scripts, never `tsc` directly:

```bash
cd tools/nevermore-cli && npm run build        # Compile TypeScript
cd tools/nevermore-cli && npm run build:watch   # Watch mode
cd tools/nevermore-cli && npm link              # Install globally for local testing
```

### ESM imports

All local imports use `.js` extension (TypeScript compiles `.ts` to `.js`, so imports must reference the output):

```typescript
import { loadDeployConfigAsync } from "./deploy-config.js";
```

## Naming conventions

### Async suffix

Async functions are named with `Async` suffix to make it visually clear they return promises and yield:

```typescript
// Good: clear that these yield
async function uploadPlaceAsync(placeId: number): Promise<void> { ... }
async function pollTaskCompletionAsync(taskId: string): Promise<TaskResult> { ... }

// Bad: hidden async behavior
async function uploadPlace(placeId: number): Promise<void> { ... }
```

### `try*` for best-effort operations

Functions that can fail gracefully use a `try*` prefix and return a result structure instead of throwing:

```typescript
// Returns a result object — caller decides what to do
async function tryRenamePlaceAsync(placeId: number): Promise<{
    success: boolean;
    reason?: string;
}> { ... }

// Reserve throwing for operations where failure should halt the caller
async function uploadPlaceAsync(placeId: number): Promise<void> {
    // throws on failure
}
```

### Private members

Use `_` prefix for private fields and methods, matching the Luau convention:

```typescript
private _connectedClient: Client;
private _rateLimiter: RateLimiter;
```

## Command pattern

Commands are classes implementing `CommandModule<T, ArgsInterface>` from yargs:

```typescript
import type { CommandModule } from "yargs";

interface DeployRunArgs {
    target: string;
    publish: boolean;
    dryrun: boolean;
}

const deployRunCommand: CommandModule<{}, DeployRunArgs> = {
    command: "run [target]",
    describe: "Build and upload via Open Cloud",
    builder: (args) => args
        .positional("target", { type: "string", default: "test" })
        .option("publish", { type: "boolean", default: false })
        .option("dryrun", { type: "boolean", default: false }),
    handler: async (args) => {
        try {
            await deployRunAsync(args);
        } catch (err) {
            OutputHelper.error(formatError(err));
            process.exit(1);
        }
    },
};
```

### Subcommands

Use nested `args.command()` calls in the builder. Use `$0` alias for the default subcommand. See `deploy-command.ts` for the `deploy init` / `deploy run` pattern.

## Error handling

Command handlers wrap logic in try/catch, format with `OutputHelper.error()`, and call `process.exit(1)`:

```typescript
// Good: actionable error with context
OutputHelper.error(`Failed to upload place ${placeId}: ${err.message}`);
OutputHelper.hint("Check that your API key has the universe-places:write scope");
OutputHelper.hint("Run 'nevermore login --status' to verify credentials");
process.exit(1);

// Bad: raw error reaching the user
throw err;  // user sees "Error: Request failed with status code 403" + stack trace
```

Error messages should be actionable — include what went wrong, what scope/permission is needed, and links or commands to fix it.

### Interactive fallback

When credentials are missing in interactive mode, prompt inline rather than erroring. Only throw in `--yes` (CI) mode.

## Output

Use `OutputHelper` from `@quenty/cli-output-helpers` for all terminal output:

```typescript
OutputHelper.info("Building rojo project...");
OutputHelper.warn("Place file is older than 1 hour");
OutputHelper.error("API key is invalid");
OutputHelper.hint("Run 'nevermore login' to set up credentials");
```

## Dryrun support

Thread the `args` object through to helpers. For subprocess calls, `runCommandAsync()` handles dryrun automatically. For API calls, log-and-skip:

```typescript
if (args.dryrun) {
    OutputHelper.info(`[dryrun] Would upload place to ${placeId}`);
    return;
}
await uploadPlaceAsync(placeId, apiKey);
```

## Process execution

Use `runCommandAsync()` from `nevermore-cli-utils.ts` to spawn child processes (wraps `execa`). For rojo builds specifically, always use `rojoBuildAsync` from `@quenty/nevermore-template-helpers` — never invoke rojo directly via `execa`.

## Other conventions

> **Git workflow**: Commit messages, interactive rebase, and branching conventions are in [Git Workflow](git-workflow.md) (shared across Luau and TypeScript).

- **Fail fast**: Validate credentials and config before expensive operations (e.g., check API key before rojo build)
- **Utils = exported functions**: Utility modules export standalone async functions, not classes. See `open-cloud-client.ts`, `credential-store.ts`, `deploy-config.ts`
- **No header comments**: Using separating comments to delimit areas implies these should be split into separate files or classes
- **No section comment headers**: Don't use `// --- Section ---` style dividers. Code organization should be self-evident from structure
- **Platform-specific code in separate files**: When code varies by OS, split into a folder with per-platform files (e.g., `roblox-auth/windows.ts`, `roblox-auth/macos.ts`) re-exported through `index.ts`
