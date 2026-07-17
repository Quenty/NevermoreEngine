---
title: Deploying with the CLI
sidebar_position: 3
---

# Deploying places with `nevermore deploy`

`nevermore deploy` builds a Rojo project, uploads it to a Roblox place via the [Open Cloud API](https://create.roblox.com/docs/cloud), and (optionally) publishes the new version so players see it. `nevermore test` is built on the same pipeline, so everything that runs in a Roblox place goes through this command.

This guide walks you from zero to your first uploaded place. For advanced features (merging with a Studio-authored base place, smoke tests, batch deploys, CI), see [Integration Testing](testing/integration-testing.md).

:::tip New to Nevermore?
Start with the [Intro](intro.md) for an overview and [Install](install.md) for setting up Node, Rojo, and the Nevermore CLI itself. This guide assumes the CLI is already on your `PATH`.
:::

## When should I use this?

For most Roblox projects, especially solo work and small teams, you don't need this. Open Roblox Studio, click **Save to Roblox** or **Publish to Roblox**, and you're done. That's normally the right answer.

You probably want `nevermore deploy` when:

- Your code lives in a git repository and Studio is just where you preview it. Deploys should come from the same commit history that reviews and tests run against, not from whichever developer's Studio happens to be open.
- More than one programmer ships to the same place. Studio's publish flow is last-writer-wins, and a CLI deploy from CI gives you one path from "merge to main" to "live in game", traceable to a specific commit.
- You want one config to drive both tests and deploys. `nevermore deploy` and `nevermore test` both read `deploy.nevermore.json`, so the place you smoke-test against on every PR is configured exactly like the one you ship to. See [Test Infrastructure](testing/testing.md).
- You want CI to gate releases. Batch deploys plug into PR checks, so a deploy only runs after lint, tests, and smoke tests pass, and shows up as a PR comment instead of an ad-hoc Studio session.

If none of those apply, stick with Studio Publish. Come back when you outgrow it.

## What deploy actually does

When you run `nevermore deploy run`:

1. Reads `deploy.nevermore.json` in your current directory and resolves the target you asked for (default: `test`).
2. Runs `rojo build` on the target's `project` file to produce an `.rbxl` place file in a temp directory.
3. Injects deploy metadata (commit, target, timestamp, place/universe IDs) into the built place if it includes the [`nevermore-cli-manifest`](#reading-deploy-metadata-at-runtime) package.
4. Uploads the `.rbxl` to the configured `universeId` / `placeId` over Open Cloud.
5. Saves the new version as a draft. If `--publish` is passed, it is also published as the live version.

That's the whole pipeline. There are no deploy hooks or post-processing steps to register.

## Prerequisites

- [Node.js](https://nodejs.org/) v18+ and the Nevermore CLI installed. The [Install guide](install.md) walks through both. The short version is `npm install -g @quenty/nevermore-cli`, or use `npx nevermore ...` from any package that depends on it.
- [Rojo](https://rojo.space/docs/v7/getting-started/installation/) v7+ on your `PATH`.
- A Roblox universe and place you own. You can create both at [create.roblox.com/dashboard/creations](https://create.roblox.com/dashboard/creations).
- A Roblox Open Cloud API key. See [Logging in](#logging-in) below.

## Logging in

`nevermore deploy` authenticates against Open Cloud with an API key. Create one at [create.roblox.com/dashboard/credentials](https://create.roblox.com/dashboard/credentials) and grant it these scopes for the universe you want to deploy to:

| Scope | Used for |
|-------|----------|
| `universe-places:write` | Uploading new place versions |
| `universe.place.luau-execution-session:write` | Running scripts (used by `nevermore test` and smoke tests) |
| `universe.place.luau-execution-session:read` | Reading script execution results |
| `legacy-asset:manage` | Downloading a [base place](testing/integration-testing.md#merging-with-an-existing-place-baseplace) (only needed if you use `basePlace`) |

Save the key to your machine once:

```bash
nevermore login
```

This stores the key at `~/.nevermore/credentials.json` (mode `0700`) after validating it against Open Cloud. Other useful flags:

- `nevermore login --force` swaps the stored key.
- `nevermore login --clear` removes it.
- `nevermore login --status` shows what's loaded and re-validates it.

### How the CLI finds your key

The CLI resolves credentials in this order (first match wins):

1. The `--api-key` CLI flag
2. The `ROBLOX_OPEN_CLOUD_API_KEY` environment variable
3. The `ROBLOX_UNIT_TEST_API_KEY` environment variable (kept for backwards compatibility)
4. `~/.nevermore/credentials.json` (from `nevermore login`)

In CI, set `ROBLOX_OPEN_CLOUD_API_KEY` as a secret. `nevermore login` is for local developer machines.

## Setting up a package for deploy

`deploy.nevermore.json` is the only file the CLI needs to know about. The fastest way to create one is the interactive `init` wizard.

### `nevermore deploy init`

From inside the directory you want to deploy from (a package under `src/`, a game under `games/`, or any directory with a `package.json`):

```bash
nevermore deploy init
```

The wizard:

- Detects a `test/default.project.json` if one exists and offers it as the default Rojo project.
- Detects `test/scripts/Server/ServerMain.server.lua` (or `.luau`) and offers it as the default script template.
- Walks up the filesystem looking for a parent `deploy.nevermore.json` with a `universeId` and reuses it. Once you have one game configured, sibling packages can inherit the universe automatically.
- Lists every existing place in the universe so you can pick one, or offers to create a new place.
- Prints the resulting config and asks you to confirm before writing it.

#### Non-interactive setup

Pass `--yes` to skip prompts. You must supply enough flags for the wizard to resolve everything without asking:

```bash
nevermore deploy init --yes \
  --universe-id 12345 \
  --place-id 67890 \
  --project default.project.json \
  --target test
```

If you have the universe but no place yet, use `--create-place` to create one. Place creation is not exposed in Open Cloud, so this uses your `.ROBLOSECURITY` cookie instead. It only works on a machine that's logged in to Roblox.

```bash
nevermore deploy init --yes \
  --universe-id 12345 \
  --create-place \
  --project default.project.json
```

Other flags:

| Flag | Description |
|------|-------------|
| `--target <name>` | Name of the target to create (default: `test`) |
| `--script-template <path>` | Set the Luau script template that `nevermore test` will run |
| `--force` | Overwrite an existing `deploy.nevermore.json` |

### The `deploy.nevermore.json` schema

```json
{
  "targets": {
    "test": {
      "universeId": 12345,
      "placeId": 67890,
      "project": "default.project.json",
      "scriptTemplate": "test/scripts/Server/ServerMain.server.lua",
      "basePlace": {
        "universeId": 12345,
        "placeId": 11111
      }
    }
  }
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `targets` | yes | Map of target name to deploy config. Most packages start with a single `test` target. |
| `targets.<name>.universeId` | yes | Roblox universe ID to deploy into. |
| `targets.<name>.placeId` | yes | Roblox place ID. The build is uploaded here as a new version. |
| `targets.<name>.project` | yes | Path to the Rojo project file, relative to the package directory. |
| `targets.<name>.scriptTemplate` | no | Luau file `nevermore test` executes via Open Cloud after upload. Not used by `nevermore deploy` itself. |
| `targets.<name>.basePlace` | no | Universe/place to download and merge with the rojo build before uploading. See [Merging with an existing place](testing/integration-testing.md#merging-with-an-existing-place-baseplace). |
| `targets.<name>.basePlace.version` | no | Pin the base place to a specific published version instead of pulling the latest. See [Pinning base place versions](#pinning-base-place-versions). |

You can declare any number of targets. A common setup is one `test` target for CI and a separate `production` or `staging` target for live deploys:

```json
{
  "targets": {
    "test":       { "universeId": 1, "placeId": 10, "project": "test/default.project.json" },
    "production": { "universeId": 1, "placeId": 20, "project": "default.project.json" }
  }
}
```

## Running a deploy

From the directory containing `deploy.nevermore.json`:

```bash
# Build + upload to the default "test" target as a saved (draft) version
nevermore deploy run

# Same, but publish so the new version is live for players
nevermore deploy run --publish

# Deploy a specific target
nevermore deploy run production --publish
```

`nevermore deploy run` and the bare `nevermore deploy <target>` form are equivalent. `run` is the default subcommand.

On success you'll see one of:

```
Saved v42 — not yet live.
Published v42 — live in game.
```

A "saved" version is uploaded but not visible to players. You can publish it later from the Roblox dashboard, or re-run with `--publish` to publish a fresh build. That version number matches what you'll see on the place page.

### Run flags

| Flag | Description |
|------|-------------|
| `--publish` | Publish the new version (default: save only) |
| `--api-key <key>` | Open Cloud API key (overrides credential lookup) |
| `--universe-id <id>` | Override the target's `universeId` |
| `--place-id <id>` | Override the target's `placeId` |
| `--place-file <path>` | Skip the rojo build and upload an existing `.rbxl` instead |
| `--output <path>` | Write a JSON record of the deploy result to this path |

Global flags (available on every `nevermore` command):

| Flag | Description |
|------|-------------|
| `--yes` | Non-interactive (fails fast instead of prompting) |
| `--dryrun` | Print what would happen without doing it |
| `--verbose` | Verbose logging (rojo output, upload details) |

### Overriding the configured place

`--universe-id` and `--place-id` let you redirect a single deploy without editing the config. This is useful when you want to push the same build to a personal staging place for a one-off test:

```bash
nevermore deploy run --universe-id 999 --place-id 8888
```

### Uploading a pre-built place

If you already have a `.rbxl` (for example, one produced by `rojo build` in an upstream CI step), skip the rebuild:

```bash
nevermore deploy run --place-file ./build/my-place.rbxl
```

The `project` field in `deploy.nevermore.json` is ignored when `--place-file` is set, but `universeId` and `placeId` are still required.

## Pinning base place versions

If a target uses a [`basePlace`](testing/integration-testing.md#merging-with-an-existing-place-baseplace), `nevermore deploy` downloads that place and merges your rojo build into it. By default it pulls **the latest published version** of the base place — so a broken Studio edit to the base place ships on the very next deploy, even when your code hasn't changed.

To make deploys reproducible, pin the base place to a specific version with an optional `version` field:

```json
{
  "targets": {
    "production": {
      "universeId": 12345,
      "placeId": 67890,
      "project": "default.project.json",
      "basePlace": {
        "universeId": 12345,
        "placeId": 11111,
        "version": 42
      }
    }
  }
}
```

With `version` set, the deploy downloads exactly that version of the base place. Omit it to keep pulling the latest (the previous behaviour — nothing changes for configs that don't opt in).

### Bumping the pin

When you actually want to roll base places forward, run:

```bash
# Re-pin every basePlace in the config to its current latest published version
nevermore deploy version upgrade

# Only upgrade one target
nevermore deploy version upgrade production

# Preview the change set without writing
nevermore deploy version upgrade --dryrun
```

`upgrade` walks every `basePlace` in `deploy.nevermore.json` (or just the named target), resolves each place's current latest published version, prints an old → new table, and — after a confirmation prompt — writes the new `version` values back into the file. Base places shared by several targets are resolved once. Pass `--yes` to skip the prompt (for scripting), or `--dryrun` to preview only.

Commit the updated `deploy.nevermore.json`, then deploy as usual. This gives you a reviewable, git-tracked record of exactly which base-place content each deploy shipped.

Resolving the latest version uses the same `legacy-asset:manage` scope already required for `basePlace` downloads, so no extra credentials are needed.

### Promoting pins between targets

Once you've validated a target — say a `production-demo` universe — you usually want to ship those exact same base-place versions to `production`, not re-pin to whatever is newest. `promote` copies the pins across:

```bash
# Copy every base place pin from production-demo onto production
nevermore deploy version promote production-demo production

# Preview without writing
nevermore deploy version promote production-demo production --dryrun
```

Places are matched by **base place id**, not by name, so the same source content lines up even when the two targets name their places differently (e.g. a demo `chapter6` and a prod `chapter8` that share one base place). Places in the destination with no matching pin in the source are left untouched and reported. This is a pure edit of `deploy.nevermore.json` — no network calls — so it's safe to run offline and review as a diff.

## Batch deploys

If you want to deploy every game affected by a code change (for example, on every PR), use `nevermore batch deploy` instead. It scans the pnpm workspace for packages with a matching deploy target, uses `pnpm ls --filter` to figure out which ones changed since `origin/main`, and runs them in parallel.

See [Integration Testing → Batch deploy](testing/integration-testing.md#batch-deploy) for the full flag list and CI usage.

## Reading deploy metadata at runtime

`nevermore deploy` and `nevermore batch deploy` can stamp each build with the deployment that produced it — which commit, which target, when, and whether it was published — so the running game can report its own provenance. This is opt-in by package: a place only gets stamped if it depends on the [`nevermore-cli-manifest`](https://github.com/Quenty/NevermoreEngine/tree/main/src/nevermore-cli-manifest) package.

That package ships a `NevermoreCLIManifestUtils` ModuleScript. Between the rojo build and the upload, the CLI finds that module in the built place and writes the metadata onto it as attributes (via a Lune transform, the same way `basePlace` merges work). Because the data lives on the package's own instance, it replicates to clients automatically. If the module isn't present, the deploy proceeds unchanged.

`nevermore test` and `nevermore batch test` apply the same stamp — but only for packages that ship or directly depend on `nevermore-cli-manifest`, so unrelated packages don't pay for a Lune pass. This is what lets that package's own spec assert the injection actually ran (`getGameMetadata().deployed` is `true`, with a real commit and the `test` target) rather than checking a synthetic fixture. Note the consequence: for those packages, `deployed` is `true` during a test run too, since the test place really was built and uploaded by the CLI.

Read it from either the client or the server:

```lua
local NevermoreCLIManifestUtils = require("NevermoreCLIManifestUtils")

local metadata = NevermoreCLIManifestUtils.getGameMetadata()
if metadata.deployed then
	print(string.format("%s @ %s (%s)", metadata.target, metadata.commit, metadata.timestamp))
else
	print("Undeployed build (Studio)")
end
```

`metadata.deployed` is the source of truth for "is this a real deploy?" — it's only ever `true` when the CLI injected it, so it stays `false` in Studio and in any place that wasn't deployed through the CLI. The full field list (`commit`, `version`, `branch`, `target`, `timestamp`, `published`, `placeId`, `universeId`) is documented in the [package README](https://github.com/Quenty/NevermoreEngine/tree/main/src/nevermore-cli-manifest). Consumers like `GameConfig`, `GameVersionUtils`, and PlayerMetrics read from this module rather than reaching for the raw attributes.

The attribute names the CLI writes (`Commit`, `Version`, `Target`, …) live in two places that must agree: `buildDeployMetadataAttributes` in `tools/nevermore-cli/src/utils/deploy/deploy-metadata.ts` (the write side) and the `ATTRIBUTE` table in `NevermoreCLIManifestUtils.lua` (the read side). The Lune transform itself is generic — it writes whatever keys it's handed — so adding a field is just those two edits. Note place/universe IDs are written as strings on purpose (Lune serializes number attributes as float32, which corrupts large IDs); the reader converts them back with `tonumber`.

## Common workflows

### First-time setup for a new game

If you're starting from a clean directory, [`nevermore init`](install.md#fast-track-installing-via-npm-and-the-nevermore-cli-recommended) scaffolds a working Nevermore game template: a `default.project.json`, server/client entry scripts, and the default packages (`loader`, `servicebag`, `binder`, etc.). After that, `nevermore deploy init` only needs your universe and place IDs.

```bash
mkdir my-game && cd my-game
nevermore init                                 # scaffold a Nevermore game template
nevermore deploy init                          # configure the deploy target (interactive)
nevermore deploy run                           # first upload, draft only
nevermore deploy run --publish                 # publish when ready
```

The wizard auto-detects the project file `nevermore init` creates, so you only answer prompts for universe and place. See [Install](install.md) for the full breakdown of what `nevermore init` produces, and [Integration Testing → Setting up a new integration game](testing/integration-testing.md#setting-up-a-new-integration-game) if you're building a game inside the Nevermore/Raven monorepo instead.

### Promoting a tested build to production

If you have separate `test` and `production` targets, the common pattern is to run the test target on every PR and only deploy production from `main`:

```bash
# In CI on main
nevermore deploy run production --publish
```

There is no separate "promote" command. You deploy the same code to whichever target you want.

### Debugging a failed deploy

- Pass `--verbose` to see the rojo build output and the raw Open Cloud responses.
- Pass `--dryrun` to confirm which target, universe, place, and project the CLI would use without uploading anything.
- Check `nevermore login --status` if you suspect a credential problem.
- Place uploads can fail with HTTP 403 when the API key is missing the `universe-places:write` scope for that specific universe. The scope is granted per-universe, not globally.

## See also

- [Intro](intro.md) — Why Nevermore, the major packages, and how the library is organized.
- [Install](install.md) — Setting up Node, Rojo, the Nevermore CLI, and scaffolding a project with `nevermore init`.
- [Integration Testing](testing/integration-testing.md) — `basePlace` merging, smoke tests, batch deploys, CI integration.
- [Test Infrastructure](testing/testing.md) — How `nevermore test` reuses the deploy config to run Jest specs in Open Cloud.
