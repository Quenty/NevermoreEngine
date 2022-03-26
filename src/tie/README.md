## Tie
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

Tie allows interfaces to be defined between Lua OOP and Roblox objects. This is designed in part to replace BinderGroups, which were a way to previously allow systems to interface with each other in a generic way. Instead, an object may implement a TieInterface, which is basically bindable functions/events.

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/Tie">View docs →</a></div>

## Installation
```
npm install @quenty/tie --save
```

## Design philosophy
This package does two things. First of all, it basically automates the creation of interfaced definitions, that is, tying a Lua object to BindableEvent/BindableFunction definitions. Second of all, it lets objects be centralized as an interface definition.