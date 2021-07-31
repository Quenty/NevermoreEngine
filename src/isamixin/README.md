## IsAMixin
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

Generic IsA interface for Lua classes.

## Installation
```
npm install @quenty/isamixin --save
```

## Usage
Usage is designed to be simple.

### `IsAMixin:Add(class)`
Adds the IsA function to a class and all descendants

### `IsAMixin:IsA(className)`
Using the .ClassName property, returns whether or not a component is


## Changelog

### 1.0.3
- Added linting via selene and fixed code to respect linting

### 1.0.0
Initial release

### 0.0.0
Initial commit
