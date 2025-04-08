--[=[
	Shared between client and server, letting us centralize definitions in one place.

	@class SettingsDataService
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Maid = require("Maid")
local ObservableMap = require("ObservableMap")
local ObservableSet = require("ObservableSet")
local PlayerSettingsInterface = require("PlayerSettingsInterface")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local _ServiceBag = require("ServiceBag")

local SettingsDataService = {}

export type SettingsDataService = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
	},
	{} :: typeof({ __index = SettingsDataService })
))

--[=[
	Initializes the shared registry service. Should be done via [ServiceBag].

	@param serviceBag ServiceBag
]=]
function SettingsDataService:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._tieRealmService = self._serviceBag:GetService(require("TieRealmService"))

	-- State
	self._settingDefinitions = self._maid:Add(ObservableSet.new())
end

function SettingsDataService:_getPlayerSettingsCacheMap()
	-- Avoid hydrating
	if self._playerSettingsCacheMap then
		return self._playerSettingsCacheMap
	end

	self._playerSettingsCacheMap = self._maid:Add(ObservableMap.new())
	self._hydratedPlayersMaid = self._maid:Add(Maid.new())

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player: Player)
		self._hydratedPlayersMaid[player] = nil
	end))

	return self._playerSettingsCacheMap
end

function SettingsDataService:_getPlayerSettingsMapForPlayer(player: Player)
	local playerSettingsCacheMap = self:_getPlayerSettingsCacheMap()

	if self._hydratedPlayersMaid[player] then
		return playerSettingsCacheMap
	end

	-- Note we only do this as requested to save memory. On the client, we're unlikely
	-- to even query other player's settings.
	self._hydratedPlayersMaid[player] = self:_hydrateCacheForPlayer(player)

	return playerSettingsCacheMap
end

function SettingsDataService:_hydrateCacheForPlayer(player: Player)
	local playerMaid = Maid.new()

	playerMaid:GiveTask(RxInstanceUtils.observeChildrenBrio(player, function(value)
		-- We really only care about this, and we can assume we have the tag immediately
		return value:HasTag("PlayerSettings")
	end)
		:Pipe({
			RxBrioUtils.flatMapBrio(function(playerSettingsInstance)
				return PlayerSettingsInterface:ObserveBrio(playerSettingsInstance, self._tieRealmService:GetTieRealm())
			end),
		})
		:Subscribe(function(brio)
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
function SettingsDataService:GetSettingDefinitions()
	return self._settingDefinitions:GetList()
end

--[=[
	Registers settings definitions

	@param definition SettingDefinition
	@return callback -- Cleanup callback
]=]
function SettingsDataService:RegisterSettingDefinition(definition)
	assert(definition, "No definition")

	return self._settingDefinitions:Add(definition)
end

--[=[
	Observes the registered definitions

	@return Observable<Brio<SettingDefinition>>
]=]
function SettingsDataService:ObserveRegisteredDefinitionsBrio()
	return self._settingDefinitions:ObserveItemsBrio()
end

--[=[
	Observes the player's settings

	@param player Player
	@return Observable<PlayerSettingsBase>
]=]
function SettingsDataService:ObservePlayerSettings(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self:_getPlayerSettingsMapForPlayer(player):ObserveAtKey(player, self._tieRealmService:GetTieRealm())
end

--[=[
	Observes the player settings in a brio

	@param player Player
	@return Observable<Brio<PlayerSettingsClient>>
]=]
function SettingsDataService:ObservePlayerSettingsBrio(player: Player)
	return self:_getPlayerSettingsMapForPlayer(player):ObserveAtKeyBrio(player, self._tieRealmService:GetTieRealm())
end

--[=[
	Promises the player's settings

	@param player Player
	@param cancelToken CancelToken
	@return Promise<PlayerSettingsBase>
]=]
function SettingsDataService:PromisePlayerSettings(player: Player, cancelToken)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return Rx.toPromise(
		self:ObservePlayerSettings(player):Pipe({
			Rx.where(function(playerSettings)
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
function SettingsDataService:GetPlayerSettings(player: Player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self:_getPlayerSettingsMapForPlayer(player):Get(player)
end

--[=[
	Cleans up the shared registry service
]=]
function SettingsDataService:Destroy()
	self._maid:DoCleaning()
end

return SettingsDataService
