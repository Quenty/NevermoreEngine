## RoundedBackingBuilder
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

Construct a rounded backing with a shadow. This existed before UICorner existed, and remains for backwards compatability with games that still leverage this. Note that the dropshadow created by this is still impossible to recreate with a UICorner, so this provides some utility.

## Installation
```
npm install @quenty/roundedbackingbuilder --save
```

## Usage
Usage is designed to be simple.

### `RoundedBackingBuilder.new(options)`
Initializes a new RoundedBackingBuilder

### `RoundedBackingBuilder:Create(gui)`

### `RoundedBackingBuilder:CreateBacking(gui)`

### `RoundedBackingBuilder:CreateTopBacking(gui)`
Only top two corners are rounded

### `RoundedBackingBuilder:CreateLeftBacking(gui)`

### `RoundedBackingBuilder:CreateRightBacking(gui)`

### `RoundedBackingBuilder:CreateBottomBacking(gui)`
Only bottom two corners are rounded

### `RoundedBackingBuilder:CreateTopShadow(backing)`

### `RoundedBackingBuilder:CreateShadow(backing)`


## Changelog

### 1.0.0
Initial release

### 0.0.0
Initial commit
