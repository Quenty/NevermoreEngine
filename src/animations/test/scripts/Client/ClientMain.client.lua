--[[
	@class ClientMain
]]
local packages = game:GetService("ReplicatedStorage"):WaitForChild("Packages")

local Players = game:GetService("Players")

local AnimationUtils = require(packages:WaitForChild("AnimationUtils"))

game.UserInputService.InputBegan:Connect(function(inputObject)
	if inputObject.KeyCode == Enum.KeyCode.Q then
		AnimationUtils.playAnimation(Players.LocalPlayer, "rbxassetid://14012074834", nil, nil, 1, Enum.AnimationPriority.Action3)
	end
end)