## {{pluginNameProper}}

Source code for {{pluginNameProper}}. This plugin was generated using Nevermore's CLI.

# Tools

This plugin uses the following tools

- [Git](https://git-scm.com/download/win) - Source control manager
- [Roblox studio](https://www.roblox.com/create) - IDE
- [Aftman](https://github.com/LPGhatguy/aftman) - Toolchain manager
- [Rojo](https://rojo.space/docs/v7/getting-started/installation/) - Build system (syncs into Studio)
- [Selene](https://kampfkarren.github.io/selene/roblox.html) - Linter
- [npm](https://nodejs.org/en/download/) - Package manager
- [Nevermore](https://github.com/Quenty/NevermoreEngine) - Packages

# Building {{pluginNameProper}}

To build the plugin, you want to do the following

1. Run `npm install` in a terminal of your choice
2. In Roblox Studio, enable PluginDebugService by navigating to File -> Studio Settings and searching for "Plugin Debugging Enabled" (located under Studio -> Debugger -> "Plugin Debugging Enabled")
3. Run `rojo build --plugin {{pluginName}}.rbxm --watch` to serve the code

# Adding new packages

To add new packages you can run `npm install @quenty/package-name` or whatever the package you want.