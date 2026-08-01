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
| `targets.<name>.basePlace.version` | no | Pin the base place to an exact version number, or track its newest `"published"` / `"saved"` version, instead of pulling the latest. See [Pinning base place versions](#pinning-base-place-versions). |
| `targets.<name>.watch` | no | Repo-relative path to the GitHub workflow that rebuilds this place, e.g. `.github/workflows/build.yml`. Makes the place eligible for `--watch`. See [Rebuilding when the base place changes](#rebuilding-when-the-base-place-changes). |

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
| `--watch <url>` | After a successful deploy, register a watch so this target rebuilds when its base place changes. Takes the register endpoint URL, ending in the lease. See [Rebuilding when the base place changes](#rebuilding-when-the-base-place-changes). |

Global flags (available on every `nevermore` command):

| Flag | Description |
|------|-------------|
| `--yes` | Non-interactive (fails fast instead of prompting) |
| `--dryrun` | Print what would happen without doing it |
| `--verbose` | Verbose logging (rojo output, upload details) |
| `--frozen-lockfile` | Fail instead of resolving a base place version the lock file does not already pin |
| `--refresh-base-place` | Re-resolve `"saved"`/`"published"` pins instead of reusing the locked version |

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

With `version` set to a number, the deploy downloads exactly that version of the base place.

Omitting it no longer means "always latest". The first deploy resolves the base place's published head and records it in the [lock file](#the-lock-file); every later deploy reuses that until you roll it forward. This is deliberate — it's what makes a config that never opted into pinning reproducible anyway — but it does mean an existing config stops silently following the base place the first time you deploy with this version of the CLI. To keep following it, say so explicitly with `"saved"` or `"published"` below and re-run `nevermore deploy version upgrade` when you want it to move.

### Tracking a version type instead of a number

A number holds the base place still. Sometimes you want the opposite: follow the base place as Studio moves it, but be precise about *which* movement counts. `version` also accepts two keywords:

| Value | Resolves to |
|-------|-------------|
| `"published"` | The newest version of the base place that has been **published live**. Studio saves are ignored until someone publishes. |
| `"saved"` | The newest version of any kind, including a **Studio save that was never published**. |

```json
{
  "basePlace": {
    "universeId": 12345,
    "placeId": 11111,
    "version": "published"
  }
}
```

`"published"` is the useful default for a shared base place: the team can save work-in-progress in Studio all day without it leaking into a deploy, and publishing the base place is the deliberate act that ships it. `"saved"` is for a Team Create place where saving *is* how content is handed off, and nobody publishes the base place at all.

One caveat if you also want [`--watch`](#rebuilding-when-the-base-place-changes): the watch service can only see `"saved"` versions when you share an Open Cloud key, so without `--watch-share-api-key` a place tracking it deploys normally but is left out of watch registration.

A keyword says which end of the base place's history to follow — not that it is re-checked on every build. The first deploy resolves it against the place's version history (newest-first, so it stays cheap even on a place with tens of thousands of versions) and writes the answer to the [lock file](#the-lock-file); later deploys reuse that, with no network call, until `nevermore deploy version upgrade` moves it. That is what keeps a keyword pin reproducible: the keyword is the intent, the lock is the fact.

The practical difference between a keyword and a number, then, is which one `upgrade` rolls forward and which file records it — not whether the deploy is deterministic. Both are.

These are the same words the Open Cloud place-publishing API uses for `versionType` when *uploading*, so a config reads the same in both directions. Anything else — `"latest"`, `"live"` — is rejected when the config loads rather than at deploy time.

## The lock file

`deploy.nevermore.json` says what you want; `deploy.nevermore.lock.json` records what that turned out to be. It sits beside the config, and **you commit it**.

```json
{
  "lockfileVersion": 1,
  "basePlaces": {
    "11111": { "version": 158, "from": "published" }
  }
}
```

Without it, a commit doesn't fully describe its own deploy: two builds of the same code can merge against different base-place content, and nothing in git says so. That's the same reason `package-lock.json` exists.

The CLI writes it for you. On a deploy, every base place that isn't pinned to an exact number is resolved and recorded; on later deploys the recorded version is used directly, with **no network call**, until you deliberately roll it forward. Entries are keyed by base place id, so one entry covers a base place shared by several targets, and multi-place targets need nothing special.

Three things it deliberately does not have: timestamps (git already records when an entry changed, and ties it to an author and a commit), entries for numeric pins (those are already exact, and a second copy is a second thing to edit), and content hashes (a Roblox place version is immutable, so there's nothing to verify).

The `from` field is what makes the lock notice you changed your mind: flip a config from `"published"` to `"saved"` and the stale entry is discarded rather than silently re-served.

### Freezing it in CI

`--frozen-lockfile` makes the CLI refuse to resolve anything the lock doesn't already answer, so a base place that moved fails the build instead of shipping:

```bash
nevermore deploy run production --frozen-lockfile
```

It's **off by default, including in CI** — a repo that hasn't committed a lock file yet shouldn't start failing. Turn it on in your workflow once the lock is committed. It applies to `deploy run`, `batch deploy`, `test`, and `batch test --no-aggregated`.

`nevermore batch test` in its default aggregated mode is the exception: it combines every package into one place, so there is no per-package place to merge a base place into and none is downloaded. Packages configured with a `basePlace` are named in a warning at the start of the run, since their Studio-authored content is not present in that place. Test those with `--no-aggregated`, or through an integration deploy.

### When it conflicts

The lock is regenerable. Take either side of the conflict, then run `nevermore deploy version upgrade` and commit the result. A lock file that fails to parse is reported as an error rather than silently rewritten, precisely so a bad merge can't quietly drop whatever the other side pinned.

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

`upgrade` walks every `basePlace` in `deploy.nevermore.json` (or just the named target), resolves each place's newest version, prints an old → new table, and — after a confirmation prompt — writes the result. Base places shared by several targets are resolved once. Pass `--yes` to skip the prompt (for scripting), or `--dryrun` to preview only.

Which file it writes depends on how the base place is pinned:

| Pin | `upgrade` writes | Resolved against |
|-----|------------------|------------------|
| a number, or no `version` at all | `deploy.nevermore.json` | latest **published** |
| `"published"` / `"saved"` | `deploy.nevermore.lock.json` | whichever type it tracks |

That split is the point: a keyword pin says "follow this place," so `upgrade` moves the recorded fact without overwriting the intent. A numeric pin says "hold still," so `upgrade` is the deliberate act that moves it. Run unscoped (no target), `upgrade` also drops lock entries for base places the config no longer references.

Commit the updated files, then deploy as usual. This gives you a reviewable, git-tracked record of exactly which base-place content each deploy shipped.

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

## Rebuilding when the base place changes

Pinning solves one problem and creates another. A pinned base place can't ship a broken Studio edit — but it also can't ship a *good* one. Someone dresses a set in Studio, publishes, and nothing happens until a human remembers to run `deploy version upgrade` and push. For a place whose content genuinely lives in Studio, that lag is the whole cost of pinning.

A **watch** closes that loop. After a successful deploy, the CLI registers with a watch service: "this place was built from base place 20 at published v158 — when that moves, dispatch this workflow." The workflow rebuilds and redeploys.

Leases are renewed by the ordinary builds — every scheduled or pushed build re-registers, which extends the lease. The watch-triggered build itself doesn't need to.

### Setting one up

The place needs two things. `watch` names the workflow to dispatch, and `basePlace.version` must track a keyword rather than a number:

```json
{
  "targets": {
    "integration": {
      "places": [
        {
          "name": "hub",
          "universeId": 9411354417,
          "placeId": 130026093497279,
          "project": "default.project.json",
          "basePlace": {
            "universeId": 10595136593,
            "placeId": 140328750749206,
            "version": "published"
          },
          "watch": ".github/workflows/build.yml"
        }
      ]
    }
  }
}
```

An exact `basePlace.version` is skipped rather than watched — a number means "hold this still", which is the opposite of what a watch is for. A place with no `basePlace` is skipped too: there's nothing to watch for.

Then register on deploy:

```bash
# Register a 7-day watch with the default service
nevermore batch deploy --watch https://watch.example.com/v1/register/7d

# Or point at a specific service / your own deployment
nevermore deploy run --watch https://watch.example.com/v1/register/7d/
```

**Nevermore ships no watch endpoint.** A watch service is deployment-specific infrastructure and this is a public repo, so the whole address comes from you — `--watch` takes the register endpoint URL, with the lease as its last path segment:

```bash
nevermore batch deploy --watch https://watch.example.com/v1/register/7d
```

In CI, keep the host in a secret and interpolate it into the argument, alongside the dispatch token. A value that is not a URL, or a URL not ending in a lease, is refused before the deploy runs rather than after it has shipped.

### Locally, `--watch` rebuilds here instead

`--watch` means different things in CI and on your machine. A workflow dispatch would rebuild on a runner, which is not where you are looking, so a local run keeps the rebuild in the terminal.

| Where | What `--watch` does |
|-------|--------------------|
| CI (`$CI` set) | Registers a watch that dispatches your workflow when a base place moves. |
| Locally | Registers a watch that **notifies this process**, holds the connection open, and **rebuilds in place** when a base place moves — until you Ctrl-C. |

```bash
nevermore deploy run integration --watch https://watch.example.com/v1/register/2h
```

```
Saved v43 — not yet live.
Watching 2 base places locally. Ctrl-C to stop.
  integration.places.hub — base place 140328750749206 (published v158)
  integration.places.lobby — base place 140328750749207 (saved v42)
integration.places.hub: base place moved v158 → v159, rebuilding...
integration.places.hub: rebuilt from v159.
```

Local watching is deliberately more permissive than the cloud path. A place does **not** need a `watch` field — that names a workflow to dispatch, and nothing is dispatched locally — and `"saved"` works, because your machine has the Open Cloud credentials the service doesn't. An exact version pin is still skipped: it means "hold this still".

Rebuilds re-resolve the pin automatically, so you don't need `--refresh-base-place` locally. A failed rebuild is retried rather than skipped, and losing the connection or failing to reach Open Cloud is reported without ending the watch.

**Pick a short lease locally.** Holding the connection keeps the watch alive, so the lease is only how long it outlives a dropped link — not how long you get to work. a lease of `30m` and then leaving the terminal open all day is the intended shape: the watch lapses shortly after you close it, instead of being polled for a week.

#### A private base place needs `--watch-share-api-key`

How the service observes a place depends on whether you share an Open Cloud key, and that decides
three things at once:

| | Without a key | With `--watch-share-api-key` |
|---|---|---|
| How it reads | Roblox asset delivery, anonymously | Place version history, as you |
| Private base place | `401`, never fires | Readable |
| `basePlace.version: "saved"` | Refused at registration | Watchable |
| Versions written in | A content hash | The same place version your lock holds |

Without a key, a private base place shows up as a `poll-failed` event on the monitor rather than a
registration error — nothing is wrong with the config, the service simply cannot see the place. The
CLI notices and falls back to watching from here, since your machine has credentials the service
doesn't.

The last row is the one with a non-obvious consequence. Reading anonymously, the service's versions
are content hashes and your lock file's are place versions, so no baseline can be sent — the first
poll adopts whatever is current. That is fine for a place that just deployed, but it means a place
that *didn't* deploy this run silently forgets a change that already happened. Share a key and the
two sides speak the same language, so `batch deploy --watch` sends each package's locked version and
the service notices what it missed.

The key is stored by the service, encrypted, and only ever used to read version history. It is off
by default.

#### Giving it a GitHub token

Set `NEVERMORE_WATCH_TOKEN` (or `GITHUB_TOKEN`), or pass `--watch-use-gh-auth` to use the token
`gh` is already holding:

```bash
nevermore deploy run integration   --watch https://watch.example.com/v1/register/30m   --watch-use-gh-auth
```

Reading `gh` is opt-in rather than automatic, and deliberately so. Registering sends the token to
the watch service and creates a monitor against your repository, so it should be a credential you
handed over — setting an environment variable is handing it over, reading whatever `gh` happens to
be logged into is not. Almost every developer machine has a logged-in `gh`, so defaulting it on
would turn a command that watches locally into one that quietly ships a token.

#### When it polls instead

Streaming needs a watch service and a GitHub identity to register under. When either is missing, `--watch` falls back to polling Open Cloud directly from here — slower to notice a change and it spends your own quota, but it works with no service at all. It says which mode you got, and why, whenever it is not the streaming one.

It falls back when:

- the service refuses the registration, or cannot be reached;
- there is no GitHub token, or the checkout has no GitHub remote — registering needs a write-scoped PAT even though a notify never spends it, because the repository is the only identity the service has;
- any watched place tracks `"saved"` and no key is shared. The whole run falls back rather than splitting, so two loops can't disagree about what's current.

### Testing a watch with `--dryrun`

`--dryrun` skips the build and upload but **registers the watch for real and fires it**. Neither touches the deploy — registration is idempotent and derives entirely from committed config plus the lock file, and firing just asks the service to dispatch now. That makes it the way to prove routing works end to end without shipping a build:

```bash
nevermore deploy run integration --dryrun --watch https://watch.example.com/v1/register/7d
```

```
[DRYRUN] Would build and upload
[DRYRUN] Registering the watch and firing it, to prove routing works. Neither touches the deploy.
Registered watch monitor "@quenty/egg-hunt-hub/integration/main" — 1 watch, lease 7d
Forced a dispatch: 1 of 1 watch fired.
  quenty/egg-hunt-hub/hub: dispatched
```

Note that firing really does start a workflow run — that is the point, since it's what proves the selector reaches `deploy run` intact.

This surfaces the things easy to get wrong — a missing `watch` path, a pinned or `"saved"` base place, a bad token, a workflow that doesn't exist on the ref — before a real deploy depends on them. Add `--verbose` to also list places that never asked to be watched. A registration failure exits non-zero even on a dryrun.

Either way the lease must be the URL's last path segment, because that's where the API takes it. A URL without one is rejected before the deploy runs rather than after it has shipped.

### The workflow on the other end

The dispatch passes the place's **selector** as a `target` input — `integration.places.hub`, which reads as the path into the config it is. Your workflow hands it back to `deploy run`:

```yaml
on:
  workflow_dispatch:
    inputs:
      target:
        description: Deploy target selector, e.g. integration.places.hub
        type: string
  push:
  schedule: [{ cron: '0 9 * * 1' }]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      # ... checkout, install, auth ...

      # Watch-triggered: rebuild exactly the place whose base place moved.
      - if: inputs.target != ''
        run: nevermore deploy run ${{ inputs.target }} --publish --refresh-base-place

      # Otherwise: a normal build, which also renews every watch lease.
      - if: inputs.target == ''
        run: nevermore batch deploy --publish --watch ${{ secrets.NEVERMORE_WATCH_REGISTER_URL }}/7d
        env:
          NEVERMORE_WATCH_TOKEN: ${{ secrets.NEVERMORE_WATCH_TOKEN }}
```

The endpoint comes from a secret because it is your infrastructure, not because
the CLI reads one — `--watch` takes it as an argument, so a secret is simply the
tidiest place to keep the host out of a public workflow file.

`--refresh-base-place` is not optional here, and it is the part that's easy to get wrong. The lock file holds a `"published"` pin still until something moves it — that's what makes builds reproducible. A watch-triggered build would therefore download the version it was *already* locked to, republish a byte-identical place, and the hot reload would silently do nothing. `--refresh-base-place` re-resolves the pin and writes the new version back to the lock, so the build picks up the edit that triggered it. (It's rejected alongside `--frozen-lockfile`, which asks for the opposite.)

Because the non-dispatch path re-registers with `--watch`, every scheduled or pushed build renews the lease. A project that builds weekly never lets a 7-day watch lapse.

### Known gap: the refreshed lock has to get committed

`--refresh-base-place` writes the new version into `deploy.nevermore.lock.json` — on the runner. **Nothing commits it yet**, and that leaves the loop open:

1. Studio publishes v101 → the watch dispatches → the build ships v101 and writes the lock on the runner, which is then discarded.
2. The next scheduled or pushed build runs *without* `--refresh-base-place`, reads the committed lock (still v100), and republishes the **old** base place — reverting the hot reload.
3. It re-registers with a v100 baseline against a v101 source, so the service sees drift and dispatches again.

The CLI warns when `--refresh-base-place` moves a lock file, so this is loud rather than silent, but the fix is not automated. Until it is, a watch-triggered build needs to commit the lock back itself:

```yaml
      - if: inputs.target != ''
        run: |
          nevermore deploy run ${{ inputs.target }} --publish --refresh-base-place
          git add deploy.nevermore.lock.json
          git diff --cached --quiet || git commit -m "chore: roll base place [skip ci]"
          git push
```

`[skip ci]` matters: the workflow triggers on `push`, so a commit without it re-enters the build.

The intended end state is for this to be automatic — commit the lock with `[skip ci]`, bump the package version, and cut a release — but that belongs outside `nevermore deploy` and is not implemented. Treat the snippet above as the stopgap.

### Selecting one place of a target

`integration.places.hub` works anywhere a target name does, including `nevermore deploy run` and `--target`. It's how a single-place command addresses one place of a multi-place target, which it otherwise refuses:

```bash
nevermore deploy run integration.places.hub   # just the hub
nevermore deploy run integration              # all of integration's places, in parallel
```

`nevermore test` is the command that refuses a multi-place target outright, since running one test place out of several isn't meaningful. `deploy run` fans out instead.

Narrowing changes which places *deploy*, not which places are *watched*: `--watch` always registers the whole target, because the monitor is named for it and re-registering replaces its list. Deploying one place therefore can't drop its siblings' watches — they keep the baseline recorded in the lock file.

### Monitors, and what a re-registration replaces

The service stores a **monitor**: a named set of watches belonging to one repository. Registering is idempotent on `(repository, name)` and **replaces that monitor's entire watch list**, which is what makes a scheduled heartbeat cheap — but also means a registration has to carry every watch its name owns, not just the ones that happened to deploy.

That drives the one behavior here worth knowing:

| Command | Monitor name | Watches registered |
|---------|--------------|--------------------|
| `nevermore deploy run --watch` | `<package>/<target>/<ref>` | Every place in that target |
| `nevermore batch deploy --watch` | `<target>/<ref>` | **Every** package with that target |

The git ref is part of the monitor name because it's part of what the monitor *does* — every dispatch runs at the ref it was registered from. Without it in the name, a `batch deploy --watch` from a feature branch would re-point the production monitor's entire watch list at that branch. Registering from a pull request's merge ref (`42/merge`) is refused outright: that ref exists only for the check run and can't be dispatched against.

`batch deploy` normally only deploys *changed* packages, but it registers watches for **all** of them. Registering only the changed ones would delete every unchanged package's watch on the next run. Packages that didn't deploy still have a lock file entry, and that entry is exactly the right `baselineVersion` for them.

Each invocation makes one call. The response reports `changed: false` when the config was identical to what was stored, so a renewal that changes nothing is distinguishable from a real edit:

```
Registered watch monitor "integration" — 3 watches, lease 7d (expires 2026-08-06T00:00:00Z)
Renewed watch monitor "integration" — 3 watches, lease 7d (expires 2026-08-13T00:00:00Z)
```

### Credentials

Two environment variables drive this, both suited to CI secrets:

| Variable | Purpose |
|----------|---------|
| `NEVERMORE_WATCH_TOKEN` | GitHub token the service dispatches with. |

The service dispatches the workflow as you, so it needs a token with `actions: write` on the repository — there are no service accounts, the token is the identity. The CLI reads `NEVERMORE_WATCH_TOKEN`, falling back to `GITHUB_TOKEN`. Prefer the dedicated variable in CI: a workflow's built-in `GITHUB_TOKEN` expires when the job ends, so a 7-day lease registered with it would outlive its own credential. Registration fails rather than proceeding without a token.

The repository and ref come from `GITHUB_REPOSITORY` / `GITHUB_REF_NAME` when running in Actions, and from the `origin` remote and current branch otherwise. The ref is written into each watch, so a watch registered from a branch rebuilds that branch rather than the repository default.

Credentials are verified against GitHub and every referenced workflow is checked to exist **before** the lease is granted, so a monitor that registers is a monitor that can dispatch. Failures are specific:

| Status | Meaning | Fix |
|--------|---------|-----|
| 401 | GitHub rejected the token | Set a valid, unexpired `NEVERMORE_WATCH_TOKEN` |
| 403 | Token can't write to the repository | Grant `actions: write` |
| 409 | Repository quota exceeded | Release monitors, or let leases expire |
| 422 | Referenced workflow doesn't exist | Fix the `watch` path — it must exist on the dispatched ref |

#### Watching a private base place

The service polls the base place to notice it moved, which needs an Open Cloud key for a private one. The CLI does **not** share the key it deployed with by default. Pass `--watch-share-api-key` to send it:

```bash
nevermore batch deploy --watch https://watch.example.com/v1/register/7d --watch-share-api-key
```

The service stores it encrypted. Without it, a watch on a place the service can't read will simply never fire.

#### `"saved"` base places can't be watched yet

The service's source carries a `versionType`, and the CLI sends the one your `basePlace.version` asks for — so a place watched for publishes and the same place watched for saves are distinct sources, polled separately.

`"saved"` is accepted by the schema but **refused at registration** until the service has a credentialed driver for it. Because one registration carries every watch in the monitor, sending a `"saved"` source would fail the whole request and take every unrelated watch down with it. So the CLI leaves those places out and says so:

```
1 place(s) asked to be watched but could not be:
  integration.places.studio tracks its basePlace as "saved", which the watch
  service cannot poll yet — it watches published versions only. Track
  "published" to make it watchable.
```

The rest of the monitor registers normally. Sharing a key is what lifts this — `buildWatchPlan` gates it on whether the run is credentialed.

## Batch deploys

If you want to deploy every game affected by a code change (for example, on every PR), use `nevermore batch deploy` instead. It scans the pnpm workspace for packages with a matching deploy target, uses `pnpm ls --filter` to figure out which ones changed since `origin/main`, and runs them in parallel.

See [Integration Testing → Batch deploy](testing/integration-testing.md#batch-deploy) for the full flag list and CI usage.

## Reading deploy metadata at runtime

`nevermore deploy` and `nevermore batch deploy` can stamp each build with the deployment that produced it — which commit, which target, when, and whether it was published — so the running game can report its own provenance. This is opt-in by package: a place only gets stamped if it depends on the [`nevermore-cli-manifest`](https://github.com/Quenty/NevermoreEngine/tree/main/src/nevermore-cli-manifest) package.

That package ships a `NevermoreCLIManifestUtils` ModuleScript. Between the rojo build and the upload, the CLI finds that module in the built place and writes the metadata onto it as attributes (via a Lune transform, the same way `basePlace` merges work). Because the data lives on the package's own instance, it replicates to clients automatically. If the module isn't present, the deploy proceeds unchanged.

`nevermore test` and `nevermore batch test` apply the same stamp — but only for packages that ship or directly depend on `nevermore-cli-manifest`, so unrelated packages don't pay for a Lune pass. A consequence is that when you run tests through the CLI's cloud path, `deployed` is `true` during the run too, since the test place really was built and uploaded by the CLI. The package's own spec does not depend on that, though: the standard Jest CI job runs specs in a Roblox VM without the CLI's injection pass, so the spec stamps a synthetic instance itself and asserts the reader returns reasonable, well-shaped values (a hex commit, the `test` target, IDs that round-trip from strings back to numbers).

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

`metadata.deployed` is the source of truth for "is this a real deploy?" — it's only ever `true` when the CLI injected it, so it stays `false` in Studio and in any place that wasn't deployed through the CLI. The full field list (`commit`, `version`, `branch`, `target`, `timestamp`, `published`, `placeId`, `universeId`, `basePlaceId`, `basePlaceVersion`) is documented in the [package README](https://github.com/Quenty/NevermoreEngine/tree/main/src/nevermore-cli-manifest). Consumers like `GameConfig`, `GameVersionUtils`, and PlayerMetrics read from this module rather than reaching for the raw attributes.

`basePlaceVersion` deserves a note, because it is the one fact nothing else can recover. A `basePlace` pinned to `"published"` resolves at deploy time, and the base place keeps moving afterwards — so once a build is running, there is no way to ask which upstream Studio content it was made from. Stamping it at merge time is the only record. It is absent on a build that merged no base place, and it is paired with `basePlaceId`, since a version number means nothing without knowing which place it counts.

That makes it the field to report when someone asks "is the live game running the latest Studio edit?" — compare it against the base place's current version.

### Showing the running version to humans

Anything you put in front of a person — a settings footer, a Cmdr prompt, a bug report — should go through `GameVersionUtils` rather than formatting the metadata itself, so every surface reports a build the same way.

```lua
local GameVersionUtils = require("GameVersionUtils")

print(GameVersionUtils.getVersionString())
--> 1.0.0 · integration · a4a79e8 · v312                        (deployed from main)
--> 1.0.0 · integration · users/quenty/thing · a4a79e8 · v312   (deployed from a branch)
--> studio                                                      (never deployed)
--> undeployed · v312                                           (published outside the CLI)
```

Fields run from most to least stable — package version, environment, branch, commit, place version — and anything the CLI didn't stamp is dropped instead of printed as `?`. The branch only appears when a build came from something other than `main`/`master`, which is exactly when the target alone doesn't tell you what's running.

`GameVersionUtils.observeVersionString()` is the reactive form, and the one to use for anything shown at boot: on the client the metadata arrives with replication, so a synchronous read during startup can miss it. `GameVersionUtils.getEnvironmentName()` / `observeEnvironmentName()` return just the target (`"integration"`, `"production-demo"`), or nil when the place wasn't CLI-deployed — callers should degrade to whatever they showed before rather than inventing an environment name. `GameConfig` uses it to suffix the Cmdr prompt, so `Quenty@CanyonHeights$` becomes `Quenty@CanyonHeights:production$` on a deployed place.

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
