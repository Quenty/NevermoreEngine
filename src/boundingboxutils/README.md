## BoundingBoxUtils
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

Bounding box utilties. Prefer model:GetBoundingBox() in most cases. However, sometimes grouping isn't possible.

## Installation
```
npm install @quenty/boundingboxutils --save
```

## BoundingBoxUtils API
Usage is designed to be simple.

### `BoundingBoxUtils.getPartsBoundingBox(parts, relativeTo)`

### `BoundingBoxUtils.clampPointToBoundingBox(cframe, size, point)`

### `BoundingBoxUtils.pushPointToLieOnBoundingBox(cframe, size, point)`

### `BoundingBoxUtils.getChildrenBoundingBox(parent, relativeTo)`

### `BoundingBoxUtils.axisAlignedBoxSize(cframe, size)`

### `BoundingBoxUtils.getBoundingBox(data, relativeTo)`
Gets a boundingBox for the given data

### `BoundingBoxUtils.inBoundingBox(cframe, size, testPosition)`

## CompiledBoundingBoxUtils API

### `CompiledBoundingBoxUtils.compileBBox(cframe, size)`
### `CompiledBoundingBoxUtils.testPointBBox(pt, bbox)`
