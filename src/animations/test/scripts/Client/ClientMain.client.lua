--[[
	@class ClientMain
]]
local loader = game:GetService("ReplicatedStorage"):WaitForChild("animations"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local Players = game:GetService("Players")

local AnimationUtils = require("AnimationUtils")

game.UserInputService.InputBegan:Connect(function(inputObject)
	if inputObject.KeyCode == Enum.KeyCode.Q then
		AnimationUtils.playAnimation(
			Players.LocalPlayer,
			"rbxassetid://14012074834",
			nil,
			nil,
			1,
			Enum.AnimationPriority.Action3
		)
	end
end)
