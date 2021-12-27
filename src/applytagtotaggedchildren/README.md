## ApplyTagToTaggedChildren
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

Class that while constructed apply a tag to any children of the parent it is given, assuming that class has the required tag. This lets you bridge tag systems since CollectionService is used as an interop model between many components in scripts.

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/ApplyTagToTaggedChildren">View docs →</a></div>

## Installation
```
npm install @quenty/applytagtotaggedchildren --save
```

## Usage
Usage is designed to be simple.

### `ApplyTagToTaggedChildren.new(parent, tag, requiredTag)`

