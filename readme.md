<div align="center">
  <h1>Nevermore</h1>
  <p>
    <a href="http://quenty.github.io/NevermoreEngine/">
      <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/docs.yml/badge.svg" alt="Documentation status" />
    </a>
    <a href="https://discord.gg/mhtGUS8">
      <img src="https://img.shields.io/discord/385151591524597761?color=5865F2&label=discord&logo=discord&logoColor=white" alt="Discord" />
    </a>
    <a href="https://github.com/Quenty/NevermoreEngine/actions">
      <img src="https://github.com/Quenty/NevermoreEngine/actions/workflows/build.yml/badge.svg" alt="Build and release status" />
    </a>
  </p>
  <p>ModuleScript loader with reusable and easy unified server-client modules for faster game development on Roblox.</p>
  <a href="https://quenty.github.io/NevermoreEngine/">View docs →</a>
</div>

<div>&nbsp;</div>

<div align="center">
  ⚠ <b>WARNING</b>: This branch of Nevermore is under development and is gaining CI/CD and other quality-of-life upgrades. Usage may be unstable at this point, and versions may not be fully semantically versioned. ⚠
</div>

<div>&nbsp;</div>
<!--moonwave-hide-before-this-line-->

## Install using npm
Nevermore is designed to use [npm](https://www.npmjs.com/) to manage packages. You can install a package like this.

```
npm install @quenty/maid
```

Each package is designed to be synced into Roblox using [rojo](https://rojo.space/).

## Install using bootstrapper
To install Nevermore, paste the following code into your command bar in Roblox Studio!

```lua
local h = game:GetService("HttpService") local e = h.HttpEnabled h.HttpEnabled = true loadstring(h:GetAsync("https://raw.githubusercontent.com/Quenty/NevermoreEngine/version2/Install.lua"))(e)
```