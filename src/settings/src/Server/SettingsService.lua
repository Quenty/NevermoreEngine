--[=[
	Provides a service for managing centralized player settings. See [SettingsDataService] for the data service.

	@class SettingsService
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local _ServiceBag = require("ServiceBag")

local SettingsService = {}
SettingsService.ServiceName = "SettingsService"

function SettingsService:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("PlayerDataStoreService"))
	self._serviceBag:GetService((require :: any)("SettingsCmdrService"))

	-- Internal
	self._settingsDataService = self._serviceBag:GetService(require("SettingsDataService"))

	-- Binders
	self._serviceBag:GetService(require("PlayerHasSettings"))
	self._serviceBag:GetService(require("PlayerSettings"))
end

--[=[
	Observes the settings for a player using Brio.

	@param player Player
	@return Observable<Brio<PlayerSettings>>
]=]
function SettingsService:ObservePlayerSettingsBrio(player: Player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self._settingsDataService:ObservePlayerSettingsBrio(player)
end

--[=[
	Observes the settings for a player.

	@param player Player
	@return Observable<PlayerSettings>
]=]
function SettingsService:ObservePlayerSettings(player: Player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self._settingsDataService:ObservePlayerSettings(player)
end

--[=[
	Obtains the settings for a player.

	@param player Player
	@return PlayerSettings
]=]
function SettingsService:GetPlayerSettings(player: Player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self._settingsDataService:GetPlayerSettings(player)
end

--[=[
	Promises the settings for a player.

	@param player Player
	@param cancelToken CancelToken?
	@return Promise<PlayerSettings>
]=]
function SettingsService:PromisePlayerSettings(player: Player, cancelToken)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self._settingsDataService:PromisePlayerSettings(player, cancelToken)
end

--[=[
	Cleans up the settings service
]=]
function SettingsService:Destroy()
	self._maid:DoCleaning()
end

return SettingsService
