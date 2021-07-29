## LinkUtils
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

Utility functions for links. Links are object values pointing to other values!

## Installation
```
npm install @quenty/linkutils --save
```

## Usage
Usage is designed to be simple.

### `LinkUtils.createLink(linkName, from, to)`

### `LinkUtils.getAllLinkValues(linkName, from)`

### `LinkUtils.getAllLinks(linkName, from)`

### `LinkUtils.getLinkValue(linkName, from)`

### `LinkUtils.promiseLinkValue(maid, linkName, from)`

## Changelog

### 1.0.3
- Added linting via selene and fixed code to respect linting

### 1.0.0
Initial release

### 0.0.1
- Added RxLinkUtils

### 0.0.0
Initial commit