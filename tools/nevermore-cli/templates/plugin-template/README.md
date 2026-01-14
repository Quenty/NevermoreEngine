## {{pluginNameProper}}

Source code for {{pluginNameProper}}. This plugin was generated using Nevermore's CLI.

# Tools

This plugin uses the following tools

- [Git](https://git-scm.com/download/win) - Source control manager
- [Roblox studio](https://www.roblox.com/create) - IDE
- [Aftman](https://github.com/LPGhatguy/aftman) - Toolchain manager
- [Rojo](https://rojo.space/docs/v7/getting-started/installation/) - Build system (syncs into Studio)
- [Selene](https://kampfkarren.github.io/selene/roblox.html) - Linter
- [Luau-LSP](https://github.com/JohnnyMorganz/luau-lsp)
- [node](https://nodejs.org/en/download/) - Execution runner + manager
- [pnpm](https://pnpm.io/) - Package manager
- [Nevermore](https://github.com/Quenty/NevermoreEngine) - Packages

# Building {{pluginNameProper}}

To build the plugin, you want to do the following

1. Run `pnpm install` in a terminal of your choice
2. In Roblox Studio, enable PluginDebugService by navigating to File -> Studio Settings and searching for "Plugin Debugging Enabled" (located under Studio -> Debugger -> "Plugin Debugging Enabled")
3. Run `rojo build --plugin {{pluginName}}.rbxm --watch` to serve the code

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

# Getting Luau-lsp to work in VSCode

Configure your vscode settings to use the custom work!

```
"luau-lsp.server.path": "C:/Users/James Onnen/.aftman/tool-storage/quenty/luau-lsp/VERSION/luau-lsp.exe",
```