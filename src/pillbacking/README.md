## PillBacking
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

Builds a pill backing for Guis. Substitute for UICorner object. Historically, this was created before the UICorner object was created. It still has utility in that it can provide a dropshadow to pill-based GUIs.

However, you should probably prefer to use a UICorner object instead of this package. This package is primarily published so legacy code may continue to rely upon it.

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/PillBackingBuilder">View docs →</a></div>

## Installation
```
npm install @quenty/pillbacking --save
```

## Usage
Usage is designed to be simple.

## Builder API

### `PillBackingBuilder.new(options)`

### `PillBackingBuilder:CreateSingle(gui, options)`

### `PillBackingBuilder:Create(gui, options)`

### `PillBackingBuilder:CreateVertical(gui, options)`

### `PillBackingBuilder:CreateSingleShadow(gui, options)`

### `PillBackingBuilder:CreateShadow(gui, options)`

### `PillBackingBuilder:CreateCircle(gui, options)`

### `PillBackingBuilder:CreateCircleShadow(gui, options)`

### `PillBackingBuilder:CreateLeft(gui, options)`

### `PillBackingBuilder:CreateRight(gui, options)`

### `PillBackingBuilder:CreateTop(gui, options)`

### `PillBackingBuilder:CreateBottom(gui, options)`

## Utils API
Utility functions to work with pillbackings. This can make animations a lot easier to work with.

### `PillBackingUtils.setBackgroundColor(backing, color3)`

### `PillBackingUtils.setTransparency(backing, transparency)`

### `PillBackingUtils.setShadowTransparency(shadow, transparency)`
