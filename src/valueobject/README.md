## ValueObject
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

To work like value objects in Roblox and track a single item with .Changed events. The motivation here is to keep it simple to work with an encapsulated value. Instead of exposing an `IPropertyChanged` interface like C# might do, we instead expose objects with .Changed that are encapsulated within the object in question.

## Installation
```
npm install @quenty/valueobject --save
```

## Features

* Battle tested
* Can take in a default value
* Automatically fires with a maid that exists for the lifetime of the value
## Changelog

### 1.0.0
Initial release

### 0.0.1
Added documentation

### 0.0.0
Initial commit