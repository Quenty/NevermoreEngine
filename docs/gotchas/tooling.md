---
title: Tooling Gotchas
sidebar_position: 1
---

# Tooling Gotchas

:::tip Before adding an entry
Would this save someone real debugging time? If you wouldn't warn a teammate about it, don't add it here.
:::

When a section grows to 10+ items, graduate it to its own doc.

## Lune

- **No `--` separator**: When spawning `lune run script.luau arg1 arg2`, do NOT use `--` between the script path and arguments. Lune passes `--` through to `process.args`, shifting all arguments by one.
- **DataModel attributes**: `roblox.deserializePlace()` returns a DataModel. `SetAttribute` must be called on a child service (e.g., `game:GetService("Workspace")`), not on the DataModel root.
- **Number attributes serialize as float32**: `SetAttribute(name, 123456789)` followed by `serializePlace()` truncates the value to float32, so any integer above 2^24 comes back rounded (123456789 → 123456792). Real Roblox stores number attributes as float64, so this only bites when a value passes *through* Lune serialization — which the deploy pipeline does. Store IDs and other large integers as **string** attributes and convert with `tonumber` on read (see `transform-inject-deploy-metadata.lua` and `NevermoreCLIManifestUtils`).
- **ObjectValue cross-DataModel reparenting**: When reparenting instances from one deserialized DataModel to another (e.g., in `combine-test-places.lua`), ObjectValues (which are links to other instances) may or may not survive the move. Reparenting a whole subtree as a unit preserves intra-subtree ObjectValue references in practice, but this behavior is not explicitly guaranteed by Lune's `@lune/roblox` API. If batch tests start failing with nil references, this is the first thing to investigate — the fallback is to resolve broken ObjectValues after reparenting by rebuilding them from Name/path lookups.

## Symlinks

- Each package under `src/` has a `node_modules/` directory that is symlinked and recursive. Regex searching or recursive file operations (`grep -r`, `rg`, `find`) can consume excessive memory. Always use `--ignore` flags to exclude `node_modules`, or use targeted file paths.

## Linter CLI Tools

- **Per-package execution**: moonwave-extractor, selene, and other linters run via `npx lerna exec --parallel` must be run per-package, not repo-wide. The recursive symlinked `node_modules` under `src/` will cause them to traverse infinitely and freeze. This is why `package.json` uses `npx lerna exec --parallel` rather than running the tools at the repo root. Same caution applies when debugging locally.
- **selene needs the repo config, or every file "fails to parse"**: running bare `selene src` from a package directory reports hundreds of `parse_error`s pointing at ordinary Luau type syntax (`local x = y :: any` → "expected identifier after `:`"). The errors are an artifact of the missing config, not of the code. Pass it the way CI does — from the package directory, `selene --no-summary --num-threads=1 --config=../../selene.toml src` — and run `selene generate-roblox-std` first if the std file is stale.
- **CI annotations**: The `linting.yml` workflow emits GitHub Actions annotations via `nevermore tools post-lint-results`. For the luau-lsp job (which already has pnpm), annotations run in-job. For stylua/selene/moonwave (lightweight Aftman-only jobs), output is uploaded as artifacts and a separate `lint-annotations` job processes them. GitHub caps annotations at 10 per step and 50 per run — the job summary serves as a fallback for large lint failures.
- **Template CI annotations**: Game and plugin templates use a simpler pattern — every linter job posts annotations inline via `npx @quenty/nevermore-cli tools post-lint-results`. No artifact relay or separate `lint-annotations` job needed, since `setup-node` is sufficient to run `npx` (no pnpm install required in the annotation step).

## nevermore-cli

- **`npm install` can't install `@quenty/*` packages in a pnpm project**: some published packages still carry a `workspace:*` range in their `devDependencies` (the release tooling rewrites `dependencies` but not `devDependencies`), and npm rejects that protocol outright with `EUNSUPPORTEDPROTOCOL — Unsupported URL Type "workspace:"`. pnpm ignores it. This is why `nevermore install` detects the project's package manager instead of always shelling out to npm, and why the game/plugin templates install with pnpm.
- **Registry search only returns 250 packages per page**: there are 300+ published `@quenty/*` packages, so a single unpaginated `registry.npmjs.org/-/v1/search` call silently misses the tail. Anything validating a package name against that list needs to page with `from`, or query the package directly at `registry.npmjs.org/@quenty%2f<name>`.
- **The watch service and the lock file do not share a version vocabulary.** A watch's `baselineVersion`, and the `currentVersion` it reports back, are the *asset-delivery content hash* for the place — that's what the service's Roblox driver reads, and it compares them by string equality. `deploy.nevermore.lock.json` holds the *Open Cloud place version* (an integer). They are never equal, so handing the lock's number over as a baseline reads as drift on the very first poll and dispatches a rebuild of the build that just shipped. The CLI therefore sends no baseline at all — the service's first poll adopts what it sees, which is what a baseline was for — and treats every version the service reports as an opaque "something moved" token, asking Open Cloud what the place is actually at before deciding to rebuild. Anything comparing a service version against a lock version is wrong even when the types line up.

