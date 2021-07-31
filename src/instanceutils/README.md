## InstanceUtils
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

Utility functions involving instances in Roblox

## Installation
```
npm install @quenty/instanceutils --save
```

## API

### `RxInstanceUtils.observeProperty(instance, property)`

### `RxInstanceUtils.observeAncestry(instance)`

### `RxInstanceUtils.observePropertyBrio(instance, property, predicate)`

### `RxInstanceUtils.observeLastNamedChildBrio(parent, className, name)`

### `RxInstanceUtils.observeChildrenOfClassBrio(parent, className)`

### `RxInstanceUtils.observeChildrenBrio(parent, predicate)`

### `RxInstanceUtils.observeDescendants(parent, predicate)`


## Changelog

### 1.0.3
- Added linting via selene and fixed code to respect linting

### 1.0.0
Initial release

### 0.0.1
Added documentation

### 0.0.0
Initial commit