## GameConfig
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

Generalized game configuration system

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/GameConfig">View docs →</a></div>

## Installation
```
npm install @quenty/gameconfig --save
```

## Design

This configuration service is designed to serve as a general backing for selling things in games, even if those products are not written into a general package. For example, a "pay to use" system could be written without explicit knowledge of the game it will be used in, or even the thing the user is paying to use.

## Features

* Localization
* Pull-from-cloud
* Support existing assets by id
* Retrieve-by-name
* Add and remove assets dynamically
* Mantle support

## Specific design features
* Easy for non-programmer to add asset for a specific game
