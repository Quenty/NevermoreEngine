## ModelAppearance
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

Allows the appearance of a model to be overridden. Most commonly used when placing down an object in a building game.

## Installation
```
npm install @quenty/modelappearance --save
```

## Usage
Usage is designed to be simple.

### `ModelAppearance.new(model)`

### `ModelAppearance:DisableInteractions()`

### `ModelAppearance:SetCanCollide(canCollide)`

### `ModelAppearance:ResetCanCollide(canCollide)`

### `ModelAppearance:SetTransparency(transparency)`

### `ModelAppearance:ResetTransparency()`

### `ModelAppearance:SetColor(color)`

### `ModelAppearance:ResetColor()`

### `ModelAppearance:ResetMaterial()`

### `ModelAppearance:SetMaterial(material)`


## Changelog

### 1.0.3
- Added linting via selene and fixed code to respect linting

### 1.0.0
Initial release

### 0.0.0
Initial commit
