--!strict
--[=[
	Provides a service for managing centralized player settings. See [SettingsDataService] for the data service.

	@class SettingsService
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")
local SettingsDataService = require("SettingsDataService")

local SettingsService = {}
SettingsService.ServiceName = "SettingsService"

export type SettingsService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_settingsDataService: SettingsDataService.SettingsDataService,
	},
	{} :: typeof({ __index = SettingsService })
))

function SettingsService.Init(self: SettingsService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("PlayerDataStoreService"))
	self._serviceBag:GetService((require :: any)("SettingsCmdrService"))

	-- Internal
	self._settingsDataService = self._serviceBag:GetService(require("SettingsDataService")) :: any

	-- Binders
	self._serviceBag:GetService(require("PlayerHasSettings"))
	self._serviceBag:GetService(require("PlayerSettings"))
end

--[=[
	Observes the settings for a player using Brio.

	@param player Player
	@return Observable<Brio<PlayerSettings>>
]=]
function SettingsService.ObservePlayerSettingsBrio(
	self: SettingsService,
	player: Player
): Observable.Observable<Brio.Brio<any>>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self._settingsDataService:ObservePlayerSettingsBrio(player)
end

--[=[
	Observes the settings for a player.

	@param player Player
	@return Observable<PlayerSettings>
]=]
function SettingsService.ObservePlayerSettings(self: SettingsService, player: Player): Observable.Observable<any>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self._settingsDataService:ObservePlayerSettings(player)
end

--[=[
	Obtains the settings for a player.

	@param player Player
	@return PlayerSettings
]=]
function SettingsService.GetPlayerSettings(self: SettingsService, player: Player): any
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self._settingsDataService:GetPlayerSettings(player)
end

--[=[
	Promises the settings for a player.

	@param player Player
	@param cancelToken CancelToken?
	@return Promise<PlayerSettings>
]=]
function SettingsService.PromisePlayerSettings(
	self: SettingsService,
	player: Player,
	cancelToken: any?
): Promise.Promise<any>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self._settingsDataService:PromisePlayerSettings(player, cancelToken)
end

--[=[
	Cleans up the settings service
]=]
function SettingsService.Destroy(self: SettingsService): ()
	self._maid:DoCleaning()
end

return SettingsService
