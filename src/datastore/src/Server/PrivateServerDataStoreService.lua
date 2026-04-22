--!strict
--[=[
	Service which manages central access to datastore. This datastore is per a private server
	or reserved server. The main server will also get one, with an empty key.

	@class PrivateServerDataStoreService
]=]

local require = require(script.Parent.loader).load(script)

local DataStore = require("DataStore")
local DataStorePromises = require("DataStorePromises")
local Maid = require("Maid")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")

local PrivateServerDataStoreService = {}
PrivateServerDataStoreService.ServiceName = "PrivateServerDataStoreService"

export type PrivateServerDataStoreService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_dataStorePromise: Promise.Promise<DataStore.DataStore>?,
		_robloxDataStorePromise: Promise.Promise<any>?,
		_bindToCloseService: any,
		_customKey: string?,
	},
	{} :: typeof({ __index = PrivateServerDataStoreService })
))

function PrivateServerDataStoreService.Init(self: PrivateServerDataStoreService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._bindToCloseService = self._serviceBag:GetService(require("BindToCloseService"))
end

--[=[
	Promises a DataStore for the current private server. If this is not a private server, it returns a datastore
	that is keyed towards "main".

	@return Promise<DataStore>
]=]
function PrivateServerDataStoreService.PromiseDataStore(
	self: PrivateServerDataStoreService
): Promise.Promise<DataStore.DataStore>
	if self._dataStorePromise then
		return self._dataStorePromise
	end

	self._dataStorePromise = self:_promiseRobloxDataStore():Then(function(robloxDataStore)
		local dataStore = self._maid:Add(DataStore.new(robloxDataStore, self:_getKey()))

		if game.PrivateServerOwnerId ~= 0 then
			dataStore:Store("LastPrivateServerOwnerId", game.PrivateServerOwnerId)
		end

		self._maid:GiveTask(self._bindToCloseService:RegisterPromiseOnCloseCallback(function()
			return dataStore:Save()
		end))

		return dataStore
	end)
	assert(self._dataStorePromise, "Typechecking assertion")

	return self._dataStorePromise
end

function PrivateServerDataStoreService.SetCustomKey(self: PrivateServerDataStoreService, customKey: string): ()
	assert(
		self._dataStorePromise == nil,
		"[PrivateServerDataStoreService] - Already got datastore, cannot set custom key"
	)

	self._customKey = customKey
end

function PrivateServerDataStoreService._promiseRobloxDataStore(
	self: PrivateServerDataStoreService
): Promise.Promise<any>
	if self._robloxDataStorePromise then
		return self._robloxDataStorePromise
	end

	-- This could potentially
	self._robloxDataStorePromise =
		self._maid:GivePromise(DataStorePromises.promiseDataStore("PrivateServerDataStores", "Version1"))
	assert(self._robloxDataStorePromise, "Typechecking assertion")

	return self._robloxDataStorePromise
end

function PrivateServerDataStoreService._getKey(self: PrivateServerDataStoreService): string
	if self._customKey then
		return self._customKey
	end
	if game.PrivateServerId ~= "" then
		return game.PrivateServerId
	else
		return "main"
	end
end

function PrivateServerDataStoreService.Destroy(self: PrivateServerDataStoreService): ()
	self._maid:DoCleaning()
end

return PrivateServerDataStoreService
