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

local PlayerDataStoreService = {}

--[=[
	Initializes the PlayerDataStoreService. Should be done via [ServiceBag.Init].
	@param serviceBag ServiceBag
]=]
function PlayerDataStoreService:Init(serviceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._maid = Maid.new()
	self._started = Promise.new()
	self._maid:GiveTask(self._started)

	self._dataStoreName = "PlayerData"
	self._dataStoreScope = "SaveData"
end

--[=[
	Initializes the datastore service for players. Should be done via [ServiceBag.Start].
]=]
function PlayerDataStoreService:Start()
	-- Give time for configuration
	self._started:Resolve()
end

--[=[
	Sets the name for the datastore to retrieve.

	:::info
	Must be done before start and after init.
	:::

	@param dataStoreName string
]=]
function PlayerDataStoreService:SetDataStoreName(dataStoreName)
	assert(type(dataStoreName) == "string", "Bad dataStoreName")
	assert(self._started, "Not initialized")
	assert(self._started:IsPending(), "Already started, cannot configure")

	self._dataStoreName = dataStoreName
end

--[=[
	Sets the scope for the datastore to retrieve.

	:::info
	Must be done before start and after init.
	:::

	@param dataStoreScope string
]=]
function PlayerDataStoreService:SetDataStoreScope(dataStoreScope)
	assert(type(dataStoreScope) == "string", "Bad dataStoreScope")
	assert(self._started, "Not initialized")
	assert(self._started:IsPending(), "Already started, cannot configure")

	self._dataStoreScope = dataStoreScope
end

--[=[
	Gets the datastore for the player.
	@param player Player
	@return Promise<DataStore>
]=]
function PlayerDataStoreService:PromiseDataStore(player)
	return self:PromiseManager()
		:Then(function(manager)
			return manager:GetDataStore(player)
		end)
end

--[=[
	Adds a removing callback to the manager.
	@param callback function -- May return a promise
	@return Promise
]=]
function PlayerDataStoreService:PromiseAddRemovingCallback(callback)
	return self:PromiseManager()
		:Then(function(manager)
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

	self._dataStoreManagerPromise = self._started
		:Then(function()
			return DataStorePromises.promiseDataStore(self._dataStoreName, self._dataStoreScope)
		end)
		:Then(function(dataStore)
			local manager = PlayerDataStoreManager.new(
				dataStore,
				function(player)
					return tostring(player.UserId)
				end)
			self._maid:GiveTask(manager)
			return manager
		end)

	return self._dataStoreManagerPromise
end

return PlayerDataStoreService