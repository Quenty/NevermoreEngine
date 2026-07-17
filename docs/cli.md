---
title: CLI Reference
sidebar_position: 4
---

import TOCInline from '@theme/TOCInline';

# The `nevermore` CLI

`nevermore` is the command-line tool that drives the Nevermore workflow: scaffolding new games and packages, installing dependencies, running tests, and deploying places to Roblox via the [Open Cloud API](https://create.roblox.com/docs/cloud). This page is the command reference. For the two deep workflows it links out to their own guides — [Deploying with the CLI](deploy.md) and [Test Infrastructure](testing/testing.md).

## Installing the CLI

You don't have to install anything to use it once — `npx` fetches and runs the latest version:

```bash
npx nevermore init
```

For day-to-day work, install it globally so `nevermore` is always on your `PATH`:

```bash
npm install -g @quenty/nevermore-cli
```

The CLI needs [Node.js](https://nodejs.org/en/download/) v18+. Most commands also expect the Luau toolchain (rojo, aftman) to be available — see [Install](install.md) for the full environment setup.

## Getting help

Every command and subcommand responds to `--help`, and the listing is generated from the CLI itself, so it never drifts from the installed version:

```bash
nevermore --help                # top-level commands
nevermore deploy --help         # a command and its subcommands
nevermore deploy init --help    # a specific subcommand's flags
nevermore --version             # installed version (and update check)
```

## Command overview

<TOCInline toc={toc.filter((node) => node.level === 3)} />

At a glance:

```
nevermore
├── init [name]              scaffold a game (default), package, or plugin
│   ├── game [name]
│   ├── package [name] [description] [template]
│   └── plugin [name]
├── install [packages..]     install @quenty/* packages from npm   (alias: i)
├── login                    store a Roblox Open Cloud API key
├── test                     test a single package
├── deploy [target]          build and upload a place
│   ├── init                 create deploy.nevermore.json
│   └── run [target]         deploy a target                        (default)
├── batch <subcommand>       run across many packages (change detection)
│   ├── test
│   └── deploy
└── tools <subcommand>       internal CI utilities
```

## Global options

These apply to every command:

| Flag | Description |
|------|-------------|
| `--yes` | Never prompt; fail instead of asking. Use in CI and scripts. |
| `--dryrun` | Describe what would happen without touching the file system or Roblox. |
| `--verbose` | Show intermediate output (building, uploading, credential loading). Also disables the live spinner in favor of plain, scrollable logs. |
| `--help` | Show help for the current command. |
| `--version` | Print the installed CLI version. |

### `nevermore init`

Scaffolds a new project from a template. The type is a subcommand; if you omit it, `init` scaffolds a **game**.

```bash
nevermore init                     # scaffold a game in the current directory
nevermore init MyGame              # same, named "MyGame" (game is the default)
nevermore init game MyGame         # explicit game
nevermore init package brio "Lifecycle-scoped values"
nevermore init plugin MyPlugin
```

| Subcommand | What it creates |
|------------|-----------------|
| `game [game-name]` | A working Nevermore game: `default.project.json`, server/client entry scripts, and the default packages (`loader`, `servicebag`, `binder`, `clienttranslator`, `cmdrservice`). |
| `package [package-name] [description] [package-template]` | A new package inside a monorepo. `package-template` is `library` (default) or `service`. |
| `plugin [plugin-name]` | A Roblox Studio plugin wired up with `loader` and `servicebag`. |

Notes:

- Positional arguments are optional. When omitted, the name defaults to the current directory (and, for `package`, `description` and the name fall back to an existing `package.json`). Run without arguments inside a package to fill in missing standard files.
- `game` and `plugin` also run the toolchain bootstrap after scaffolding: `pnpm install`, `git init`, `aftman install`, `npm run format`, and `selene generate-roblox-std`. Missing tools are reported but don't abort the scaffold.
- `--dryrun` previews the files that would be written.

:::note Back-compat aliases
`nevermore init-package` and `nevermore init-plugin` (hyphenated) still work as hidden back-compat aliases, but the subcommand forms `nevermore init package` and `nevermore init plugin` are canonical. Prefer them.
:::

### `nevermore install`

Installs one or more Nevermore packages from npm. Names are given **without** the `@quenty/` scope — the CLI adds it and validates each name against the published `@quenty/*` packages before installing. Alias: `i`.

```bash
nevermore install maid
nevermore install maid rx blend
nevermore i servicebag            # short alias
```

This is a convenience wrapper over `npm install @quenty/<name>`. Plain `npm install @quenty/maid` works identically if you prefer.

### `nevermore login`

Stores a Roblox Open Cloud API key so `test --cloud` and `deploy` can authenticate. Prompts interactively (masked input) unless you pass `--api-key`. The key is validated before it's saved to `~/.nevermore/credentials.json`.

```bash
nevermore login                   # prompt for a key, validate, and store it
nevermore login --api-key <key>   # non-interactive
nevermore login --status          # show what's loaded and re-validate it
nevermore login --force           # replace an existing key
nevermore login --clear           # remove the stored key
```

| Flag | Description |
|------|-------------|
| `--api-key <key>` | Provide the key directly instead of being prompted. |
| `--status` | Report the active credential source (flag, env var, or stored file) and validate it. |
| `--force` | Overwrite an existing key rather than reporting "already logged in". |
| `--clear` | Delete the stored credentials. |

Credentials can also come from the `ROBLOX_OPEN_CLOUD_API_KEY` environment variable (preferred in CI) — see [Deploying → Credentials](deploy.md) for the full resolution order.

### `nevermore test`

Runs the test target for the package in the current directory. Reads the `test` target from `deploy.nevermore.json`. Runs locally by default; pass `--cloud` to run through Open Cloud. See [Test Infrastructure](testing/testing.md) for the full guide.

```bash
nevermore test                                        # run locally
nevermore test --cloud                                # run via Open Cloud
nevermore test --cloud --logs                         # include execution logs
nevermore test --cloud --script-text 'print("hi")'    # run arbitrary Luau to debug
```

| Flag | Description |
|------|-------------|
| `--cloud` | Run via Open Cloud instead of locally. |
| `--api-key <key>` | Open Cloud API key (`--cloud` only). Otherwise resolved from login/env. |
| `--logs` | Show execution logs even on success. |
| `--universe-id <id>` / `--place-id <id>` | Override the IDs from `deploy.nevermore.json` (`--cloud` only). |
| `--script-template <path>` | Override the Luau script template to execute. |
| `--script-text <luau>` | Run the given Luau directly instead of the configured template. Handy for one-off debugging. |
| `--output <file>` | Write JSON results to a file. |
| `--timeout <seconds>` | Max execution time, sent to Open Cloud so Roblox cancels server-side on overrun (default: 120). |

### `nevermore deploy`

Builds a Rojo project and uploads it to a Roblox place. `run` is the default subcommand, so `nevermore deploy` and `nevermore deploy <target>` both deploy. Full walkthrough in [Deploying with the CLI](deploy.md).

```bash
nevermore deploy init                    # create deploy.nevermore.json (interactive)
nevermore deploy run                     # build + upload, saved (not live)
nevermore deploy run --publish           # build + upload and publish live
nevermore deploy production --publish    # 'run' is implied; deploy the 'production' target
nevermore deploy version upgrade         # re-pin base place versions to latest
```

**`nevermore deploy init`** — writes a `deploy.nevermore.json` for the current package.

| Flag | Description |
|------|-------------|
| `--universe-id <id>` / `--place-id <id>` | Roblox IDs to write into the config. |
| `--target <name>` | Deploy target name (auto-detects `test` or `integration` if omitted). |
| `--project <path>` | Rojo project file, relative to the package. |
| `--script-template <path>` | Luau script `nevermore test` will execute after upload. |
| `--create-place` | Auto-create a new place in the universe (uses cookie auth). |
| `--force` | Overwrite an existing `deploy.nevermore.json`. |

**`nevermore deploy run [target]`** — builds and uploads a target. Defaults to the only target if there's one, otherwise `test`.

| Flag | Description |
|------|-------------|
| `--publish` | Publish the place live. Without it, the upload is *Saved* (draft) only. |
| `--api-key <key>` | Open Cloud API key. Otherwise resolved from login/env. |
| `--universe-id <id>` / `--place-id <id>` | Override config IDs (single-place targets only). |
| `--place-file <path>` | Upload a pre-built `.rbxl` instead of building via rojo (single-place targets only). |
| `--output <file>` | Write JSON results to a file. |
| `--logs` | Show build/upload logs even on success. |

**`nevermore deploy version upgrade [target]`** — re-pins every `basePlace` in `deploy.nevermore.json` to its current latest published version, so deploys pull a fixed, git-tracked base place instead of whatever is live. Without a target it walks every target. See [Pinning base place versions](deploy.md#pinning-base-place-versions).

| Flag | Description |
|------|-------------|
| `--dryrun` | Print the old → new version table without writing. |
| `--yes` | Skip the confirmation prompt (for scripting/CI). |
| `--api-key <key>` | Open Cloud API key. Otherwise resolved from login/env. |

**`nevermore deploy version promote <from> <to>`** — copies base-place version pins from one target to another (e.g. promote validated `production-demo` pins to `production`). Places are matched by base place id, so content lines up even when the targets name their places differently. Pure config edit — no network. Supports `--dryrun` and `--yes`. See [Promoting pins between targets](deploy.md#promoting-pins-between-targets).

### `nevermore batch`

Runs `test` or `deploy` across many packages at once, using git change detection so PRs only touch what changed. Scans the pnpm workspace for packages with a matching deploy target. See [Test Infrastructure](testing/testing.md) and [Deploying](deploy.md) for how targets are configured.

```bash
nevermore batch test                       # test packages changed since origin/main
nevermore batch test --all                 # test every package with a test target
nevermore batch test --cloud --concurrency 3
nevermore batch deploy --all --publish     # deploy + publish everything
```

**`nevermore batch test`**

| Flag | Description |
|------|-------------|
| `--cloud` | Run via Open Cloud instead of locally. |
| `--all` | Test every package with a test target, not just changed ones. |
| `--base <ref>` | Git ref to diff against for change detection (default: `origin/main`). |
| `--concurrency <n>` | Max parallel tests (`0` = unlimited, the default). |
| `--aggregated` | Build all packages into a single place and run one batch script (default: **on**). |
| `--batch-place-id <id>` / `--batch-universe-id <id>` | Override IDs for the aggregated upload (`--aggregated` only). |
| `--limit <n>` | Cap the number of packages (local debugging). |
| `--logs` | Show execution logs for every package, not just failures. |
| `--output <file>` | Write JSON results to a file. |
| `--api-key <key>` | Open Cloud API key (`--cloud` only). |
| `--timeout <seconds>` | Max execution time for the whole batch, sent to Open Cloud (default: 300, the API max). |

**`nevermore batch deploy`**

| Flag | Description |
|------|-------------|
| `--target <name>` | Deploy target name in `deploy.nevermore.json` (default: `test`). |
| `--publish` | Publish the places live (default: Saved). |
| `--all` | Deploy every package with the target, not just changed ones. |
| `--base <ref>` | Git ref to diff against (default: `origin/main`). |
| `--concurrency <n>` | Max parallel deploys (default: 3). |
| `--smoke-test` | After deploying targets with a `basePlace`, run server scripts via Open Cloud and fail on boot errors. |
| `--limit <n>` | Cap the number of packages (debugging). |
| `--logs` | Show build/upload logs for every package. |
| `--output <file>` | Write JSON results to a file. |
| `--api-key <key>` | Open Cloud API key. |

### `nevermore tools`

Internal tooling and CI utilities. You rarely run these by hand — they're wired into GitHub Actions workflows — but they're documented here for completeness.

| Subcommand | Purpose |
|------------|---------|
| `post-test-results <input>` | Post test results as a PR comment (requires `GITHUB_TOKEN` and CI context). |
| `post-deploy-results <input>` | Post deploy results as a PR comment (requires `GITHUB_TOKEN` and CI context). |
| `post-lint-results <input>` | Parse linter output and emit GitHub Actions annotations (requires CI context). |
| `download-roblox-types [file-name]` | Download the Roblox Luau type definitions. |
| `strip-sourcemap-jest` | Remove Jest nodes from `sourcemap.json` to avoid luau-lsp name conflicts. |

## See also

- [Install](install.md) — Setting up Node, Rojo, the toolchain, and scaffolding your first project.
- [Deploying with the CLI](deploy.md) — The full `deploy` / `login` workflow, config schema, and credentials.
- [Test Infrastructure](testing/testing.md) — Configuring test targets, credentials, and CI.
- [TypeScript Conventions](conventions/typescript.md) — How the CLI itself is built (for contributors).
