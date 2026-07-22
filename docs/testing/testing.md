---
title: Test Infrastructure
sidebar_position: 1
---

# Testing

So you want to unit test your project. Roblox testing has a reputation for being painful — Nevermore removes
most of the reasons why:

- **Tests run in a real place, from your terminal.** `nevermore test` builds the package's test place and
  executes it in Studio locally or headlessly via Open Cloud. No manual Studio sessions, no hand-wired runners.
- **You write ordinary Jest.** Familiar `describe`/`it`/`expect`, strictly typed, with specs living next to
  the code they test.
- **Player I/O is already intercepted.** [PlayerMock](/api/PlayerMock) stands in for real players at the
  lowest level of the stack, so server logic, remoting round-trips, and client UI all run headless through
  production code paths — no connected client, no stubbing in your tests.
- **CI is included.** `nevermore batch test` detects changed packages, runs them in the cloud, and posts
  results to your PR.

## Writing tests

We use [Jest3](https://github.com/jsdotlua/jest-lua) via the Nevermore-compatible wrapper `@quentystudios/jest-lua`. The only difference from upstream Jest is how you access globals — require `Jest` and access them via `Jest.Globals`.

Test files must end in `.spec.lua` and live alongside the code they test (e.g. `src/Shared/MyUtils.spec.lua`).

### Example test

```luau
--!strict
--[[
	@class MyUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

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

### Self-documenting code

Spec files should be comment-free apart from lint directives (`--!strict`, `-- selene:`) and the
`@class` docstring — the code and test names carry the intent. Do **not** write prose headers above
`setup()` or other helpers describing what they build, comments narrating test flow, or comments
restating what an assertion checks — `setup()`/`destroy()` is an established pattern and needs no
explanation. The only comment worth keeping is one documenting something impossible to infer from
the code (e.g. an engine-bug workaround, with a link). When in doubt, omit it.

### Clean up everything a test creates

Batch runs (and CI) execute every package's specs in **one shared place**, sequentially, under
`ServerScriptService.<package>`. There is no per-package isolation, so any background work a spec
leaves running keeps executing after the test ends and can throw during a *later* package's window —
which the runner reports as that innocent later package failing. A leaked `DataStore` auto-save loop
throwing during the `secrets` suite is a real example we hit.

So every object a test constructs must be torn down. Use the **`setup()` / `destroy()` controller
pattern** — the standard across the codebase (see the `rogue-properties` specs and
`saveslot/.../HasSaveSlots.spec.lua`). A local `setup()` creates a `Maid`, `maid:Add`s the
`ServiceBag` and every object it builds, and returns a controller: named fields plus factory
functions, and a `destroy` that cleans the maid. Each test calls `setup()`, does its work, and calls
`controller:destroy()` at the end. This is the same object-ownership idiom the Hoarcekat stories use.

```luau
local function setup()
	local maid = Maid.new()

	local serviceBag = maid:Add(ServiceBag.new())
	serviceBag:GetService(require("SomeService"))
	serviceBag:Init()
	serviceBag:Start()

	local thing = maid:Add(SomeClass.new(serviceBag))

	return {
		thing = thing,
		destroy = function()
			maid:DoCleaning()
		end,
	}
end

it("does a thing", function()
	local controller = setup()
	expect(controller.thing:DoSomething()).toEqual(true)
	controller:destroy()
end)
```

Guidelines:

- `maid:Add` **every** object `setup()` creates, not just the `ServiceBag`. A standalone object the
  bag does not own — a manager, a `DataStore`, a bound class — keeps its background work (an auto-save
  loop, a subscription) running otherwise. This is the exact bug that leaked into the `secrets` suite.
- For objects a test builds on demand (multiple stores, per-test config), expose a factory that
  returns `maid:Add(X.new(...))` — e.g. a `newDataStore()` on the controller.
- In a hung-promise guard that returns early, call `controller:destroy()` before the `return` so the
  early exit still cleans up.
- A test may still `:Destroy()` an object mid-test when that teardown *is* the behavior under test —
  the maid safely skips an already-destroyed object at `DoCleaning` (a destroyed `BaseObject` has its
  metatable nil'd), so there is no double-destroy.
- A plain object with no `ServiceBag` can skip the controller: create it in the test and
  `object:Destroy()` at the end (and in any early-return guard).

### Consume every rejection (or Jest passes but the run still fails)

Jest only tracks assertions that run inside an `it`. Any **uncaught Luau error** raised outside that —
printed as a `Stack Begin` / `Stack End` block — fails the whole run, so you can see
`Tests: N passed` from Jest and `Tests failed!` from the CLI in the same output. It is a real leak to
fix, not a false positive.

The most common cause is an **unconsumed promise rejection**. A rejected `Promise` warns
`[Promise] - Uncaught exception in promise: ...` at the end of the frame unless something consumes the
rejection. Attaching a rejection handler (`Catch`, or `Then` with a reject callback) consumes it — and so
does reading the settled outcome: `GetResults`, `Yield`, and `Wait` all mark the rejection consumed, since
the caller has inspected it. What still leaks is the **fire-and-forget** promise nobody ever reads:

```luau
-- Leaks: nothing ever consumes the rejection
store:Save()

-- Fixed: a best-effort call consumes its own failure
store:Save():Catch(function() end)
```

When you need to wait for a settled result, `PromiseTestUtils.awaitOutcome` / `awaitSettled` attach handlers
synchronously — prefer them over hand-rolled awaits.

### Standing in for a `Player`

A real `Player` cannot be `Instance.new`'d, and no client joins a headless test place — `Players.LocalPlayer`
is nil and `Players:GetPlayers()` is empty. Tests use **[PlayerMock](/api/PlayerMock)** (package
`@quenty/playermock`): a real `Instance` typed as `Player` that stands in anywhere production code touches a
player.

**The design contract is that it just works.** PlayerMock is the interception layer for everything that hits
I/O for a player — properties, character and backpack, remoting, ID-keyed engine calls (group rank, asset
ownership, ...). Core packages already branch on the mock internally, at the lowest level of the stack, so a
test creates a mock and drives production APIs unchanged. You should not need to know how the mock is
implemented to test against it; the API reference lives in the [moonwave docs](/api/PlayerMock).

If production code does **not** work against a mock, that is the package failing its contract — the fix is a
seam in the package (an `isMock` branch at the engine call, or a new domain in the `LOOKUPS` or
`INPUT_DOMAINS` tables in `PlayerMock.lua`), never a stub in your test or at a call site. If the package isn't yours to change, file
the gap upstream instead of working around it.

Add `@quenty/playermock` to the package's `package.json` (then `pnpm install`) before requiring it.

**Quick unit tests** construct mocks directly:

```luau
local PlayerMock = require("PlayerMock")

local player = PlayerMock.new({ UserId = 12345, AccountAge = 30 })
player.Parent = workspace

PlayerMock.write(player, "AccountAge", 31) -- mock a property
PlayerMock.writeLookup(player, "MarketplaceService.UserOwnsGamePassAsync", gamePassId, true)
```

`PlayerMock.writeLookup` injects the result of an ID-keyed engine call. Domains are named after the
canonical engine `Service.Method` the production code path bottoms out in, and injected values are the raw
engine result shape — the consuming util's real parsing, fallback ordering, and reject paths all execute;
only the engine call is stubbed. (For coherent group rank/role pairs, see `GroupTestUtils.assignGroupInfo`
in `@quenty/grouputils`.)

**Full-flow tests** use the services:

- Create mocks before or after booting bags — both work. `playerMockService:CreatePlayer({ UserId = 12345 })`
  ties the mock's lifetime to the bag (teardown cleans it up); a hand-built `PlayerMock.new` is yours to
  destroy.
- For client-realm code, designate the local player — before boot via
  `PlayerMock.setMockedLocalPlayer(player)` (the booting `PlayerMockServiceClient` adopts it, matching
  production where `Players.LocalPlayer` exists before any service runs), or after boot via
  `playerMockServiceClient:SetLocalPlayer(player)`. Client code resolves it as
  `Players.LocalPlayer or PlayerMock.getMockedLocalPlayer()`, and dummy-mode `Remoting` routes fires the
  same way — client↔server round-trips run headless against production remoting, with no loopback stubs.
- One server-realm mock service may be alive at a time; multiple client services (simulated clients) may
  coexist, each knowing its own local player (`playerMockServiceClient:GetLocalPlayer()`).
- Destroy every mock the test creates. Leak detection is built in: a mock may not outlive the mock service
  that observed it — the next boot that sees one fails loudly.

Behavior beyond seeded properties is emulated with real engine semantics rather than recorded:
`PlayerMock.loadCharacterAsync` is the spawn path (full avatar-loading event order, fresh `Backpack` per
spawn) and `PlayerMock.kick` really performs the removal sequence. See each function's docs.

:::warning
Never fork production behavior at a call site to survive a headless test — no `pcall` around
context-restricted engine calls, no gating on `RunService:IsRunning()`/`IsStudio()` environment queries.
Both silently change what production executes. The one acceptable `RunService` branch is **signal
selection**, and it lives centrally in `StepUtils`, never at call sites: `StepUtils.getRenderStepSignal()`
for render-bound work that doesn't feed physics (`StepUtils.bindToRenderStep`, `TimedTween`), and
`StepUtils.getAnimationStepSignal()` when server-side writes may be physics-locked (`SpringObject` —
on a live server it keeps `Stepped`, the physics pre-step, so spring-driven CFrames stay in sync with
constraints and replication). Both fall back to `Heartbeat` headless, where `Stepped` never fires.
:::

For package authors adding a seam, the branch is explicit and greppable — `PlayerMock.read`/`write` error on
anything that is not a mock, so the real-player branch stays a typed native access:

```luau
local userId = if PlayerMock.isMock(player) then PlayerMock.read(player, "UserId") else player.UserId

assert((typeof(player) == "Instance" and player:IsA("Player")) or PlayerMock.isMock(player), "Bad player")
```

`PlayerMock.findFirstAncestorMock` covers ancestor walks (`FindFirstAncestorWhichIsA("Player")` cannot see
the mock) and `PlayerMock.getMockByUserId` covers utils that only hold a `userId`.

Known limits — these are gaps in `player-mock`'s contract to fix there, not patterns to work around in tests:

- Headless UI needs a hand-sized surface: `ScreenGuiService:SetGuiParent(frame)` with an explicitly sized
  `Frame` (e.g. 1280×720), since nothing computes a viewport headless. This surface belongs in the mock.
- Concurrent simulated clients are distinct only through their services — the ambient
  `PlayerMock.getMockedLocalPlayer()` global holds a single designation, so bag-less call sites (dummy-mode
  `Remoting`) see the most recent one.
- Per-player data with no lookup domain yet: add a domain to `LOOKUPS` rather than stubbing per call
  site.

### jest.config.lua

Every testable package needs a `jest.config.lua` in its `src/` directory. This tells the test runner to discover `.spec` files:

```luau
return {
	testMatch = { "**/*.spec" },
}
```

### Migration from TestEZ to Jest

Legacy tests use the TestEZ pattern (`return function()` wrapper, `.to.equal()` matchers). New tests should use the explicit Jest pattern. Key differences:

| TestEZ (old) | Jest (new) |
|---|---|
| `--!nonstrict` | `--!strict` |
| No `Jest` require | `local Jest = require("Jest")` |
| Implicit `describe`/`it`/`expect` globals | Extract from `Jest.Globals` |
| `return function() ... end` wrapper | Top-level `describe()` (no wrapper) |
| `expect(x).to.equal(y)` | `expect(x).toEqual(y)` |
| `expect(x).to.be.ok()` | `expect(x).toBeTruthy()` |
| `expect(x).to.be.near(y, 1e-3)` | `expect(x).toBeCloseTo(y, 3)` |
| `expect(fn).to.throw()` | `expect(fn).toThrow()` |
| `expect(x).never.to.equal(y)` | `expect(x).never.toEqual(y)` |

Note: `toBeCloseTo(value, numDigits)` takes the number of decimal digits of precision (e.g. `3` means `1e-3` tolerance), not an absolute epsilon.

## Setting up a package for testing

Each testable package needs:

1. **A `deploy.nevermore.json`** with a `test` target
2. **A Rojo project file** (typically `test/default.project.json`) that builds the test place
3. **A script template** (typically `test/scripts/Server/ServerMain.server.lua`) that boots the package and runs tests
4. **A `@quentystudios/jest-lua` dependency** in the package's `package.json` (plus a `jest.config.lua`, see above) — the first `.spec.lua` in a package that has never had one must add this. Without it every spec fails to *run* with `[Loader] - "Jest" is not available` (a load error, not an assertion failure), because `require("Jest")` resolves through the package's own dependency graph. Run `pnpm install` after adding it so the workspace symlink is created.

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

local root = ServerScriptService.mypackage
local loader = root:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(root)

local NevermoreTestRunnerUtils = require("NevermoreTestRunnerUtils")

if NevermoreTestRunnerUtils.runTestsIfNeededAsync(root) then
	return
end
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

## Linux headless testing

Studio can run headlessly on Linux via Wine, enabling E2E tests in devcontainers and GitHub Actions without a display or GPU. The `studio-bridge` CLI handles all environment setup:

```bash
# One-time setup
studio-bridge linux setup --install-deps
studio-bridge linux inject-credentials  # reads $ROBLOSECURITY env var

# Run tests the same as on Windows/macOS
nevermore test
```

Prerequisites (Wine 11, Xvfb, openbox, Mesa llvmpipe) are documented in `tools/studio-bridge/src/linux/README.md`. The `linux setup --install-deps` flag installs everything on Debian/Ubuntu but is opt-in — it never runs sudo automatically.

For CI, set `ROBLOSECURITY` as a repository or Codespace secret. The `.github/workflows/studio-linux-e2e.yml` workflow demonstrates the full flow.

## CI design principles

- **Workflows should be thin.** All logic lives in `nevermore-cli` commands — GitHub Actions workflows just call them. This keeps CI debuggable locally.
- **Rate limiting** is shared across concurrent workers via the `OpenCloudClient` instance. The `RateLimiter` caps concurrent Open Cloud API requests (default 4 in-flight via a semaphore), reads `x-ratelimit-remaining` / `x-ratelimit-reset` headers, and retries 429s with jittered back-off.
- **Post results via CLI**: `nevermore tools post-test-results <file>` posts or updates a PR comment with test results and writes to the GitHub Actions job summary. Requires `GITHUB_TOKEN` for PR comments; job summaries are written automatically when `GITHUB_STEP_SUMMARY` is set.
- **Live comment updates during the run**: When `nevermore batch test` detects a CI environment, it also updates the PR comment as packages transition between phases (throttled to ~10s). The `post-test-results` step still writes the final snapshot, but reviewers see progress without waiting for the full run to finish. In `--aggregated` mode every package shares one execution, so they move through `uploading` → `scheduling` → `executing` in lock-step — that's expected, not a bug.
- **Job summaries**: Results are automatically written to the [GitHub Actions job summary](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#adding-a-job-summary) when running in CI. This makes results visible on the workflow run summary page, complementing the PR comment. The job summary is only written by `post-test-results` (not by the live batch run) to avoid duplicate entries on the workflow summary page.
