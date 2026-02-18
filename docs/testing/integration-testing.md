---
title: Integration Testing
sidebar_position: 2
---

# Integration testing

Per-package unit tests (see [Test Infrastructure](testing.md)) verify individual packages in isolation. Integration tests go further — they deploy a full game that depends on many packages, upload it to Roblox, and run a smoke test to confirm everything boots together. This catches problems that unit tests miss: incompatible package versions, missing dependencies, and broken service initialization order.

## When to use integration tests

Integration tests are useful when you have a game or experience that pulls in multiple Nevermore packages and you want to verify the whole thing works on every PR. Typical use cases:

- A production game that depends on dozens of packages — catch regressions before merging
- A dedicated test game that exercises specific package combinations together
- A team-create place where artists build content and code is deployed separately

## Quick start

If you already have a Roblox universe and place set up, the minimum setup is four files in a directory under `games/`:

```
games/my-game/
├── package.json               # So pnpm discovers the workspace
├── deploy.nevermore.json       # Tells the CLI where to deploy
├── default.project.json        # Rojo project that maps code into the place
└── scripts/
    └── Server/
        └── ServerMain.server.lua   # Entry point that runs in Roblox
```

Then deploy with:

```bash
nevermore deploy run
```

The rest of this guide walks through each file and the available options.

## Setting up a new integration game

### 1. Create the game directory

Create a directory under `games/` and add a `package.json` so pnpm includes it in the workspace. List the Nevermore packages your game depends on:

```json
{
  "name": "@quenty/my-game",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "@quenty/loader": "workspace:*",
    "@quenty/servicebag": "workspace:*",
    "@quenty/maid": "workspace:*"
  }
}
```

Then run `pnpm install` from the repo root so the dependencies are linked.

### 2. Add a Rojo project file

The `default.project.json` maps your game's code into the Roblox DataModel. Here's an example from the built-in integration game:

```json
{
  "name": "MyGameTest",
  "tree": {
    "$className": "DataModel",
    "ServerScriptService": {
      "$properties": {
        "LoadStringEnabled": true
      },
      "mygame": {
        "$className": "Folder",
        "game": {
          "$path": "modules"
        },
        "node_modules": {
          "$path": "node_modules"
        }
      },
      "Script": {
        "$path": "scripts/Server"
      }
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "Main": {
          "$path": "scripts/Client"
        }
      }
    }
  }
}
```

`LoadStringEnabled` must be `true` because the smoke test executes code via Open Cloud's Luau execution API.

### 3. Add a deploy config

Create `deploy.nevermore.json` with a `test` target pointing to your Roblox universe and place:

```json
{
  "targets": {
    "test": {
      "universeId": 12345,
      "placeId": 67890,
      "project": "default.project.json"
    }
  }
}
```

### 4. Add entry scripts

Add a server entry point at `scripts/Server/ServerMain.server.lua` that bootstraps the loader:

```luau
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.mygame)

local ServiceBag = require("ServiceBag")

local serviceBag = ServiceBag.new()
serviceBag:GetService(require("MyService"))
-- ... register services
serviceBag:Init()
serviceBag:Start()
```

Replace `mygame` with the key used in your Rojo project tree.

## Running deploys

### Single game

From the game directory:

```bash
# Deploy to the test target (default)
nevermore deploy run

# Deploy and publish (makes the version live in-game)
nevermore deploy run --publish

# Deploy a specific target
nevermore deploy run staging

# Show build and upload logs
nevermore deploy run --logs
```

| Flag | Description |
|------|-------------|
| `--publish` | Publish the place (default: saved as draft) |
| `--api-key` | Roblox Open Cloud API key |
| `--universe-id` | Override universe ID from config |
| `--place-id` | Override place ID from config |
| `--place-file` | Upload a pre-built `.rbxl` instead of building via rojo |

### Batch deploy

Deploy multiple games at once, with automatic change detection:

```bash
# Deploy only games affected by changes vs origin/main
nevermore batch deploy

# Deploy all games with deploy targets
nevermore batch deploy --all

# Control parallelism
nevermore batch deploy --concurrency 3

# Write JSON results to a file (for CI)
nevermore batch deploy --output results.json
```

| Flag | Description |
|------|-------------|
| `--all` | Deploy all games, not just changed ones |
| `--base` | Git ref to diff against (default: `origin/main`) |
| `--concurrency` | Max parallel deploys (default: 3) |
| `--output` | Write JSON results to a file |
| `--limit` | Max number of games to deploy |
| `--logs` | Show build/upload logs |
| `--publish` | Publish all deployed places |
| `--target` | Deploy target name (default: `test`) |

Change detection uses `pnpm ls --filter "...[base]"` to find packages (and their dependents) that changed since the base ref, then filters to those with a matching deploy target.

## Merging with an existing place (basePlace)

If your game has content built in Studio (terrain, UI, models) that lives in a team-create place, you don't want rojo to overwrite it. The `basePlace` config solves this — the CLI downloads the existing place, builds your code separately via rojo, and merges them together before uploading.

Add `basePlace` to your deploy target:

```json
{
  "targets": {
    "test": {
      "universeId": 12345,
      "placeId": 67890,
      "project": "default.project.json",
      "basePlace": {
        "universeId": 12345,
        "placeId": 11111
      }
    }
  }
}
```

The `basePlace` place is the source of truth for Studio-authored content. The target `placeId` is where the merged result gets uploaded. These can be in the same universe or different ones.

### How the merge works

The merge is driven by your rojo project file. Each entry in the tree is treated as one of two kinds:

- **Graft nodes** (has `$path` or `$className`) — the entire child is replaced with the rojo-built version. This is your code.
- **Navigation nodes** (no `$path` or `$className`) — the CLI traverses into the existing base service without replacing it. This preserves Studio content like terrain, workspace models, and UI.

This matches how `rojo serve` works: rojo owns the subtrees you point it at and leaves everything else untouched.

### Credential requirements

Downloading a base place uses the Roblox Asset Delivery API, which requires the `legacy-asset:manage` scope on your API key in addition to the standard `universe-places:write` scope. See [Credential resolution](testing.md#credential-resolution) for how the CLI finds your API key.

### Smoke testing

When `basePlace` is configured, the deploy pipeline automatically runs a smoke test after uploading. The smoke test spawns all `Script` instances in `ServerScriptService` and waits 30 seconds for errors. If any script throws, the deploy is marked as failed. No test assertions are needed — a clean boot is the test.

## CI integration

### Posting deploy results to a PR

After running `nevermore batch deploy --output results.json`, post the results as a PR comment:

```bash
nevermore tools post-deploy-results results.json --run-outcome success
```

This creates or updates a PR comment with a table showing each game's deploy status and a "Try it" link to the Roblox place. Requires `GITHUB_TOKEN` for PR comments. Job summaries are written automatically when `GITHUB_STEP_SUMMARY` is set.

### Automatic discovery

`nevermore batch deploy` discovers games the same way `nevermore batch test` discovers test packages — by scanning pnpm workspaces for `deploy.nevermore.json` files with the specified target. Any directory under `games/` (or anywhere in the workspace) with a valid config is picked up automatically.

## Luau template convention

Luau scripts that run in Roblox contexts (smoke tests, transforms, templates) should be stored as `.luau` files in `build-scripts/` directories — not generated inline from TypeScript. This keeps Luau code editable, lintable, and follows the pattern established by `studio-bridge/build-scripts/`.
