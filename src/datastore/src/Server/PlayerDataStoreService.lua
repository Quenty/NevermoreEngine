--[=[
	Centralized service using serviceBag. This will let other packages work with a single player datastore service.

	@server
	@class PlayerDataStoreService
]=]

local require = require(script.Parent.loader).load(script)

local PlayerDataStoreManager = require("PlayerDataStoreManager")
local DataStorePromises = require("DataStorePromises")
local Promise = require("Promise")
local Maid = require("Maid")
local _ServiceBag = require("ServiceBag")

local PlayerDataStoreService = {}
PlayerDataStoreService.ServiceName = "PlayerDataStoreService"

export type PlayerDataStoreService = typeof(setmetatable(
	{} :: {
		_serviceBag: _ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_dataStoreName: string,
		_dataStoreScope: string,
		_dataStoreManagerPromise: Promise.Promise<PlayerDataStoreManager.PlayerDataStoreManager>,
	},
	{} :: typeof({ __index = PlayerDataStoreService })
))

--[=[
	Initializes the PlayerDataStoreService. Should be done via [ServiceBag.Init].
	@param serviceBag ServiceBag
]=]
function PlayerDataStoreService:Init(serviceBag: _ServiceBag.ServiceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._bindToCloseService = self._serviceBag:GetService(require("BindToCloseService"))

	self._promiseStarted = self._maid:Add(Promise.new())

	self._dataStoreName = "PlayerData"
	self._dataStoreScope = "SaveData"
end

--[=[
	Initializes the datastore service for players. Should be done via [ServiceBag.Start].
]=]
function PlayerDataStoreService:Start()
	-- Give time for configuration
	self._promiseStarted:Resolve()
end

--[=[
	Sets the name for the datastore to retrieve.

	:::info
	Must be done before start and after init.
	:::

	@param dataStoreName string
]=]
function PlayerDataStoreService:SetDataStoreName(dataStoreName: string)
	assert(type(dataStoreName) == "string", "Bad dataStoreName")
	assert(self._promiseStarted, "Not initialized")
	assert(self._promiseStarted:IsPending(), "Already started, cannot configure")

	self._dataStoreName = dataStoreName
end

--[=[
	Sets the scope for the datastore to retrieve.

	:::info
	Must be done before start and after init.
	:::

	@param dataStoreScope string
]=]
function PlayerDataStoreService:SetDataStoreScope(dataStoreScope: string)
	assert(type(dataStoreScope) == "string", "Bad dataStoreScope")
	assert(self._promiseStarted, "Not initialized")
	assert(self._promiseStarted:IsPending(), "Already started, cannot configure")

	self._dataStoreScope = dataStoreScope
end

--[=[
	Gets the datastore for the player.
	@param player Player
	@return Promise<DataStore>
]=]
function PlayerDataStoreService:PromiseDataStore(player: Player)
	return self:PromiseManager():Then(function(manager)
		return manager:GetDataStore(player)
	end)
end

--[=[
	Adds a removing callback to the manager.
	@param callback function -- May return a promise
	@return Promise
]=]
function PlayerDataStoreService:PromiseAddRemovingCallback(callback)
	return self:PromiseManager():Then(function(manager)
		manager:AddRemovingCallback(callback)
	end)
end

--[=[
	Retrieves the manager
	@return PlayerDataStoreManager
]=]
function PlayerDataStoreService:PromiseManager()
	if self._dataStoreManagerPromise then
		return self._dataStoreManagerPromise
	end

	self._dataStoreManagerPromise = self._promiseStarted
		:Then(function()
			return DataStorePromises.promiseDataStore(self._dataStoreName, self._dataStoreScope)
		end)
		:Then(function(dataStore)
			local manager = self._maid:Add(PlayerDataStoreManager.new(dataStore, function(player)
				return tostring(player.UserId)
			end, true))

			-- A lot safer if we're hot reloading or need to monitor bind to close calls
			self._maid:GiveTask(self._bindToCloseService:RegisterPromiseOnCloseCallback(function()
				return manager:PromiseAllSaves()
			end))

			return manager
		end)

	return self._dataStoreManagerPromise
end

function PlayerDataStoreService:Destroy()
	self._maid:DoCleaning()
end

return PlayerDataStoreService
