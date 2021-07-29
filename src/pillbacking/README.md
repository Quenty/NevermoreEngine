## PillBacking
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

Builds a pill backing for Guis. Substitute for UICorner object. Historically, this was created before the UICorner object was created. It still has utility in that it can provide a dropshadow to pill-based GUIs.

However, you should probably prefer to use a UICorner object instead of this package. This package is primarily published so legacy code may continue to rely upon it.

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

## Changelog

### 1.0.3
- Added linting via selene and fixed code to respect linting

### 1.0.0
Initial release

### 0.0.0
Initial commit
