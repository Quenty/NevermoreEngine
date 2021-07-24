## CoreGuiEnabler
<div align="center">
  <a href="http://quenty.github.io/api/">
    <img src="https://img.shields.io/badge/docs-website-green.svg" alt="Documentation" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/badge/discord-nevermore-blue.svg" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/workflows/luacheck/badge.svg" alt="Actions Status" />
  </a>
</div>

Key based CoreGuiEnabler, singleton Use this class to load/unload CoreGuis / other GUIs, by disabling based upon keys Keys are additive, so if you have more than 1 disabled, it's ok.

## Installation
```
npm install @quenty/coreguienabler --save
```

## Usage
Usage is designed to be simple.

### `CoreGuiEnabler.new()`

### `CoreGuiEnabler:AddState(key, coreGuiStateChangeFunc)`

### `CoreGuiEnabler:Disable(key, coreGuiState)`

### `CoreGuiEnabler:Enable(key, coreGuiState)`


## Changelog

### 1.0.0
Initial release

### 0.0.0
Initial commit
