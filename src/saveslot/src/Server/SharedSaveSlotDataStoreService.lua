--!strict
--[=[
	Owns a single global (non-player) datastore that hands save-slot snapshots between sessions and
	players. Unlike a player store this is a flat key/value store -- each key (a code/guid) holds one
	snapshot -- with no session locking, so a write is immediately loadable from any server. Pair it
	with [HasSaveSlots.PromiseSaveSlotToSharedDataStore] / [HasSaveSlots.PromiseImportSlotFromSharedDataStore].

	@server
	@class SharedSaveSlotDataStoreService
]=]

local require = require(script.Parent.loader).load(script)

local DataStorePromises = require("DataStorePromises")
local Maid = require("Maid")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")

local SharedSaveSlotDataStoreService = {}
SharedSaveSlotDataStoreService.ServiceName = "SharedSaveSlotDataStoreService"

export type SharedSaveSlotDataStoreService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_robloxDataStorePromise: Promise.Promise<any>?,
		_dataStoreName: string,
		_dataStoreScope: string,
	},
	{} :: typeof({ __index = SharedSaveSlotDataStoreService })
))

function SharedSaveSlotDataStoreService.Init(
	self: SharedSaveSlotDataStoreService,
	serviceBag: ServiceBag.ServiceBag
): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._dataStoreName = "SharedSaveSlotData"
	self._dataStoreScope = "Version1"
end

--[=[
	Injects the underlying datastore to use instead of resolving a real one. Accepts a real datastore
	or a [DataStoreMock]. Intended for testing; must be called before the datastore is first resolved.

	@param robloxDataStore DataStore | DataStoreMock
]=]
function SharedSaveSlotDataStoreService.SetRobloxDataStore(
	self: SharedSaveSlotDataStoreService,
	robloxDataStore: any
): ()
	assert(DataStorePromises.isDataStore(robloxDataStore), "Bad robloxDataStore")
	assert(not self._robloxDataStorePromise, "Already resolved robloxDataStore, cannot override")

	self._robloxDataStorePromise = Promise.resolved(robloxDataStore)
end

--[=[
	Sets the datastore name. Must be called before the datastore is first resolved.
]=]
function SharedSaveSlotDataStoreService.SetDataStoreName(self: SharedSaveSlotDataStoreService, name: string): ()
	assert(type(name) == "string", "Bad name")
	assert(not self._robloxDataStorePromise, "Cannot set name after datastore has been resolved")

	self._dataStoreName = name
end

--[=[
	Sets the datastore scope. Must be called before the datastore is first resolved.
]=]
function SharedSaveSlotDataStoreService.SetDataStoreScope(self: SharedSaveSlotDataStoreService, scope: string): ()
	assert(type(scope) == "string", "Bad scope")
	assert(not self._robloxDataStorePromise, "Cannot set scope after datastore has been resolved")

	self._dataStoreScope = scope
end

--[=[
	Writes a value under the given key, optionally tagging the owning user ids (for data-erasure
	discoverability). Resolves once the write commits.

	@param key string
	@param value any
	@param userIds { number }?
	@return Promise<boolean>
]=]
function SharedSaveSlotDataStoreService.PromiseWrite(
	self: SharedSaveSlotDataStoreService,
	key: string,
	value: any,
	userIds: { number }?
): Promise.Promise<boolean>
	assert(type(key) == "string", "Bad key")

	return self:_promiseRobloxDataStore():Then(function(robloxDataStore)
		return DataStorePromises.setAsync(robloxDataStore, key, value, userIds)
	end)
end

--[=[
	Reads the value stored under the given key, resolving nil when absent.

	@param key string
	@return Promise<any>
]=]
function SharedSaveSlotDataStoreService.PromiseRead(
	self: SharedSaveSlotDataStoreService,
	key: string
): Promise.Promise<any>
	assert(type(key) == "string", "Bad key")

	return self:_promiseRobloxDataStore():Then(function(robloxDataStore)
		return DataStorePromises.getAsync(robloxDataStore, key)
	end)
end

--[=[
	Removes the value stored under the given key.

	@param key string
	@return Promise<boolean>
]=]
function SharedSaveSlotDataStoreService.PromiseRemove(
	self: SharedSaveSlotDataStoreService,
	key: string
): Promise.Promise<boolean>
	assert(type(key) == "string", "Bad key")

	return self:_promiseRobloxDataStore():Then(function(robloxDataStore)
		return DataStorePromises.removeAsync(robloxDataStore, key)
	end)
end

function SharedSaveSlotDataStoreService._promiseRobloxDataStore(
	self: SharedSaveSlotDataStoreService
): Promise.Promise<any>
	if self._robloxDataStorePromise then
		return self._robloxDataStorePromise
	end

	self._robloxDataStorePromise =
		self._maid:GivePromise(DataStorePromises.promiseDataStore(self._dataStoreName, self._dataStoreScope))

	assert(self._robloxDataStorePromise, "Typechecking assertion")

	return self._robloxDataStorePromise
end

function SharedSaveSlotDataStoreService.Destroy(self: SharedSaveSlotDataStoreService): ()
	self._maid:DoCleaning()
end

return SharedSaveSlotDataStoreService
