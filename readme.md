## About
Nevermore is a ModuleScript loader for Roblox, and loads modules by name. Nevermore is designed to make code more portable. Nevermore comes with a variety of utility libraries. These libraries are used on both the client and server and are useful for a variety of things. 

Nevermore follows both functional and OOP programming paradigms. However, many modules return classes, and may require more advance Lua knowledge to use. 

## Get Nevermore
To install Nevermore, paste the following code into your command bar in Roblox Studio!

```lua
local h = game:GetService("HttpService") local e = h.HttpEnabled h.HttpEnabled = true loadstring(h:GetAsync("https://raw.githubusercontent.com/Quenty/NevermoreEngine/master/Install.lua"))() h.HttpEnabled = e
```

## Usage
Here's an example of using Nevermore

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LoadCustomLibrary = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))


-- Do actual things
local Players = game:GetService("Players")

local SnackbarManager = LoadCustomLibrary("SnackbarManager").new()
	:WithPlayerGui(Players.LocalPlayer:WaitForChild("PlayerGui"))

SnackbarManager:MakeSnackbar("Nevermore loaded!")
```

## Programming module
Modules are stored in the `ServerScriptService.Nevermore`. 

* Modules are loaded by name, case sensitive
* Modules with the word "Server" (case insensitive) in them at any point will not be replicated to the client
* Folders are used purely for organization and do not affect loading
* Children underneath a module that are not a module will be replicated relatively to their parent

### Programming modules best practices
* Modules should not load on yield
* Modules should not hold state
* Document using Nevermore's specified style

