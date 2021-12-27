## Signal
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
A simple signal implementation for Roblox

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/Signal">View docs →</a></div>

## Installation
```
npm install @quenty/signal --save
```

This allows us to pass Lua objects around through a signal without reserialization. It wraps a Roblox bindable event, and reproduces Roblox's signal behavior.

## Features

* Supports Roblox's deferred event mode
* Allows you to pass metatables and other data without reserialization
* Light-weight
* Maintains stack traces
