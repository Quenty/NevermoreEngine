---
title: Test Infrastructure
sidebar_position: 1
---

# Testing

## Writing tests

We use [Jest3](https://github.com/jsdotlua/jest-lua) via the Nevermore-compatible wrapper `@quentystudios/jest-lua`. The only difference from upstream Jest is how you access globals — require `Jest` and access them via `Jest.Globals`.

Test files must end in `.spec.lua` and live alongside the code they test (e.g. `src/Shared/MyUtils.spec.lua`).

### Example test

```luau
--!nonstrict
--[[
	@class MyUtils.spec.lua
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local Jest = require("Jest")
local MyUtils = require("MyUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("MyUtils", function()
	it("should do something", function()
		expect(MyUtils.doSomething()).toBe(true)
	end)
end)
```

## Setting up a package for testing

Each testable package needs:

1. **A `deploy.nevermore.json`** with a `test` target
2. **A Rojo project file** (typically `test/default.project.json`) that builds the test place
3. **A script template** (typically `test/scripts/Server/ServerMain.server.lua`) that boots the package and runs tests

### 1. deploy.nevermore.json

Run `nevermore deploy init` from inside a package directory. The interactive wizard will walk you through setting up the test target, or use flags for non-interactive setup:

```bash
# Interactive (recommended for first time)
nevermore deploy init

# Non-interactive
nevermore deploy init --yes --universe-id 12345 --create-place --project test/default.project.json --script-template test/scripts/Server/ServerMain.server.lua
```

The resulting config looks like:

```json
{
  "targets": {
    "test": {
      "universeId": 12345,
      "placeId": 67890,
      "project": "test/default.project.json",
      "scriptTemplate": "test/scripts/Server/ServerMain.server.lua"
    }
  }
}
```

### 2. Rojo project (test/default.project.json)

The test project maps the package into `ServerScriptService` so the test runner can find it:

```json
{
  "name": "MyPackageTest",
  "tree": {
    "$className": "DataModel",
    "ServerScriptService": {
      "$properties": {
        "LoadStringEnabled": true
      },
      "mypackage": {
        "$path": ".."
      },
      "Script": {
        "$path": "scripts/Server"
      }
    }
  }
}
```

### 3. Script template (test/scripts/Server/ServerMain.server.lua)

The script template is executed via Open Cloud (or locally via studio-bridge). It bootstraps the loader and delegates to `NevermoreTestRunnerUtils`:

```luau
--!nonstrict
--[[
	@class ServerMain
]]

local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.mypackage)

local NevermoreTestRunnerUtils = require("NevermoreTestRunnerUtils")

NevermoreTestRunnerUtils.runTestsIfNeededAsync(ServerScriptService.mypackage)
```

Replace `mypackage` with the key used in your Rojo project tree.

### NevermoreTestRunnerUtils

The `@quenty/nevermore-test-runner` package provides `NevermoreTestRunnerUtils`, which handles the test execution lifecycle:

- If a `jest.config` is found under the given root, it runs Jest tests
- If no `jest.config` is found, boot success is the test (smoke test)
- Detects Open Cloud vs local execution context and exits appropriately

## Running tests

### Single package

From a package directory with a `deploy.nevermore.json`:

```bash
# Run locally via studio-bridge (default)
nevermore test

# Run via Roblox Open Cloud
nevermore test --cloud

# Show execution logs
nevermore test --logs
```

Options:
| Flag | Description |
|------|-------------|
| `--cloud` | Run tests via Open Cloud instead of locally |
| `--logs` | Show execution logs |
| `--api-key` | Roblox Open Cloud API key (`--cloud` only) |
| `--universe-id` | Override universe ID from deploy.nevermore.json |
| `--place-id` | Override place ID from deploy.nevermore.json |
| `--script-template` | Override script template path |
| `--script-text` | Luau code to execute directly instead of the configured template |

### Batch testing

Run tests across multiple packages, with automatic change detection:

```bash
# Test only packages changed vs origin/main
nevermore batch test

# Test all packages with test targets
nevermore batch test --all

# Run via Open Cloud with concurrency
nevermore batch test --cloud --concurrency 3

# Write JSON results to file
nevermore batch test --output results.json
```

Options:
| Flag | Description |
|------|-------------|
| `--cloud` | Run tests via Open Cloud instead of locally |
| `--all` | Test all packages, not just changed ones |
| `--base` | Git ref to diff against (default: `origin/main`) |
| `--concurrency` | Max parallel tests (default: 1 local, 3 cloud) |
| `--output` | Write JSON results to a file |
| `--limit` | Max number of packages to test |
| `--logs` | Show execution logs for all packages |

## Credential resolution

The CLI resolves API credentials in this order (first match wins):

1. `--api-key` CLI flag
2. `ROBLOX_OPEN_CLOUD_API_KEY` environment variable
3. `ROBLOX_UNIT_TEST_API_KEY` environment variable (backwards compat)
4. `~/.nevermore/credentials.json` (stored via `nevermore login`)

In interactive mode, if no credentials are found, the CLI prompts inline. In `--yes` (CI) mode, it errors immediately.

## Failure annotations

When tests fail in CI, the `post-test-results` command parses Jest-lua output and emits GitHub Actions annotations pointing to the failing spec files. To map Roblox instance paths (e.g. `ServerScriptService.maid.Shared.Maid.spec`) back to repo-relative filesystem paths, two strategies are used:

1. **Sourcemap resolution** (preferred) — If `sourcemap.json` exists (generated by `rojo sourcemap --absolute`), the `SourcemapResolver` builds a lookup index from the tree. This is exact and handles all project layouts. The CI workflow runs `npm run build:sourcemap` before posting results to ensure the file is available.

2. **Heuristic fallback** — When no sourcemap is available, the resolver assumes the standard `src/{slug}/src/` layout and rejoins known dotted suffixes (`.spec`, `.story`). This works for the common case but can produce wrong paths for non-standard layouts or dotted filenames.

The resolver code lives in `tools/nevermore-cli/src/utils/sourcemap/` and is shared with the `strip-sourcemap-jest` command.

## Integration testing

Integration tests verify that packages work in the context of a full game with real assets, complementing the per-package unit tests.

### How it works

Integration games live in `games/` (e.g. `games/integration/`). Each has a `deploy.nevermore.json` and a rojo project file. The pipeline:

1. **Build** code via rojo (`rojo build`)
2. **Download** the team-create place via Open Cloud (when `basePlace` is configured)
3. **Merge** fresh code into the base place using a Lune script (project-file-driven merge)
4. **Upload** the merged result via Open Cloud
5. **Smoke test** by executing server scripts via Luau execution
6. **Report** results and "Try it" links in the PR comment

### The `basePlace` config

A deploy target can optionally reference a Roblox place to download as a base:

```json
{
  "targets": {
    "test": {
      "universeId": 12345,
      "placeId": 67890,
      "project": "default.project.json",
      "basePlace": {
        "universeId": 11111,
        "placeId": 22222
      }
    }
  }
}
```

When `basePlace` is present, the build pipeline downloads that place, builds code via rojo, and merges them — transparently to the rest of the pipeline.

The download uses the Roblox Asset Delivery API and requires the `legacy-asset:manage` scope on the API key (in addition to the standard scopes listed under [Credential resolution](#credential-resolution)).

### Merge strategy

The Lune merge script reads the rojo project file to determine which instance paths are rojo-managed:

- **Navigation nodes** (no `$path` or `$className`) — traverse into the existing base service without replacing it
- **Graft nodes** (`$path` or `$className` present) — replace the named child entirely with the rojo-built version

This matches how `rojo serve` works: rojo owns specific subtrees and leaves everything else untouched.

### Setting up a new integration game

1. Create the game directory under `games/`
2. Add a `default.project.json` with the rojo project tree
3. Add a `deploy.nevermore.json` with the `test` target (and `basePlace` if needed)
4. Add a `package.json` so pnpm discovers the workspace
5. The CI workflow automatically discovers and deploys integration games via `nevermore batch deploy`

### Posting deploy results

```bash
nevermore tools post-deploy-results <results.json> --run-outcome <success|failure>
```

Posts or updates a PR comment with deploy results and "Try it" links. Parallels `post-test-results` for the deploy pipeline.

### Luau template convention

Luau scripts that run in Roblox contexts (smoke tests, transforms, templates) should be stored as `.luau` files in `build-scripts/` directories — not generated inline from TypeScript. This keeps Luau code editable, lintable, and follows the pattern established by `studio-bridge/build-scripts/`.

## CI design principles

- **Workflows should be thin.** All logic lives in `nevermore-cli` commands — GitHub Actions workflows just call them. This keeps CI debuggable locally.
- **Rate limiting** is shared across concurrent workers via the `OpenCloudClient` instance. The `RateLimiter` serializes all Open Cloud API requests (one in-flight at a time) and reads `x-ratelimit-remaining` / `x-ratelimit-reset` headers.
- **Post results via CLI**: `nevermore tools post-test-results <file>` posts or updates a PR comment with test results and writes to the GitHub Actions job summary. Requires `GITHUB_TOKEN` for PR comments; job summaries are written automatically when `GITHUB_STEP_SUMMARY` is set.
- **Job summaries**: Results are automatically written to the [GitHub Actions job summary](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#adding-a-job-summary) when running in CI. This makes results visible on the workflow run summary page, complementing the PR comment.
