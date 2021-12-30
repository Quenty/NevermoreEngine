## RoundedBackingBuilder
<div align="center">
  <a href="http://quenty.github.io/NevermoreEngine/">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/docs.yml/badge.svg" alt="Documentation status" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/discord/385151591524597761?color=5865F2&label=discord&logo=discord&logoColor=white" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/build.yml/badge.svg" alt="Build and release status" />
  </a>
</div>

Construct a rounded backing with a shadow. This existed before UICorner existed, and remains for backwards compatability with games that still leverage this. Note that the dropshadow created by this is still impossible to recreate with a UICorner, so this provides some utility.

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/RoundedBackingBuilder">View docs →</a></div>

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

