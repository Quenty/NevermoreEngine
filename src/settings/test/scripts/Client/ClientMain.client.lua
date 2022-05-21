--[[
	@class ClientMain
]]
local packages = game:GetService("ReplicatedStorage"):WaitForChild("Packages")

local serviceBag = require(packages.ServiceBag).new()
serviceBag:GetService(packages.SettingsServiceClient)

-- Start game
serviceBag:Init()
serviceBag:Start()

local SettingDefinition = require(packages.SettingDefinition)

local volumeDefinition = SettingDefinition.new("Volume", 1)
local volume = volumeDefinition:Get(serviceBag, game.Players.LocalPlayer)

volume:Observe():Subscribe(function(value)
	print("Volume on client", value)
end)

game:GetService("UserInputService").InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		volume.Value = math.random()
	end
end)