## NetworkOwnerService
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

NetworkOwnerService - Tracks a stack of owners so ownership isn't reverted or overwritten in delayed network owner set

## Installation
```
npm install @quenty/networkownerservice --save
```

## Setup

```lua
-- Server.lua

require("NetworkOwnerService"):Init()
```

## Usage
```lua
-- Force this part to be owned by the server
local handle = NetworkOwnerService:AddSetNetworkOwnerHandle(workspace.Part, nil)

delay(2.5, function()
	-- oh no, another function wants to set the network owner, guess we'll be owned by Quenty for a while
	local handle = NetworkOwnerService:AddSetNetworkOwnerHandle(workspace.Part, Players.Quenty)

	delay(1, function()
		-- stop using quenty, guess we're back to the server now
		handle()
	end)
end)

delay(5, function()
	handle() -- stop forcing network ownership to be the server, now we're back to nil
end)
```
## Changelog

### 1.0.3
- Added linting via selene and fixed code to respect linting

### 1.0.0
Initial release

### 0.0.1
Added documentation

### 0.0.0
Initial commit