## PlayerThumbnailUtils
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

Reimplementation of Player:GetUserThumbnailAsync but as a promise with retry logic

## Installation
```
npm install @quenty/playerthumbnailutils --save
```

## Usage
Usage is designed to be simple.

### `PlayerThumbnailUtils.promiseUserThumbnail(userId, thumbnailType, thumbnailSize)`

