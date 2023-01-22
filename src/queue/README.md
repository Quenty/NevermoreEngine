## Queue
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

Queue class with better performance characteristics than table.remove()

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/Queue">View docs →</a></div>

## Installation
```
npm install @quenty/queue --save
```

## Usage

```lua
local queue = Queue.new()
queue:PushRight("a")
queue:PushRight("b")
queue:PushRight("c")

while not queue:IsEmpty() do
    local entry = queue:PopLeft()
    print(entry) --> a, b, c
end
```