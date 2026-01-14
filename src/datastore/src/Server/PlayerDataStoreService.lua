--!strict
--[=[
	Centralized service using serviceBag. This will let other packages work with a single player datastore service.

	@server
	@class PlayerDataStoreService
]=]

local require = require(script.Parent.loader).load(script)

local DataStore = require("DataStore")
local DataStorePromises = require("DataStorePromises")
local Maid = require("Maid")
local PlayerDataStoreManager = require("PlayerDataStoreManager")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")

local PlayerDataStoreService = {}
PlayerDataStoreService.ServiceName = "PlayerDataStoreService"

export type PlayerDataStoreService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_dataStoreName: string,
		_dataStoreScope: string,
		_dataStoreManagerPromise: Promise.Promise<PlayerDataStoreManager.PlayerDataStoreManager>,
		_bindToCloseService: any,
		_promiseStarted: Promise.Promise<()>,
	},
	{} :: typeof({ __index = PlayerDataStoreService })
))

--[=[
	Initializes the PlayerDataStoreService. Should be done via [ServiceBag.Init].
	@param serviceBag ServiceBag
]=]
function PlayerDataStoreService.Init(self: PlayerDataStoreService, serviceBag: ServiceBag.ServiceBag): ()
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
function PlayerDataStoreService.Start(self: PlayerDataStoreService): ()
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
function PlayerDataStoreService.SetDataStoreName(self: PlayerDataStoreService, dataStoreName: string): ()
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
function PlayerDataStoreService.SetDataStoreScope(self: PlayerDataStoreService, dataStoreScope: string): ()
	assert(type(dataStoreScope) == "string", "Bad dataStoreScope")
	assert(self._promiseStarted, "Not initialized")
	assert(self._promiseStarted:IsPending(), "Already started, cannot configure")

	self._dataStoreScope = dataStoreScope
end

--[=[
	Gets the datastore for the player.

	:::tip
	If you get the datastore by UserId, be sure to call datastore:PromiseCloseSession()
	when done to avoid session leaks.
	:::

	@param player Player | number
	@return Promise<DataStore>
]=]
function PlayerDataStoreService.PromiseDataStore(
	self: PlayerDataStoreService,
	player: Player | number
): Promise.Promise<DataStore.DataStore>
	return self:PromiseManager():Then(function(manager)
		return manager:GetDataStore(player)
	end)
end

--[=[
	Adds a removing callback to the manager.
	@param callback function -- May return a promise
	@return Promise
]=]
function PlayerDataStoreService.PromiseAddRemovingCallback(
	self: PlayerDataStoreService,
	callback: () -> Promise.Promise<any>?
): Promise.Promise<()>
	return self:PromiseManager():Then(function(manager)
		manager:AddRemovingCallback(callback)
	end)
end

--[=[
	Retrieves the manager
	@return Promise<PlayerDataStoreManager>
]=]
function PlayerDataStoreService.PromiseManager(
	self: PlayerDataStoreService
): Promise.Promise<PlayerDataStoreManager.PlayerDataStoreManager>
	if self._dataStoreManagerPromise then
		return self._dataStoreManagerPromise
	end

	self._dataStoreManagerPromise = self._promiseStarted
		:Then(function()
			return DataStorePromises.promiseDataStore(self._dataStoreName, self._dataStoreScope)
		end)
		:Then(function(dataStore)
			local manager = self._maid:Add(PlayerDataStoreManager.new(dataStore, function(player)
				if type(player) == "number" then
					return tostring(player)
				else
					return tostring(player.UserId)
				end
			end, true))

			-- A lot safer if we're hot reloading or need to monitor bind to close calls
			self._maid:GiveTask(self._bindToCloseService:RegisterPromiseOnCloseCallback(function()
				return manager:PromiseAllSaves()
			end))

			return manager
		end)
	assert(self._dataStoreManagerPromise, "Typechecking assertion")

	return self._dataStoreManagerPromise
end

function PlayerDataStoreService.Destroy(self: PlayerDataStoreService): ()
	self._maid:DoCleaning()
end

return PlayerDataStoreService
