## IK
<div align="center">
	<a href="http://quenty.github.io/api/">
		<img src="https://img.shields.io/badge/docs-website-green.svg" alt="Documentation" />
	</a>
	<a href="https://discord.gg/mhtGUS8">
		<img src="https://img.shields.io/badge/discord-nevermore-blue.svg" alt="Discord" />
	</a>
	<a href="https://github.com/Quenty/NevermoreEngine/actions">
		<img src="https://github.com/Quenty/NevermoreEngine/workflows/luacheck/badge.svg" alt="Actions Status" />
	</a>
</div>

Inverse kinematics system for Roblox

## Features

* Supports animation playback ontop of the binder
* Battle-tested code
* Handles streaming enabled
* Supports NPCs
* Client-side animations scale with distance
* Client-side animations keep thinks silky

## Installation
```
npm install @quenty/ik --save
```

## Usage
Usage is designed to be very simple.

### Setup
Some setup is required. Init and Start both must be called.

```lua
-- Server.lua
require("IKService"):Init()

require("IKService"):Start()
```

```lua
-- Client.lua
require("CameraStackService"):Init()
require("IKServiceClient"):Init()

require("IKServiceClient"):Start()
```

## Usage on the client

### Overriding where the character looks
```lua
-- Make the local character always look towards the origin

local IKServiceClient = require("IKServiceClient")
local IKAimPositionPriorites = require("IKAimPositionPriorites")

RunService.Stepped:Connect(function()
	IKServiceClient:SetAimPosition(Vector3.new(0, 0, 0), IKAimPositionPriorites.HIGH)
end)
```

### Stopping the character from looking around
```lua
require("IKServiceClient"):SetNoDefaultIK(true)
```

## Usage on the server

### Making an NPC look at a target
```lua
local IKService = require("IKService")

-- Make the NPC look at a target
IKService:UpdateServerRigTarget(workspace.NPC.Humanoid, Vector3.new(0, 0, 0))
```

### Setting up hand grips (arm IK)
```lua
local Binder = require("Binder")
local IKGripUtils = require("IKGripUtils")

-- Create a new binder (do this in a binder provider preferably)
local leftGripAttachmentBinder = Binder.new("IKLeftGrip", require("IKLeftGrip"))
leftGripAttachmentBinder:Init()
leftGripAttachmentBinder:Start()

-- Setup sample grip
local attachment = Instance.new("Attachment")
attachment.Parent = workspace.Terrain
attachment.Name = "GripTarget"

-- This will make the NPC try to grip this attachment
local objectValue = IKGripUtils.create(leftGripAttachmentBinder, workspace.NPC.Humanoid)
objectValue.Parent = attachment
```