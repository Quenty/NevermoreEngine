## TemplateProvider
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

Base of a template retrieval system

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/TemplateProvider">View docs →</a></div>

## Installation
```
npm install @quenty/templateprovider --save
```

## Deferred replication template behavior

1. We want to defer replication of templates until client requests the template
2. Then we want to send the template to the client via PlayerGui methods
3. We want to decide whether or not to bother doing this

This will prevent memory usage of unused templates on the client, which happens with the cars and a variety of other game-systems.

We can't store the stuff initially in cameras or in team-create Roblox won't replicate the stuff. But we can move on run-time and hope...