## PlayerInputMode
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

Service that takes active input modes from the player and exposes it to every other player via the server.

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/PlayerInputModeService">View docs →</a></div>

## Installation
```
npm install @quenty/playerinputmode --save
```

## Design
It's oftentimes useful to know if a player is on mobile, pc, or xbox. However, we're platform agnostic, so instead we'll expose input types, which tend to also affect controls, and other things. This information is useful, not just to us, as developers, but also other players in terms of exposing what behavior they should expect from a player.