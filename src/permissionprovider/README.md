## Permission Provider
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

Utility permission provider system for Roblox

## Usage

```lua
---
-- @module PermissionService
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local PermissionProvider = require("PermissionProvider")
local PermissionProviderUtils = require("PermissionProviderUtils")

return PermissionProvider.new(PermissionProviderUtils.createGroupRankConfig({
  groupId = 8668163;
  minAdminRequiredRank = 250;
  minCreatorRequiredRank = 254;
}))
```