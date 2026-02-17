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
