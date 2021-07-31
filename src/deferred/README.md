## Deferred
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
Deferred (otherwise known as fastSpawn) implementation for Roblox

## Installation
```
npm install @quenty/deferred --save
```

An expensive way to spawn a function. However, unlike spawn(), it executes on the same frame, and unlike coroutines, does not obscure errors


## Usage
```lua
deferred(function()
	-- This is running at the next event point (or immediately, depending on event mode)
	wait(1)
	-- This is back on Roblox's task scheduler
end)
```
## Changelog

### 1.0.3
- Added linting via selene and fixed code to respect linting

### 1.0.0
Initial release

### 0.0.1
Added documentation

### 0.0.0
Initial commit