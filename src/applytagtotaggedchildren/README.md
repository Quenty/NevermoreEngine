## ApplyTagToTaggedChildren
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

Class that while constructed apply a tag to any children of the parent it is given, assuming that class has the required tag. This lets you bridge tag systems since CollectionService is used as an interop model between many components in scripts.

## Installation
```
npm install @quenty/applytagtotaggedchildren --save
```

## Usage
Usage is designed to be simple.

### `ApplyTagToTaggedChildren.new(parent, tag, requiredTag)`

