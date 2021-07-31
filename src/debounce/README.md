## debounce
<div align="center">
  <a href="http://quenty.github.io/api/">
    <img src="https://img.shields.io/badge/docs-website-green.svg" alt="Documentation" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/badge/discord-nevermore-blue.svg" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/build.yml/badge.svg" alt="Build and release status" />
  </a>
</div>

debounce a existing function by timeout

## Installation
```
npm install @quenty/debounce --save
```

## Usage

```lua
debouncePrint = debounce(0.5, print)

debouncePrint("Hi") --> Hi
debouncePrint("Hello") --> ... (silence, this got debounced)
```

## DebounceTimer API

### `DebounceTimer.new(length)`

### `DebounceTimer:SetLength(length)`

### `DebounceTimer:Restart()`

### `DebounceTimer:IsRunning()`

### `DebounceTimer:IsDone()`

## Changelog

### 1.0.3
- Added linting via selene and fixed code to respect linting

### 1.0.0
Initial release

### 0.0.0
Initial commit
