## PartTouchingCalculator
<div align="center">
  <a href="http://quenty.github.io/api/">
    <img src="https://img.shields.io/badge/docs-website-green.svg" alt="Documentation" />
  </a>
  <a href="https://discord.gg/mhtGUS8">
    <img src="https://img.shields.io/badge/discord-nevermore-blue.svg" alt="Discord" />
  </a>
  <a href="https://github.com/Quenty/NevermoreEngine/actions">
    <img src="https://github.com/Quenty/NevermoreEngine/workflows/luacheck/badge.svg" alt="Actions Status" />
  </a>
</div>

Determines if parts are touching or not

## Installation
```
npm install @quenty/parttouchingcalculator --save
```

## Usage
Usage is designed to be simple.

## PartTouchingCalculator API
Determines if parts are touching or not

### `PartTouchingCalculator.new()`

### `PartTouchingCalculator:CheckIfTouchingHumanoid(humanoid, parts)`

### `PartTouchingCalculator:GetCollidingPartFromParts(parts, relativeTo, padding)`

### `PartTouchingCalculator:GetTouchingBoundingBox(parts, relativeTo, padding)`

### `PartTouchingCalculator:GetTouchingHull(parts, padding)`
Expensive hull check on a list of parts (aggregating each parts touching list)

### `PartTouchingCalculator:GetTouching(basePart, padding)`
Retrieves parts touching a base part

### `PartTouchingCalculator:GetTouchingHumanoids(touchingList)`


## BinderTouchingCalculator API
Extends PartTouchingCalculator with generic binder stuff

### `BinderTouchingCalculator.new()`

### `BinderTouchingCalculator:GetTouchingClass(binder, touchingList, ignoreObject)`


## PartTouchingRenderer API
Renders touching parts from the PartTouchingCalculator

### `PartTouchingRenderer.new()`

### `PartTouchingRenderer:RenderTouchingProps(touchingPartList)`

## Changelog

### 0.0.0
Initial commit
