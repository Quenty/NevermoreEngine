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

## Symlinks

- Each package under `src/` has a `node_modules/` directory that is symlinked and recursive. Regex searching or recursive file operations (`grep -r`, `rg`, `find`) can consume excessive memory. Always use `--ignore` flags to exclude `node_modules`, or use targeted file paths.

## Rojo

- Nevermore uses a custom fork of Rojo that understands symlinks and turns them into ObjectValues. This is required for development but not for consuming packages.

