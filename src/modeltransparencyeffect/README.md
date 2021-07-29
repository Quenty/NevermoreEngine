## ModelTransparencyEffect
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

Allows a model to have transparent set locally on the client

## Installation
```
npm install @quenty/modeltransparencyeffect --save
```

## Usage
Usage is designed to be simple.

### `ModelTransparencyEffect.new(adornee, transparencyServiceMethodName)`

### `ModelTransparencyEffect:SetAcceleration(acceleration)`

### `ModelTransparencyEffect:SetTransparency(transparency, doNotAnimate)`

### `ModelTransparencyEffect:IsDoneAnimating()`

### `ModelTransparencyEffect:FinishTransparencyAnimation(callback)`


## Changelog

### 1.0.3
- Added linting via selene and fixed code to respect linting

### 1.0.0
Initial release

### 0.0.0
Initial commit
