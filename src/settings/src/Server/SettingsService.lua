--[=[
	@class SettingsService
]=]

local require = require(script.Parent.loader).load(script)

local PlayerSettingsUtils = require("PlayerSettingsUtils")
local Rx = require("Rx")
local Maid = require("Maid")

local SettingsService = {}
SettingsService.ServiceName = "SettingsService"

function SettingsService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("PlayerDataStoreService"))
	self._serviceBag:GetService(require("SettingsCmdrService"))


	-- Internal
	self._binders = self._serviceBag:GetService(require("SettingsBindersServer"))
	self._serviceBag:GetService(require("SettingRegistryServiceShared")):RegisterSettingService(self)
end

function SettingsService:ObservePlayerSettingsBrio(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return PlayerSettingsUtils.observePlayerSettingsBrio(self._binders.PlayerSettings, player)
end

function SettingsService:ObservePlayerSettings(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return PlayerSettingsUtils.observePlayerSettings(self._binders.PlayerSettings, player)
end

function SettingsService:GetPlayerSettings(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return PlayerSettingsUtils.getPlayerSettings(self._binders.PlayerSettings, player)
end

function SettingsService:PromisePlayerSettings(player, cancelToken)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return Rx.toPromise(self:ObservePlayerSettings(player):Pipe({
		Rx.where(function(x)
			return x ~= nil
		end)
	}), cancelToken)
end

function SettingsService:Destroy()
	self._maid:DoCleaning()
end

return SettingsService