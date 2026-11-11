## GameVersionUtils
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

Utility functions to automatically detect the version a game is running at

<div align="center"><a href="https://quenty.github.io/NevermoreEngine/api/GameVersionUtils">View docs →</a></div>

## Installation
```
npm install @quenty/gameversionutils --save
```

## Usage

`getVersionString()` formats the place version together with the deploy metadata the nevermore CLI bakes in (see [`@quenty/nevermoreclimanifest`](https://github.com/Quenty/NevermoreEngine/tree/main/src/nevermore-cli-manifest)), so every diagnostic surface reports a build the same way.

```lua
local GameVersionUtils = require("GameVersionUtils")

print(GameVersionUtils.getVersionString())
--> 1.0.0 · integration · a4a79e8 · v312                        (deployed from main)
--> 1.0.0 · integration · users/quenty/thing · a4a79e8 · v312   (deployed from a branch)
--> studio                                                      (never deployed)
--> undeployed · v312                                           (published outside the CLI)
```

Fields the CLI did not stamp are dropped rather than printed as placeholders, and the branch is only shown when a build came from something other than `main`/`master`.

Use `observeVersionString()` for anything displayed at boot — on the client the metadata arrives with replication. `getEnvironmentName()` returns just the deploy target (`"integration"`, `"production-demo"`), or nil when the place was not deployed through the CLI.