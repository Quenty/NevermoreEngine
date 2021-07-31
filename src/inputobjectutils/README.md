## InputObjectUtils
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

Provides utility functions involving input objects

## Installation
```
npm install @quenty/inputobjectutils --save
```

## InputObjectRayUtils API

### `InputObjectRayUtils.cameraRayFromInputObject(inputObject, distance)`

### `InputObjectRayUtils.cameraRayFromInputObjectWithOffset(inputObject, distance, offset)`

### `InputObjectRayUtils.cameraRayFromScreenPosition(position, distance)`

### `InputObjectRayUtils.cameraRayFromViewportPosition(position, distance)`

### `InputObjectRayUtils.generateCircleRays(ray, count, radius)`
Generates a circle of rays including the center ray

## InputObjectUtils API

### `InputObjectUtils.isMouseUserInputType(userInputType)`

### `InputObjectUtils.isSameInputObject(inputObject, otherInputObject)`
