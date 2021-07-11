## ScoredActionService
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

Scores actions and picks the highest rated one every frame

## Installation
```
npm install @quenty/scoredactionservice --save
```

## Usage
Usage is designed to be simple.

### `ScoredActionService:Init()`

### `ScoredActionService:GetScoredAction(inputKeyMapList)`

## ScoredAction API

### `ScoredAction.new()`

### `ScoredAction:IsPreferred()`

### `ScoredAction:SetScore(score)`
Big number is more important. At `-math.huge` we won't ever set preferred

### `ScoredAction:GetScore()`

### `ScoredAction:PushPreferred()`

### `ScoredAction.Removing`
Signal for when the scored action is getting cleaned up or removed

### `ScoredAction.PreferredChanged`
Signal for when the IsPreferred() value changed

## Changelog

### 0.0.0
Initial commit
