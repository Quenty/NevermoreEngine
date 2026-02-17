---
title: VSCode / Cursor
sidebar_position: 1
---

# Getting started with VSCode

VSCode works with Nevermore relatively easily. We have default extensions.json setup. Follow the general setup tips. This types should generally work for Cursor and other VS-Code based IDEs.

## Extensions

Nevermore uses standard community extensions, including the following:

* quenty.nevermore-vscode
* kampfkarren.selene-vscode
* johnnymorganz.luau-lsp
* johnnymorganz.stylua

These will provide snippets, styling, and linking.

## Configuration of Luau-LSP

You currently must use the forked version of luau-lsp. You can use the default extension.

in `settings.json` configure the luau-lsp server to point towards a custom exe path. This should be your Luau-lsp exe path installed via aftman.toml.

```json
  "luau-lsp.server.path": "C:/Users/James Onnen/.aftman/tool-storage/quenty/luau-lsp/1.58.0-quenty.1/luau-lsp.exe",
```

## Other helpful settings for consumption

In your user-settings the following settings can be helpful:

```json
  "[lua]": {
    "editor.defaultFormatter": "JohnnyMorganz.stylua",
    "editor.formatOnSave": true,
    "editor.formatOnSaveMode": "file"
  },
  "[luau]": {
    "editor.defaultFormatter": "JohnnyMorganz.stylua",
    "editor.formatOnSave": true,
    "editor.formatOnSaveMode": "file"
  },

  // Explorer
  "explorer.confirmDragAndDrop": false,
  "explorer.compactFolders": false,

  // Make init files not horrible
  "explorer.fileNesting.enabled": true,
  "explorer.fileNesting.patterns": {
    "init.lua": "*.lua",
    "*": "${basename}.*.${extname}"
  },
  "workbench.editor.customLabels.patterns": {
    "**/init.lua": "${dirname}.lua"
  },
```