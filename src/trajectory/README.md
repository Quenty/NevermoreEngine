## trajectory
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

Utility function for estimating low and high arcs of projectiles. Solves for bullet drop given. Returns two possible paths from origin to target where the magnitude of the initial velocity is initialVelocity.

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/trajectory">View docs →</a></div>

## Installation
```
npm install @quenty/trajectory --save
```

## Usage
```lua
local bullet = Instance.new("Part", workspace)
bullet.Position = Vector3.new(0, 100, 0)

-- 200 studs down-range
local target = Vector3.new(200, 100, 0)

-- Use the actual function
local low, high, fallback = trajectory(bullet.Position, target, 250, workspace.Gravity)

-- Make part follow low trajectory if available, and then high, and then the fallback.
-- This will ensure the part, assuming it does not hit anything, hits the targetted position
bullet.Velocity = low or high or fallback
```

## API

### `trajectory(origin, target, initialVelocity, gravityForce)`
Returns two possible paths from origin to target where the magnitude of the initial velocity is initialVelocity

- origin: Vector3, Origin of the bullet
- target: Vector3, Target for the bullet
- initialVelocity: number, Magnitude of the initial velocity
- gravityForce: number, Force of the gravity

## MinEntranceVelocityUtils API

### `MinEntranceVelocityUtils.minimizeEntranceVelocity(origin, target, accel)`
Determines the starting velocity to minimize the velocity at the target for a parabula

### `MinEntranceVelocityUtils.computeEntranceVelocity(velocity, origin, target, accel)`
NOTE: This may only works for a minimizeEntranceVelocity

### `MinEntranceVelocityUtils.computeEntranceTime(velocity, origin, target, accel)`
NOTE: This may only works for a minimizeEntranceVelocity

