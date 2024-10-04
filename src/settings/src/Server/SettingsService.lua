--[=[
	@class SettingsService
]=]

local require = require(script.Parent.loader).load(script)

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
	self._settingsDataService = self._serviceBag:GetService(require("SettingsDataService"))

	-- Binders
	self._serviceBag:GetService(require("PlayerHasSettings"))
	self._serviceBag:GetService(require("PlayerSettings"))
end

function SettingsService:ObservePlayerSettingsBrio(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self._settingsDataService:ObservePlayerSettingsBrio(player)
end

function SettingsService:ObservePlayerSettings(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self._settingsDataService:ObservePlayerSettings(player)
end

function SettingsService:GetPlayerSettings(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self._settingsDataService:GetPlayerSettings(player)
end

function SettingsService:PromisePlayerSettings(player, cancelToken)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self._settingsDataService:PromisePlayerSettings(player, cancelToken)
end

function SettingsService:Destroy()
	self._maid:DoCleaning()
end

return SettingsService