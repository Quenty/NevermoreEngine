--!strict
--[=[
	Service which manages central access to datastore. This datastore will refresh pretty frequently and
	can be used for configuration and other components, such as Twitter codes or global settings.

	@server
	@class GameDataStoreService
]=]

local require = require(script.Parent.loader).load(script)

local DataStore = require("DataStore")
local DataStorePromises = require("DataStorePromises")
local Maid = require("Maid")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")

local GameDataStoreService = {}
GameDataStoreService.ServiceName = "GameDataStoreService"

export type GameDataStoreService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_dataStorePromise: Promise.Promise<DataStore.DataStore>?,
		_robloxDataStorePromise: Promise.Promise<any>?,
		_bindToCloseService: any,
	},
	{} :: typeof({ __index = GameDataStoreService })
))

function GameDataStoreService.Init(self: GameDataStoreService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._bindToCloseService = self._serviceBag:GetService(require("BindToCloseService"))
end

--[=[
	Promises a DataStore for the current game that is synchronized every 5 seconds.

	@return Promise<DataStore>
]=]
function GameDataStoreService.PromiseDataStore(self: GameDataStoreService): Promise.Promise<DataStore>
	if self._dataStorePromise then
		return self._dataStorePromise
	end

	self._dataStorePromise = self:_promiseRobloxDataStore():Then(function(robloxDataStore)
		-- Live sync this stuff pretty frequently
		local dataStore: DataStore.DataStore = DataStore.new(robloxDataStore, self:_getKey())
		dataStore:SetSyncOnSave(true)
		dataStore:SetAutoSaveTimeSeconds(5)

		self._maid:GiveTask(self._bindToCloseService:RegisterPromiseOnCloseCallback(function()
			return Promise.defer(function(resolve)
				return resolve(dataStore:Save())
			end):Finally(function()
				dataStore:Destroy()
			end)
		end))

		return dataStore
	end)
	assert(self._dataStorePromise, "Typechecking assertion")

	return self._dataStorePromise
end

function GameDataStoreService._promiseRobloxDataStore(self: GameDataStoreService): Promise.Promise<any>
	if self._robloxDataStorePromise then
		return self._robloxDataStorePromise
	end

	self._robloxDataStorePromise =
		self._maid:GivePromise(DataStorePromises.promiseDataStore("GameDataStore", "Version1"))

	assert(self._robloxDataStorePromise, "Typechecking assertion")

	return self._robloxDataStorePromise
end

function GameDataStoreService._getKey(_self: GameDataStoreService): string
	return "version1"
end

function GameDataStoreService.Destroy(self: GameDataStoreService)
	self._maid:DoCleaning()
end

return GameDataStoreService
