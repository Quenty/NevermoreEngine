local require = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputServic")

-- Load snackbar manager
local SnackbarManager = require("SnackbarManager").new()
	:WithPlayerGui(Players.LocalPlayer:WaitForChild("PlayerGui"))

-- Create snackbar
SnackbarManager:MakeSnackbar("Nevermore loaded!")

-- Show snackbar after every input!
UserInputService.InputBegan:Connect(function()
	SnackbarManager:MakeSnackbar("New input happend!")
end)