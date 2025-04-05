--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.settings)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("SettingsService"))
local bridge = serviceBag:GetService(require("SettingsServiceBridge"))

local SettingDefinition = require("SettingDefinition")

local screenShakeDefinition = SettingDefinition.new("ScreenShake", false)
serviceBag:GetService(screenShakeDefinition)
serviceBag:Init()
serviceBag:Start()


local volumeDefinition = SettingDefinition.new("Volume", 1)
bridge:RegisterSettingDefinition(volumeDefinition)

local rumbleDefinition = SettingDefinition.new("Rumble", true)
bridge:RegisterSettingDefinition(rumbleDefinition)

local function handlePlayer(player: Player)
	local volume = volumeDefinition:GetSettingProperty(serviceBag, player)

	volume:PromiseValue():Then(function(value)
		print(value)
	end)

	-- volume:PromiseSetValue(0.5)
	-- 	:Then(function()
	-- 		print(volume.Value)
	-- 	end)
end

game.Players.PlayerAdded:Connect(handlePlayer)
for _, player in game.Players:GetPlayers() do
	handlePlayer(player)
end