- **How Open Cloud delivers a task's logs and return value is asserted, not written down here.** `tools/nevermore-cli/src/utils/open-cloud/open-cloud-logs.characterization.test.ts` runs real tasks against a real place and pins every claim we depend on: that a small run arrives whole and in order, that a large one is truncated to a contiguous *tail* by a ring buffer whose capacity does not grow with output, that page size counts log *entries* so no request parameter recovers what was dropped, and that an oversize return value fails the whole task rather than arriving cut short. Run it with `NEVERMORE_CHARACTERIZATION=1 npm test -- open-cloud-logs` from `tools/nevermore-cli`; it is skipped by default because it spends Open Cloud quota. **Do not restate its numbers in prose** — a measurement copied into a document cannot notice when Roblox changes it, and several of the numbers that used to live here were already stale. The one design consequence worth stating: anything that must be read back exactly belongs in the script's return value, never in its output.

- **How jest-lua reports a run is asserted in `src/nevermore-test-runner/src/Server/NevermoreTestResults.spec.lua`.** Three bugs shipped green out of this logic — counts read off `runCLI`'s wrapper instead of the inner `AggregatedResult`, jest-lua's `AggregatedResult.success` being set to the *failure* condition rather than negated, and `numFailedTestSuites` double-counted by adding `numRuntimeErrorTestSuites` to it. Each is now a test, along with the rule that made them survivable: validate the counts with the invariant `total == passed + failed + skipped` rather than a list of field names, and **fail closed** on a shape you cannot read, because a missing count reads as `0` and zero failures over zero tests is spelled exactly like a clean run.

- **Documenting a *local* Luau function with `--[=[ … ]=]` breaks `lint:moonwave`.** moonwave-extractor treats any `--[=[` block as a doc comment and rejects one it cannot attach to a class: `error: Function requires @within tag`. It also aborts on the first diagnostic, so one bad block hides every other. Use plain `--[[ … ]]` for local helpers and keep `--[=[ … ]=]` for public members (or add `@within` explicitly, as `@prop` blocks do).

- **A structured channel that is plumbed but not flowing looks exactly like one that works.** The first version of the results-return path shipped inert: the runner returned its table, the batch runner captured it, the parser preferred it — and because the counts were all zero and nothing said where they came from, the verdict silently fell back to log scraping and every check passed. Both readers now state provenance unconditionally (`countsSource`, plus an `info` line naming how many packages returned counts), warn when a run fell back to scraping, and warn when the two channels disagree about the same run's totals. When adding a channel that has a fallback, make using the fallback louder than using the channel.

- **`--script-text` loses everything after the first line when invoked through `npx` on Windows**: the `npx.cmd` shim truncates a multi-line argument, so `nevermore test --cloud --script-text '<line 1>\n<line 2>'` silently runs only line 1 (and prints `(no output)` when line 1 produced none). Either write the script as a single line with `;` separators, or bypass the shim: `node tools/nevermore-cli/dist/nevermore.js test --cloud --script-text '...'`, which passes newlines through intact.

## Claude Code hooks

Committed Claude Code hooks live in `.claude/settings.json`, backed by scripts in `.claude/hooks/`. They run only for contributors using Claude Code — not for manual `git` usage or CI.

- **stylua auto-format on edit** (`PostToolUse` → `stylua-format.mjs`): after any `.lua`/`.luau` edit, the file is formatted in place with `stylua.toml`.
- **prettier auto-format on edit** (`PostToolUse` → `prettier-format.mjs`): after editing a `.ts`/`.tsx`/`.js`/`.jsx` file under `tools/`, it is formatted in place, matching `npm run format:ts` (root prettier config, `--ignore-path .gitignore`).
- **luau type check before push** (`PreToolUse(Bash)` → `luau-lint-before-push.mjs`): a `git push` runs `npm run lint:luau` first and is blocked if it fails. The matcher only fires on a push in command position (start of line or after `;`/`&&`/`||`/`|`/`(`).

The push hook blocks on any non-zero exit from `lint:luau`, including luau-lsp lint warnings like `LocalShadow` — so the tree must stay lint-clean for Claude-driven pushes to succeed.

## Rojo

- Nevermore uses a custom fork of Rojo that understands symlinks and turns them into ObjectValues. This is required for development but not for consuming packages.
- **Symlink deduplication**: When multiple `$path` entries resolve to the same physical filesystem path (common with pnpm workspace links where `src/A/node_modules/@quenty/loader` and `src/B/node_modules/@quenty/loader` both symlink to `src/loader`), rojo only includes the content once — under whichever tree entry it processes first. The second entry's subtree silently loses those dependencies. This means you **cannot combine multiple packages into a single rojo project** if they share workspace-linked dependencies. The workaround is to build each package individually with rojo, then merge the outputs using Lune's `@lune/roblox` API (reparenting whole subtrees preserves ObjectValue references within each package).
- **A package that gains its first dependency needs `src/node_modules.project.json`**: that nested project is the only thing that pulls a package's own `node_modules` into the build. Packages with no dependencies beyond `loader`/`nevermore-test-runner` don't have the file, so it's easy to add a dependency to one and never notice the file is missing. Nothing catches it: `pnpm install` links the dependency, luau-lsp resolves it off the filesystem, and the build succeeds — the package just ships without its dependencies. The loader then walks *up* the tree at runtime and usually finds them anyway, because some ancestor package happens to depend on the same thing. The failure only appears when that coincidence ends, and it appears in an unrelated package as `[Loader] - "SomeModule" is not available`. Copy the file verbatim from any package that has one, then confirm with `rojo build <pkg>/default.project.json --output out.rbxlx` and grep the output for an instance named after the dependency.

