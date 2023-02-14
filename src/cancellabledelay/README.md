## cancellableDelay
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

cancellableDelay a delay that can be cancelled

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/cancellableDelay">View docs →</a></div>

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
