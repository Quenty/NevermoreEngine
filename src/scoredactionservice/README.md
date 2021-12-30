## ScoredActionService
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

Scores actions and picks the highest rated one every frame

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/ScoredActionService">View docs →</a></div>

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
