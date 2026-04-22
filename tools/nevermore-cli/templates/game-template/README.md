## {{gameNameProper}}

Source code for {{gameNameProper}}. This game was generated using Nevermore's CLI.

# Tools

This game uses the following tools

- [Git](https://git-scm.com/download/win) - Source control manager
- [Roblox studio](https://www.roblox.com/create) - IDE
- [Aftman](https://github.com/LPGhatguy/aftman) - Toolchain manager
- [Rojo](https://rojo.space/docs/v7/getting-started/installation/) - Build system (syncs into Studio)
- [Selene](https://kampfkarren.github.io/selene/roblox.html) - Linter
- [Luau-LSP](https://github.com/JohnnyMorganz/luau-lsp)
- [node](https://nodejs.org/en/download/) - Execution runner + manager
- [pnpm](https://pnpm.io/) - Package manager
- [Nevermore](https://github.com/Quenty/NevermoreEngine) - Packages
- [Nevermore CLI](https://github.com/Quenty/NevermoreEngine/tree/main/tools/nevermore-cli) - Testing, deployment, and CI utilities

# Building {{gameNameProper}}

To build the game, you want to do the following

1. Run `pnpm install` in a terminal of your choice
2. Run `rojo serve` to serve the code

# Adding new packages

To add new packages you can run `pnpm install @quenty/package-name` or whatever the package you want.

# Running tools locally

To check linting, run the following commands in your terminal.

```bash
npm run lint:luau
```

```bash
npm run lint:selene
```

```bash
npm run lint:stylua
```

```bash
npm run lint:moonwave
```

To automatically fix formatting, run

```bash
npm run format
```

Note that you should also configure your editor to automatically format files using Stylua.

# CI/CD

This project includes GitHub Actions workflows in `.github/workflows/`:

- **Linting** (`linting.yml`) — Runs automatically on PRs and push to main. Posts inline annotations on PRs for luau-lsp, stylua, selene, and moonwave issues.
- **Tests** (`tests.yml`) — Runs on PRs when configured. Set up with `nevermore deploy init` to create a `deploy.nevermore.json`, then add `ROBLOX_OPEN_CLOUD_API_KEY` as a repository secret.
- **Deploy** (`deploy.yml`) — Runs on push to main when configured. Same setup as tests: `nevermore deploy init` + `ROBLOX_OPEN_CLOUD_API_KEY` secret.

Tests and deploy workflows are inactive until configured — they skip cleanly with a notice annotation explaining the setup steps.

# Getting Luau-lsp to work in VSCode

Configure your vscode settings to use the custom work!

```
"luau-lsp.server.path": "C:/Users/James Onnen/.aftman/tool-storage/quenty/luau-lsp/VERSION/luau-lsp.exe",
```