## TransparencyService
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

Service that orchistrates transparency setting from multiple colliding sources and handle the transparency appropriately. This means that 2 systems can work with transparency without knowing about each other.

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/TransparencyService">View docs →</a></div>

## Installation
```
npm install @quenty/transparencyservice --save
```

## Usage
Usage is designed to be simple.

### `TransparencyService:Init()`

### `TransparencyService:SetTransparency(key, part, transparency)`

### `TransparencyService:SetLocalTransparencyModifier(key, part, transparency)`

### `TransparencyService:ResetLocalTransparencyModifier(key, part)`

### `TransparencyService:ResetTransparency(key, part)`

