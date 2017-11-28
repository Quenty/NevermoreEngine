## About
Nevermore is a ModuleScript loader for Roblox, and loads modules by name. Nevermore is designed to make code more portable. Nevermore comes with a variety of utility libraries. 

## Get Nevermore
To Install Nevermore, paste the following code into your command bar.

```lua
local h = game:GetService("HttpService") local e = h.HttpEnabled h.HttpEnabled = true loadstring(h:GetAsync("https://raw.githubusercontent.com/Quenty/NevermoreEngine/master/Install.lua"))() h.HttpEnabled = e
```

## Usage
Nevermore 


```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LoadCustomLibrary = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
```

### Loading a library
With the above code, you can easily load a library and all dependencies

```lua
local qSystems = LoadCustomLibrary("qSystems")
```

Libraries have different functions with a variety of useful methods. For example, let's say we want to make a lava brick.

Vanilla RobloxLua code to turn all `Part`s into killing bricks:
```lua
local function HandleTouch(Part)
	-- Recursively find the humanoid
	local Humanoid = Part:FindFirstChild("Humanoid")
	if not Humanoid then
		if Part.Parent then
			return HandleTouch(Part.Parent)
		end
	elseif Humanoid:IsA("Humanoid") then
		Part.Humanoid:TakeDamage(100)
	end
end

local function RecurseApplyLava(Parent)
	for _, Item in pairs(Parent:GetChildren()) do
		if Item:IsA("BasePart") then
			Item.Touched:connect(HandleTouch)
		end

		RecurseApplyLava(Item)
	end
end

RecurseApplyLava(workspace)
```

Simpler code utilizing Nevermore's libraries:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LoadCustomLibrary = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))

local qSystems = LoadCustomLibrary("qSystems")

local function HandleTouch(Part)
	local Humanoid = qSystems.GetHumanoid(Part)
	if Humanoid then
		Humanoid:TakeDamage(100)
	end
end

qSystems.CallOnChildren(workspace, function(Item)
	if Item:IsA("BasePart") then
		Item.Touched:connect(HandleTouch)
	end
end)
```


## Manual Installation
Put `NevermoreEngine.lua`'s content's in `game.ReplicatedStorage` in a ModuleScript name `NevermoreEngine`

Put all the modules in a folder in `game.ServerScriptStorage` and name them the names of their script, but without
.lua

```
game
	ReplicatedStorage
		`ModuleScript` NevermoreEngine
	ServerScriptStorage
		`Folder` Nevermore
			`Folder` qSystems
				`ModuleScript` qSystems
				... more libraries
			... more folders and libraries

```