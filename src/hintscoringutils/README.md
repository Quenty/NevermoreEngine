## HintScoringUtils
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

Utility functions that let you score a proximity prompt (i.e. a Hint) based upon its relation to a character in 3D space.

## Installation
```
npm install @quenty/hintscoringutils --save
```

## Usage
Usage is designed to be simple.

### `HintScoringUtils.getHumanoidPositionDirection(humanoid)`

### `HintScoringUtils.getAdorneeInRegionSet(position, radius, ignoreList, getAdorneeFunction)`

### `HintScoringUtils.raycastToAdornee(raycaster, humanoidCenter, adornee, closestBoundingBoxPoint, extraDistance)`

### `HintScoringUtils.clampToBoundingBox(adornee, humanoidCenter)`

### `HintScoringUtils.scoreAdornee(adornee, raycaster, humanoidCenter, humanoidLookVector, maxViewRadius, maxTriggerRadius, maxViewAngle, maxTriggerAngle, isLineOfSightRequired)`

### `HintScoringUtils.scoreDist(distance, maxViewDistance, maxTriggerRadius)`

### `HintScoringUtils.scoreAngle(angle, maxViewAngle, maxTriggerAngle)`


## Changelog

### 0.0.1
Added isLineOfSightRequired to scoreAdornee

### 0.0.0
Initial commit
