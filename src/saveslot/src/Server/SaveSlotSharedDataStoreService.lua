--!strict
--[=[
	Owns a single global (non-player) datastore that hands save-slot snapshots between sessions and
	players. Unlike a player store this is a flat key/value store -- each key (a code/guid) holds one
	snapshot -- with no session locking, so a write is immediately loadable from any server. Pair it
	with [HasSaveSlots.PromiseSaveSlotToSharedDataStore] / [HasSaveSlots.PromiseImportSlotFromSharedDataStore].

	@server
	@class SaveSlotSharedDataStoreService
]=]

local require = require(script.Parent.loader).load(script)

local DataStorePromises = require("DataStorePromises")
local Maid = require("Maid")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")

local SaveSlotSharedDataStoreService = {}
SaveSlotSharedDataStoreService.ServiceName = "SaveSlotSharedDataStoreService"

export type SaveSlotSharedDataStoreService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_robloxDataStorePromise: Promise.Promise<any>?,
		_dataStoreName: string,
		_dataStoreScope: string,
	},
	{} :: typeof({ __index = SaveSlotSharedDataStoreService })
))

function SaveSlotSharedDataStoreService.Init(
	self: SaveSlotSharedDataStoreService,
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
function SaveSlotSharedDataStoreService.SetRobloxDataStore(
	self: SaveSlotSharedDataStoreService,
	robloxDataStore: any
): ()
	assert(DataStorePromises.isDataStore(robloxDataStore), "Bad robloxDataStore")
	assert(not self._robloxDataStorePromise, "Already resolved robloxDataStore, cannot override")

	self._robloxDataStorePromise = Promise.resolved(robloxDataStore)
end

--[=[
	Sets the datastore name. Must be called before the datastore is first resolved.
]=]
function SaveSlotSharedDataStoreService.SetDataStoreName(self: SaveSlotSharedDataStoreService, name: string): ()
	assert(type(name) == "string", "Bad name")
	assert(not self._robloxDataStorePromise, "Cannot set name after datastore has been resolved")

	self._dataStoreName = name
end

--[=[
	Sets the datastore scope. Must be called before the datastore is first resolved.
]=]
function SaveSlotSharedDataStoreService.SetDataStoreScope(self: SaveSlotSharedDataStoreService, scope: string): ()
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
function SaveSlotSharedDataStoreService.PromiseWrite(
	self: SaveSlotSharedDataStoreService,
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
function SaveSlotSharedDataStoreService.PromiseRead(
	self: SaveSlotSharedDataStoreService,
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
function SaveSlotSharedDataStoreService.PromiseRemove(
	self: SaveSlotSharedDataStoreService,
	key: string
): Promise.Promise<boolean>
	assert(type(key) == "string", "Bad key")

	return self:_promiseRobloxDataStore():Then(function(robloxDataStore)
		return DataStorePromises.removeAsync(robloxDataStore, key)
	end)
end

function SaveSlotSharedDataStoreService._promiseRobloxDataStore(
	self: SaveSlotSharedDataStoreService
): Promise.Promise<any>
	if self._robloxDataStorePromise then
		return self._robloxDataStorePromise
	end

	self._robloxDataStorePromise =
		self._maid:GivePromise(DataStorePromises.promiseDataStore(self._dataStoreName, self._dataStoreScope))

	assert(self._robloxDataStorePromise, "Typechecking assertion")

	return self._robloxDataStorePromise
end

function SaveSlotSharedDataStoreService.Destroy(self: SaveSlotSharedDataStoreService): ()
	self._maid:DoCleaning()
end

return SaveSlotSharedDataStoreService
