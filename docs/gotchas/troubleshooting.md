---
title: Troubleshooting
sidebar_position: 2
---

# Troubleshooting

Common setup and development issues and how to resolve them.

## Setup

### `pnpm install` fails or npm/yarn is rejected

The repo enforces pnpm via a `preinstall` script. Using `npm install` or `yarn install` will fail on purpose.

- Install pnpm: `npm install -g pnpm` (or see [pnpm.io](https://pnpm.io/))
- Verify Node version is 18+: `node --version`
- Run `pnpm install` from the repo root

### Aftman tools not found after install

If `rojo`, `selene`, `stylua`, or `luau-lsp` aren't available after running `aftman install`:

- Ensure aftman's bin directory is on your `PATH`. See [aftman's README](https://github.com/LPGhatguy/aftman) for platform-specific setup.
- Re-run `aftman install` from the repo root — it reads `aftman.toml` for tool versions.
- On first install, you may need to restart your shell for `PATH` changes to take effect.

### Luau-LSP not working in VS Code

Nevermore uses a forked luau-lsp. The standard extension works, but you must point it at the custom binary:

1. Run `aftman install` to get the fork
2. In VS Code settings, set `luau-lsp.server.path` to your aftman-installed binary (see `docs/ides/vscode.md`)
3. Restart VS Code after changing the setting

## Linting

### `lint:luau` errors about missing sourcemap

The luau type checker needs a sourcemap to resolve module paths. `npm run lint:luau` auto-runs `build:sourcemap` via its `prelint:luau` script, so this usually "just works". If it fails:

- Run `npm run build:sourcemap` manually and check for errors
- Ensure Rojo is installed via aftman (the sourcemap is built with Rojo)

### Linting hangs or uses excessive memory

Linters traverse symlinks infinitely if run repo-wide. They must run per-package via `npx lerna exec --parallel`. The `npm run lint:*` scripts in the root `package.json` handle this — don't run selene, moonwave-extractor, or similar tools directly at the repo root.

## Testing

### Cloud tests fail with authentication errors

`nevermore test --cloud` needs a Roblox Open Cloud API key. Credential resolution order:

1. `--api-key` CLI flag
2. `ROBLOX_OPEN_CLOUD_API_KEY` environment variable
3. `.env` file in the package directory

See `docs/testing/testing.md` for full credential documentation.

### Tests pass locally but fail in CI

- CI uses the same `nevermore test --cloud` path. Check that `deploy.nevermore.json` has the correct `universeId` and `placeId`.
- Look at the CI job summary for sourcemap-resolved failure annotations.
- The `--script-text` flag can help debug: `nevermore test --cloud --script-text 'print(workspace:GetChildren())'`

## Rojo

### Rojo build errors or missing modules

Nevermore uses a custom Rojo fork that understands symlinks (installed via aftman). Standard Rojo won't resolve the monorepo's symlinked `node_modules` correctly.

- Verify you're using the forked version: check `aftman.toml` for the Rojo entry
- If modules are missing, run `pnpm install` first — Rojo resolves paths through npm's dependency tree
