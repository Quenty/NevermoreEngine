--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local packages = require(loader).bootstrapGame(ServerScriptService.settings)

local serviceBag = require(packages.ServiceBag).new()
serviceBag:GetService(packages.SettingsService)

local SettingDefinition = require(packages.SettingDefinition)

local screenShakeDefinition = SettingDefinition.new("ScreenShake", false)
serviceBag:GetService(screenShakeDefinition)

-- Start game
serviceBag:Init()
serviceBag:Start()


local volumeDefinition = SettingDefinition.new("Volume", 1)
volumeDefinition:RegisterToService(serviceBag)

local rumbleDefinition = SettingDefinition.new("Rumble", true)
rumbleDefinition:RegisterToService(serviceBag)


local function handlePlayer(player)
	local volume = volumeDefinition:GetSettingProperty(serviceBag, player)

	volume:PromiseValue()
		:Then(function(value)
			print(value)
		end)

	-- volume:PromiseSetValue(0.5)
	-- 	:Then(function()
	-- 		print(volume.Value)
	-- 	end)
end

game.Players.PlayerAdded:Connect(handlePlayer)
for _, player in pairs(game.Players:GetPlayers()) do
	handlePlayer(player)
end

