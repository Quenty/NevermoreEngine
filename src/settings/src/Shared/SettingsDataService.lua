--!strict
--[=[
	Shared between client and server, letting us centralize definitions in one place.

	@class SettingsDataService
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Brio = require("Brio")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableMap = require("ObservableMap")
local ObservableSet = require("ObservableSet")
local PlayerSettingsInterface = require("PlayerSettingsInterface")
local Promise = require("Promise")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local ServiceBag = require("ServiceBag")

local SettingsDataService = {}
SettingsDataService.ServiceName = "SettingsDataService"

export type SettingsDataService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_tieRealmService: any,
		_settingDefinitions: ObservableSet.ObservableSet<any>,
		_playerSettingsCacheMap: ObservableMap.ObservableMap<Player, any>,
		_hydratedPlayersMaid: Maid.Maid,
	},
	{} :: typeof({ __index = SettingsDataService })
))

--[=[
	Initializes the shared registry service. Should be done via [ServiceBag].

	@param serviceBag ServiceBag
]=]
function SettingsDataService.Init(self: SettingsDataService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._tieRealmService = self._serviceBag:GetService(require("TieRealmService"))

	-- State
	self._settingDefinitions = self._maid:Add(ObservableSet.new())
end

function SettingsDataService._getPlayerSettingsCacheMap(
	self: SettingsDataService
): ObservableMap.ObservableMap<Player, any>
	-- Avoid hydrating
	if self._playerSettingsCacheMap then
		return self._playerSettingsCacheMap
	end

	self._playerSettingsCacheMap = self._maid:Add(ObservableMap.new() :: ObservableMap.ObservableMap<Player, any>)
	self._hydratedPlayersMaid = self._maid:Add(Maid.new())

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player: Player)
		self._hydratedPlayersMaid[player] = nil
	end))

	return (self._playerSettingsCacheMap :: any) :: ObservableMap.ObservableMap<Player, any>
end

function SettingsDataService._getPlayerSettingsMapForPlayer(
	self: SettingsDataService,
	player: Player
): ObservableMap.ObservableMap<Player, any>
	local playerSettingsCacheMap = self:_getPlayerSettingsCacheMap()

	if self._hydratedPlayersMaid[player] then
		return playerSettingsCacheMap
	end

	-- Note we only do this as requested to save memory. On the client, we're unlikely
	-- to even query other player's settings.
	self._hydratedPlayersMaid[player] = self:_hydrateCacheForPlayer(player)

	return playerSettingsCacheMap
end

function SettingsDataService._hydrateCacheForPlayer(self: SettingsDataService, player: Player): Maid.Maid
	local playerMaid = Maid.new()

	playerMaid:GiveTask((RxInstanceUtils.observeChildrenBrio(player, function(value): any
		-- We really only care about this, and we can assume we have the tag immediately
		return value:HasTag("PlayerSettings")
	end) :: any)
		:Pipe({
			RxBrioUtils.flatMapBrio(function(playerSettingsInstance): any
				return PlayerSettingsInterface:ObserveBrio(playerSettingsInstance, self._tieRealmService:GetTieRealm())
			end),
		})
		:Subscribe(function(brio): ()
			if brio:IsDead() then
				return
			end

			local maid, playerSettings = brio:ToMaidAndValue()
			maid:GiveTask(self._playerSettingsCacheMap:Set(playerSettings:GetPlayer(), playerSettings))
		end))

	return playerMaid
end

--[=[
	Gets the setting definitions

	@return { SettingDefinition }
]=]
function SettingsDataService.GetSettingDefinitions(self: SettingsDataService): { any }
	return self._settingDefinitions:GetList()
end

--[=[
	Registers settings definitions

	@param definition SettingDefinition
	@return callback -- Cleanup callback
]=]
function SettingsDataService.RegisterSettingDefinition(self: SettingsDataService, definition: any): () -> ()
	assert(definition, "No definition")

	return self._settingDefinitions:Add(definition)
end

--[=[
	Observes the registered definitions

	@return Observable<Brio<SettingDefinition>>
]=]
function SettingsDataService.ObserveRegisteredDefinitionsBrio(
	self: SettingsDataService
): Observable.Observable<Brio.Brio<any>>
	return self._settingDefinitions:ObserveItemsBrio()
end

--[=[
	Observes the player's settings

	@param player Player
	@return Observable<PlayerSettingsBase>
]=]
function SettingsDataService.ObservePlayerSettings(
	self: SettingsDataService,
	player: Player
): Observable.Observable<any>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return (self:_getPlayerSettingsMapForPlayer(player) :: any):ObserveAtKey(
		player,
		self._tieRealmService:GetTieRealm()
	)
end

--[=[
	Observes the player settings in a brio

	@param player Player
	@return Observable<Brio<PlayerSettingsClient>>
]=]
function SettingsDataService.ObservePlayerSettingsBrio(
	self: SettingsDataService,
	player: Player
): Observable.Observable<Brio.Brio<any>>
	return (self:_getPlayerSettingsMapForPlayer(player) :: any):ObserveAtKeyBrio(
		player,
		self._tieRealmService:GetTieRealm()
	)
end

--[=[
	Promises the player's settings

	@param player Player
	@param cancelToken CancelToken
	@return Promise<PlayerSettingsBase>
]=]
function SettingsDataService.PromisePlayerSettings(
	self: SettingsDataService,
	player: Player,
	cancelToken: any
): Promise.Promise<any>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return Rx.toPromise(
		(self:ObservePlayerSettings(player) :: any):Pipe({
			Rx.where(function(playerSettings): any
				return playerSettings ~= nil
			end),
		}),
		cancelToken
	)
end

--[=[
	Gets the player's settings

	@param player Player
	@return Promise<PlayerSettingsBase>
]=]
function SettingsDataService.GetPlayerSettings(self: SettingsDataService, player: Player): any
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self:_getPlayerSettingsMapForPlayer(player):Get(player)
end

--[=[
	Cleans up the shared registry service
]=]
function SettingsDataService.Destroy(self: SettingsDataService): ()
	self._maid:DoCleaning()
end

return SettingsDataService
