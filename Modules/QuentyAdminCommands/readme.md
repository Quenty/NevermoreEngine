These modules makes administration commands such as `Freeze Quenty` or `Teleport me Quenty` easy.

These are all chat based commands.

# Features

* Around 80ish commands
* Overridden commands
* Custom chat UI hides commands 
* Custom chat UI has a log of commands, shows commands to only authenticated users
* Smarter parsing of text (Teleport Team.Red Quenty) will work
* Parsing can work on groups
* No "hidden" or "obfusicated" code to guarantee the creator is given admin
* Low cost

# Installation
Put all the required modules and dependencies in Nevermore.


### Load serverside components
In a regular Script that runs on the server, load `NevermoreCommandsServer`

Suggest parent: `game.ServerScriptStorage`

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local NevermoreCommandsServer = LoadCustomLibrary("NevermoreCommandsServer")
local PseudoChatManagerServer = LoadCustomLibrary("PseudoChatManagerServer")

```

### Load client components

In `StarterPlayer.StarterPlayerScripts` go ahead and load local commands. Put this in a `LocalScript`

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems = LoadCustomLibrary("qSystems")
local NevermoreCommandsLocal = LoadCustomLibrary("NevermoreCommandsLocal")

local LocalPlayer   = Players.LocalPlayer
local PlayerGui     = qSystems.WaitForChild(LocalPlayer, "PlayerGui")
local ScreenGui     = Instance.new("ScreenGui", PlayerGui)

local Chat do
	local PseudoChat = LoadCustomLibrary("PseudoChat")
	Chat = PseudoChat.MakePseudoChat(ScreenGui)
end
```

Note that `ScreenGui` can be parented to whatever you want.

### Set authenticated users

In `QACSettings` go ahead and modify the `Authorized` list and add your username
and any other usernames you want.

Authorized users will see a new tab in the fake chat, which lets them see administration logs.

# Use
Use the chat system to chat out commands. For example, `tp q m` will teleport any player named q to any player named m. 