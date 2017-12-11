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
