--[=[
	Service which manages central access to datastore. This datastore is per a private server
	or reserved server. The main server will also get one, with an empty key.

	@class PrivateServerDataStoreService
]=]

local require = require(script.Parent.loader).load(script)

local DataStore = require("DataStore")
local DataStorePromises = require("DataStorePromises")
local Maid = require("Maid")
local _ServiceBag = require("ServiceBag")

local PrivateServerDataStoreService = {}
PrivateServerDataStoreService.ServiceName = "PrivateServerDataStoreService"

function PrivateServerDataStoreService:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._bindToCloseService = self._serviceBag:GetService(require("BindToCloseService"))

	self._maid = Maid.new()
end

function PrivateServerDataStoreService:PromiseDataStore()
	if self._dataStorePromise then
		return self._dataStorePromise
	end

	self._dataStorePromise = self:_promiseRobloxDataStore()
		:Then(function(robloxDataStore)
			local dataStore = DataStore.new(robloxDataStore, self:_getKey())
			self._maid:GiveTask(dataStore)

			if game.PrivateServerOwnerId ~= 0 then
				dataStore:Store("LastPrivateServerOwnerId", game.PrivateServerOwnerId)
			end

			self._maid:GiveTask(self._bindToCloseService:RegisterPromiseOnCloseCallback(function()
				return dataStore:Save()
			end))

			return dataStore
		end)

	return self._dataStorePromise
end

function PrivateServerDataStoreService:SetCustomKey(customKey)
	assert(self._dataStorePromise == nil, "[PrivateServerDataStoreService] - Already got datastore, cannot set custom key")

	self._customKey = customKey
end

function PrivateServerDataStoreService:_promiseRobloxDataStore()
	if self._robloxDataStorePromise then
		return self._robloxDataStorePromise
	end

	-- This could potentially
	self._robloxDataStorePromise = self._maid:GivePromise(DataStorePromises.promiseDataStore("PrivateServerDataStores", "Version1"))

	return self._robloxDataStorePromise
end

function PrivateServerDataStoreService:_getKey()
	if self._customKey then
		return self._customKey
	end
	if game.PrivateServerId ~= "" then
		return game.PrivateServerId
	else
		return "main"
	end
end

function PrivateServerDataStoreService:Destroy()
	self._maid:DoCleaning()
end

return PrivateServerDataStoreService