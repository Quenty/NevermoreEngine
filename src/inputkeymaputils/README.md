## InputKeyMapUtils
<div align="center">
  <a href="http://quenty.github.io/api/">
    <img src="https://img.shields.io/badge/docs-website-green.svg" alt="Documentation" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/badge/discord-nevermore-blue.svg" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/workflows/lint/badge.svg" alt="Actions Status" />
  </a>
</div>

Utility methods for input map

## Installation
```
npm install @quenty/inputkeymaputils --save
```

## Usage
Usage is designed to be simple.

### `InputKeyMapUtils.createKeyMap(inputMode, inputTypes)`

### `InputKeyMapUtils.getInputTypesSetForActionBinding(inputKeyMapList)`

### `InputKeyMapUtils.getInputTypesForActionBinding(inputKeyMapList)`
Converts keymap into ContextActionService friendly types

### `InputKeyMapUtils.getInputTypeListForMode(inputKeyMapList, inputMode)`

### `InputKeyMapUtils.getInputTypeSetForMode(inputKeyMapList, inputMode)`

### `InputKeyMapUtils.getInputModes(inputKeyMapList)`

### `InputKeyMapUtils.isTouchButton(inputKeyMapList)`

### `InputKeyMapUtils.isTapInWorld(inputKeyMapList)`


## Changelog

### 1.0.0
Initial release

### 0.0.0
Initial commit
