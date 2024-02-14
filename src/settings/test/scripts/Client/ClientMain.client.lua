--[[
	@class ClientMain
]]
local loader = game:GetService("ReplicatedStorage"):WaitForChild("settings"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("SettingsServiceClient"))
serviceBag:Init()
serviceBag:Start()

local SettingDefinition = require("SettingDefinition")

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