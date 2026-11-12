## Studio-Bridge-Plugin
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

The Roblox Studio side of [studio-bridge](../../tools/studio-bridge/README.md): it connects Studio, and the playtests it starts, to the studio-bridge CLI, which pushes actions to it and runs Luau through it.

You don't install this package yourself. `studio-bridge plugin install` builds it and puts it in Studio's plugins folder, and a session that needs a plugin for one run builds its own copy.

## Working on this package

Run the specs with `nevermore test --cloud` from this directory.
