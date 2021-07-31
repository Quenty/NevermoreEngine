## TransparencyService
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

Service that orchistrates transparency setting from multiple colliding sources and handle the transparency appropriately. This means that 2 systems can work with transparency without knowing about each other.

## Installation
```
npm install @quenty/transparencyservice --save
```

## Usage
Usage is designed to be simple.

### `TransparencyService:Init()`

### `TransparencyService:SetTransparency(key, part, transparency)`

### `TransparencyService:SetLocalTransparencyModifier(key, part, transparency)`

### `TransparencyService:ResetLocalTransparencyModifier(key, part)`

### `TransparencyService:ResetTransparency(key, part)`


## Changelog

### 1.0.3
- Added linting via selene and fixed code to respect linting

### 1.0.0
Initial release

### 0.0.0
Initial commit
