## PhysicsUtils
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

General physics library for use on Roblox

## Installation
```
npm install @quenty/physicsutils --save
```

## Usage
Usage is designed to be simple.

### `PhysicsUtils.getConnectedParts(part)`
Retrieves all connected parts of a part, plus the connected part

### `PhysicsUtils.getMass(parts)`

### `PhysicsUtils.estimateBuoyancyContribution(parts)`
Estimate buoyancy contributed by parts

### `PhysicsUtils.getCenterOfMass(parts)`
Return's the world vector center of mass.

### `PhysicsUtils.momentOfInertia(part, axis, origin)`
Calculates the moment of inertia of a solid cuboid. This is wrong for Roblox.

### `PhysicsUtils.bodyMomentOfInertia(parts, axis, origin)`
Given a connected body of parts, returns the moment of inertia of these parts

### `PhysicsUtils.applyForce(part, force, forcePosition)`

### `PhysicsUtils.acceleratePart(part, emittingPart, acceleration)`
Accelerates a part utilizing newton's laws. emittingPart is the part it's emitted from.


## Changelog

### 1.0.3
- Added linting via selene and fixed code to respect linting

### 1.0.0
Initial release

### 0.0.0
Initial commit
