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
- **ObjectValue cross-DataModel reparenting**: When reparenting instances from one deserialized DataModel to another (e.g., in `combine-test-places.luau`), ObjectValues (which are links to other instances) may or may not survive the move. Reparenting a whole subtree as a unit preserves intra-subtree ObjectValue references in practice, but this behavior is not explicitly guaranteed by Lune's `@lune/roblox` API. If batch tests start failing with nil references, this is the first thing to investigate — the fallback is to resolve broken ObjectValues after reparenting by rebuilding them from Name/path lookups.

## Symlinks

- Each package under `src/` has a `node_modules/` directory that is symlinked and recursive. Regex searching or recursive file operations (`grep -r`, `rg`, `find`) can consume excessive memory. Always use `--ignore` flags to exclude `node_modules`, or use targeted file paths.

## Linter CLI Tools

- **Per-package execution**: moonwave-extractor, selene, and other linters run via `npx lerna exec --parallel` must be run per-package, not repo-wide. The recursive symlinked `node_modules` under `src/` will cause them to traverse infinitely and freeze. This is why `package.json` uses `npx lerna exec --parallel` rather than running the tools at the repo root. Same caution applies when debugging locally.
- **CI annotations**: The `linting.yml` workflow emits GitHub Actions annotations via `nevermore tools post-lint-results`. For the luau-lsp job (which already has pnpm), annotations run in-job. For stylua/selene/moonwave (lightweight Aftman-only jobs), output is uploaded as artifacts and a separate `lint-annotations` job processes them. GitHub caps annotations at 10 per step and 50 per run — the job summary serves as a fallback for large lint failures.

## Rojo

- Nevermore uses a custom fork of Rojo that understands symlinks and turns them into ObjectValues. This is required for development but not for consuming packages.
- **Symlink deduplication**: When multiple `$path` entries resolve to the same physical filesystem path (common with pnpm workspace links where `src/A/node_modules/@quenty/loader` and `src/B/node_modules/@quenty/loader` both symlink to `src/loader`), rojo only includes the content once — under whichever tree entry it processes first. The second entry's subtree silently loses those dependencies. This means you **cannot combine multiple packages into a single rojo project** if they share workspace-linked dependencies. The workaround is to build each package individually with rojo, then merge the outputs using Lune's `@lune/roblox` API (reparenting whole subtrees preserves ObjectValue references within each package).

