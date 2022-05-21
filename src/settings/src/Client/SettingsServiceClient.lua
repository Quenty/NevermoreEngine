--[=[
	@class SettingsServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local PlayerSettingsUtils = require("PlayerSettingsUtils")
local Rx = require("Rx")

local SettingsServiceClient = {}

function SettingsServiceClient:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- Internal
	self._serviceBag:GetService(require("SettingServiceBridge")):RegisterSettingService(self)
	self._binders = self._serviceBag:GetService(require("SettingsBindersClient"))
end

function SettingsServiceClient:GetLocalPlayerSettings()
	return self:GetPlayerSettings(Players.LocalPlayer)
end

function SettingsServiceClient:ObserveLocalPlayerSettingsBrio()
	return self:ObservePlayerSettingsBrio(Players.LocalPlayer)
end

function SettingsServiceClient:ObserveLocalPlayerSettings()
	return self:ObservePlayerSettings(Players.LocalPlayer)
end

function SettingsServiceClient:PromiseLocalPlayerSettings(cancelToken)
	return self:PromisePlayerSettings(Players.LocalPlayer, cancelToken)
end

function SettingsServiceClient:ObservePlayerSettings(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return PlayerSettingsUtils.observePlayerSettings(self._binders.PlayerSettings, player)
end

function SettingsServiceClient:ObservePlayerSettingsBrio(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return PlayerSettingsUtils.observePlayerSettingsBrio(self._binders.PlayerSettings, player)
end

function SettingsServiceClient:GetPlayerSettings(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return PlayerSettingsUtils.getPlayerSettings(self._binders.PlayerSettings, player)
end

function SettingsServiceClient:PromisePlayerSettings(player, cancelToken)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return Rx.toPromise(self:ObservePlayerSettings(player):Pipe({
		Rx.where(function(x)
			return x ~= nil
		end)
	}), cancelToken)
end

return SettingsServiceClient