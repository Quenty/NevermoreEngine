# Nevermore-VSCode

This provides snippets for Nevermore for VSCode that help with boiler-plate. For example, you can do type `class` in Lua document, and it will generate a Lua class.

Note that sometimes this can lead to built-in patterns emerging that are maybe more verbose than intended. Please consider updating the snippets as Nevermore develops to reduce boilerplate.

## Building locally
Basic approach:

```bash
npm run build:install
```

Manual approach:

```bash
npm install -g @vscode/vsce
vsce package
code --install-extension roblox-lua-snippets-1.0.0.vsix
```