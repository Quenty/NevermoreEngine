## Brio
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

Brios wrap a value and provide the following constraints

## Installation
```
npm install @quenty/brio --save
```

- Can be in 2 states, dead or alive
- While alive, can retrieve values
- While dead, retrieving values is forbidden
- Died will fire once upon death

Brios encapsulate the "lifetime" of a valid resource. Unlike a maid, they
- Can only die once
- Have less memory leaks
- Cannot be reentered

Calling :Destroy() or :Kill() after death does nothing. Brios cannot be resurrected.

Useful for downstream events where you want to emit a resource. Typically
brios should be killed when their source is killed.

Brios are intended to be merged with downstream brios so create a chain of reliable
resources.

Anything may "kill" a brio by calling :Destroy() or :Kill().

## API Surface

### `Brio.isBrio(value)`

### `Brio.new(...) -- Wrap`

### `Brio:GetDiedSignal()`

### `Brio:IsDead()`

### `Brio:ErrorIfDead()`

### `Brio:ToMaid()`

### `Brio:GetValue()`

### `Brio:Destroy()`

## Changelog

### 1.0.0
Initial release

### 0.0.1
- Added RxBrioUtils to brio
- Updated documentation
- Added changelog

### 0.0.0
Initial commit