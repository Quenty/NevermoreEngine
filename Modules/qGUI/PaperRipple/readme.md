## What is PaperRipple?
Paper ripple is used to emulate the ripple effect as seen in Google's Material Design. It adds responsive feedback to your GUIs. 

## Using the PaperRipple to automatically add ripples to your buttons

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local PaperRipple = LoadCustomLibrary("PaperRipple")

local TextButton = script.Parent -- This is your button
local Ripple = PaperRipple.FromParent(TextButton)
```