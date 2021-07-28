## cancellableDelay
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

cancellableDelay a delay that can be cancelled

## Installation
```
npm install @quenty/cancellabledelay --save
```

## Usage
Usage is pretty simple, it's a delay function that returns.

```lua
local cancel = cancellableDelay(2, function(arg)
    print("Executing", arg)
end, 5)

delay(1, function()
    cancel() -- cancel
end)
```

## Changelog

### 1.0.0
Initial release

### 0.0.1
Added documentation

### 0.0.0
Initial commit