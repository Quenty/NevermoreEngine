## Signal
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
A simple signal implementation for Roblox

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
