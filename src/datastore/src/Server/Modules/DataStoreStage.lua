--!strict
--[=[
	Provides a data storage facility with an ability to get sub-stores. So you can write
	directly to this store, overwriting all children, or you can have more partial control
	at children level. This minimizes accidently overwriting.
	The big cost here is that we may leave keys that can't be removed.

	Layers in priority order:

	1. Save data
	2. Substores
	3. Base layer

	@server
	@class DataStoreStage
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local DataStoreDeleteToken = require("DataStoreDeleteToken")
local DataStoreSnapshotUtils = require("DataStoreSnapshotUtils")
local DataStoreWriter = require("DataStoreWriter")
local Signal = require("Signal")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableSubscriptionTable = require("ObservableSubscriptionTable")
local Promise = require("Promise")
local PromiseUtils = require("PromiseUtils")
local Set = require("Set")
local Symbol = require("Symbol")
local Table = require("Table")

local SLOW_INTEGRITY_CHECK_ENABLED = false

local DataStoreStage = setmetatable({}, BaseObject)
DataStoreStage.ClassName = "DataStoreStage"
DataStoreStage.__index = DataStoreStage

export type DataStoreStageKey = string | number

export type DataStoreCallback = () -> Promise.Promise<()>?

export type DataStoreStage = typeof(setmetatable(
	{} :: {
		_loadName: DataStoreStageKey,
		_loadParent: DataStoreStage?,
		_saveDataSnapshot: any,
		_fullPath: string?,
		_baseDataSnapshot: any,
		_viewSnapshot: any,
		_stores: { [DataStoreStageKey]: DataStoreStage },
		_savingCallbacks: { DataStoreCallback },
		_keySubscriptions: ObservableSubscriptionTable.ObservableSubscriptionTable<any>,

		Changed: Signal.Signal<any>,
		DataStored: Signal.Signal<any>,
	},
	{} :: typeof({ __index = DataStoreStage })
)) & BaseObject.BaseObject

--[=[
	Constructs a new DataStoreStage to load from. Prefer to use DataStore because this doesn't
	have any way to retrieve this.

	See [DataStore], [GameDataStoreService], and [PlayerDataStoreService].

	```lua
	-- Data store inherits from DataStoreStage
	local dataStore = serviceBag:GetService(PlayerDataStoreService):PromiseDataStore(player):Yield()
	```

	@param loadName string
	@param loadParent DataStoreStage?
	@return DataStoreStage
]=]
function DataStoreStage.new(loadName: DataStoreStageKey, loadParent: DataStoreStage?): DataStoreStage
	local self: DataStoreStage = setmetatable(BaseObject.new() :: any, DataStoreStage)

	-- LoadParent is optional, used for loading
	self._loadName = loadName
	self._loadParent = loadParent

	self.Changed = self._maid:Add(Signal.new()) -- :Fire(viewSnapshot)
	self.DataStored = self._maid:Add(Signal.new())

	-- Stores the actual data loaded and synced (but not pending written data)
	self._saveDataSnapshot = nil
	self._stores = {} -- [name] = dataSubStore
	self._baseDataSnapshot = nil

	-- View data
	self._viewSnapshot = nil

	self._savingCallbacks = {} -- [func, ...]

	self._keySubscriptions = self._maid:Add(ObservableSubscriptionTable.new())

	return self
end

--[=[
	Stores the value, firing off events and queuing the item for save.

	```lua
	dataStore:Store("money", 25)
	```

	@param key string
	@param value any
]=]
function DataStoreStage.Store(self: DataStoreStage, key: string, value: any)
	assert(type(key) == "string", "Bad key")

	if value == nil then
		value = DataStoreDeleteToken
	end

	-- Ensure that we at least start loading (and thus the autosave loop) for write
	self:PromiseViewUpToDate()

	self:_storeAtKey(key, value)
end

--[=[
	Loads the data at the `key` and returns a promise with that value

	```lua
	dataStore:Load():Then(function(data)
		print(data)
	end)
	```

	@param key string | number
	@param defaultValue T?
	@return Promise<T>
]=]
function DataStoreStage.Load<T>(self: DataStoreStage, key: DataStoreStageKey, defaultValue: T?): Promise.Promise<T>
	assert(type(key) == "string" or type(key) == "number", "Bad key")

	return self:PromiseViewUpToDate():Then(function()
		if type(self._viewSnapshot) == "table" then
			local value = self._viewSnapshot[key]
			if value ~= nil then
				return value
			else
				return defaultValue
			end
		else
			return defaultValue
		end
	end)
end

--[=[
	Promises the full content for the datastore

	```lua
	dataStore:LoadAll():Then(function(data)
		print(data)
	end)
	```

	@param defaultValue any
	@return Promise<any>
]=]
function DataStoreStage.LoadAll(self: DataStoreStage, defaultValue)
	return self:PromiseViewUpToDate():Then(function()
		if self._viewSnapshot == nil then
			return defaultValue
		else
			return self._viewSnapshot
		end
	end)
end

--[=[
	Gets a sub-datastore that will write at the given key. This will have the same
	helper methods as any other data store object.

	```lua
	local dataStore = DataStore.new()

	local saveslot = dataStore:GetSubStore("saveslot0")
	saveslot:Store("Money", 0)
	```

	@param key string | number
	@return DataStoreStage
]=]
function DataStoreStage.GetSubStore(self: DataStoreStage, key: DataStoreStageKey)
	assert(type(key) == "string" or type(key) == "number", "Bad key")

	if self._stores[key] then
		return self._stores[key]
	end

	local maid = Maid.new()
	local newStore = maid:Add(DataStoreStage.new(key, self))

	-- TODO: Transfer delete tokens too?
	if type(self._baseDataSnapshot) == "table" and not Symbol.isSymbol(self._baseDataSnapshot) then
		local baseDataToTransfer = self._baseDataSnapshot[key]
		if baseDataToTransfer ~= nil then
			local newSnapshot = table.clone(self._baseDataSnapshot)
			newSnapshot[key] = nil
			newStore:MergeDiffSnapshot(baseDataToTransfer)
			self._baseDataSnapshot = table.freeze(newSnapshot)
		end
	end

	-- Transfer save data to substore
	if type(self._saveDataSnapshot) == "table" and not Symbol.isSymbol(self._saveDataSnapshot) then
		local saveDataToTransfer = self._saveDataSnapshot[key]

		if saveDataToTransfer ~= nil then
			local newSnapshot = table.clone(self._saveDataSnapshot)
			newSnapshot[key] = nil

			newStore:Overwrite(saveDataToTransfer)

			if DataStoreSnapshotUtils.isEmptySnapshot(newSnapshot) then
				self._saveDataSnapshot = nil
			else
				self._saveDataSnapshot = table.freeze(newSnapshot)
			end
		end
	end

	self._stores[key] = newStore
	self._maid[maid] = maid

	maid:GiveTask(newStore.Changed:Connect(function()
		self:_updateViewSnapshotAtKey(key)
	end))
	self:_updateViewSnapshotAtKey(key)

	return newStore
end

--[=[
	Explicitely deletes data at the key

	@param key string | number
]=]
function DataStoreStage.Delete(self: DataStoreStage, key: string)
	assert(type(key) == "string", "Bad key")

	self:_storeAtKey(key, DataStoreDeleteToken)
end

--[=[
	Queues up a wipe of all values. This will completely set the data to nil.
]=]
function DataStoreStage.Wipe(self: DataStoreStage)
	self:Overwrite(DataStoreDeleteToken)
end

--[=[
	Observes the current value for the stage itself

	If no key is passed than it will observe the whole view snapshot

	@param key string | number?
	@param defaultValue T?
	@return Observable<T>
]=]
function DataStoreStage.Observe(self: DataStoreStage, key, defaultValue)
	assert(type(key) == "string" or type(key) == "number" or key == nil, "Bad key")

	if key == nil then
		return Observable.new(function(sub)
			local maid = Maid.new()
			maid:GivePromise(self:LoadAll()):Then(function()
				-- Only connect once loaded
				maid:GiveTask(self.Changed:Connect(function(viewSnapshot)
					if viewSnapshot == nil then
						sub:Fire(defaultValue)
					else
						sub:Fire(viewSnapshot)
					end
				end))

				if self._viewSnapshot == nil then
					sub:Fire(defaultValue)
				else
					sub:Fire(self._viewSnapshot)
				end
			end, function(...)
				sub:Fail(...)
			end)

			return maid
		end)
	end

	return Observable.new(function(sub)
		local maid = Maid.new()

		maid:GiveTask(self._keySubscriptions:Observe(key):Subscribe(function(value)
			if value == nil then
				sub:Fire(defaultValue)
			else
				sub:Fire(value)
			end
		end, sub:GetFailComplete()))

		-- Load initially
		maid:GivePromise(self:Load(key, defaultValue)):Then(function(value)
			sub:Fire(value)
		end, function(...)
			sub:Fail(...)
		end)

		return maid
	end)
end

--[=[
	Adds a callback to be called before save. This may return a promise.

	@param callback function -- May return a promise
	@return function -- Call to remove
]=]
function DataStoreStage.AddSavingCallback(self: DataStoreStage, callback: DataStoreCallback?)
	assert(type(callback) == "function", "Bad callback")

	table.insert(self._savingCallbacks, callback)

	return function()
		if self.Destroy then
			self:RemoveSavingCallback(callback)
		end
	end
end

--[=[
	Removes a saving callback from the data store stage
	@param callback function
]=]
function DataStoreStage.RemoveSavingCallback(self: DataStoreStage, callback: DataStoreCallback?)
	assert(type(callback) == "function", "Bad callback")

	local index = table.find(self._savingCallbacks, callback)
	if index then
		table.remove(self._savingCallbacks, index)
	end
end

--[=[
	Gets an event that will fire off whenever something is stored at this level

	@return Signal
]=]
function DataStoreStage.GetTopLevelDataStoredSignal(self: DataStoreStage)
	return self.DataStored
end

--[=[
	Retrieves the full path of this datastore stage for diagnostic purposes.

	@return string
]=]
function DataStoreStage.GetFullPath(self: DataStoreStage): string
	if self._fullPath then
		return self._fullPath
	elseif self._loadParent then
		local fullPath = self._loadParent:GetFullPath() .. "." .. tostring(self._loadName)
		self._fullPath = fullPath
		return fullPath
	else
		local fullPath = tostring(self._loadName)
		self._fullPath = fullPath
		return fullPath
	end
end

--[=[
	Promises a list of keys in the data store stage

	@return Promise<{ string }>
]=]
function DataStoreStage.PromiseKeyList(self: DataStoreStage): Promise.Promise<{ string }>
	return self:PromiseKeySet():Then(function(keys)
		local list = {}
		for key, _ in keys do
			table.insert(list, key)
		end
		return list
	end)
end

--[=[
	Promises a set of keys in the data store stage

	@return Promise<{ [string]: true }>
]=]
function DataStoreStage.PromiseKeySet(self: DataStoreStage): Promise.Promise<{ [string]: true }>
	return self:PromiseViewUpToDate():Then(function()
		if type(self._viewSnapshot) == "table" then
			return Set.fromKeys(self._viewSnapshot)
		else
			return {}
		end
	end)
end

--[=[
	This will always prioritize our own view of the world over
	incoming data.

	:::tip
	This is a helper method that helps load diff data into the data store.
	:::

	@param diffSnapshot any
]=]
function DataStoreStage.MergeDiffSnapshot(self: DataStoreStage, diffSnapshot)
	self:_checkIntegrity()

	self._baseDataSnapshot = self:_updateStoresAndComputeBaseDataSnapshotFromDiffSnapshot(diffSnapshot)

	self:_updateViewSnapshot()
	self:_checkIntegrity()
end

--[=[
	Updates the base data to the saved / written data.

	This will always prioritize our own view of the world over
	incoming data.

	@param parentWriter DataStoreWriter
]=]
function DataStoreStage.MarkDataAsSaved(self: DataStoreStage, parentWriter: DataStoreWriter.DataStoreWriter)
	-- Update all children first
	for key, subwriter in pairs(parentWriter:GetSubWritersMap()) do
		local store = self._stores[key]
		if store then
			store:MarkDataAsSaved(subwriter)
		else
			warn("[DataStoreStage] - Store removed, but writer persists")
		end
	end

	local dataToSave = parentWriter:GetDataToSave()
	if self._saveDataSnapshot == DataStoreDeleteToken or dataToSave == DataStoreDeleteToken then
		if self._saveDataSnapshot == dataToSave then
			self._baseDataSnapshot = nil
			self._saveDataSnapshot = nil
		end
	elseif type(self._saveDataSnapshot) == "table" or type(dataToSave) == "table" then
		if type(self._saveDataSnapshot) == "table" and type(dataToSave) == "table" then
			local newSaveSnapshot = table.clone(self._saveDataSnapshot)
			local newBaseDataSnapshot
			if type(self._baseDataSnapshot) == "table" then
				newBaseDataSnapshot = table.clone(self._baseDataSnapshot)
			else
				newBaseDataSnapshot = {}
			end

			for key, value in dataToSave do
				local ourSnapshotValue = self._saveDataSnapshot[key]
				if Table.deepEquivalent(ourSnapshotValue, value) or ourSnapshotValue == nil then
					-- This shouldn't fire any event because our save data is matching
					newBaseDataSnapshot[key] =
						self:_updateStoresAndComputeBaseDataSnapshotValueFromDiffSnapshot(key, value)
					newSaveSnapshot[key] = nil
				end
			end

			self._baseDataSnapshot = table.freeze(newBaseDataSnapshot)

			if DataStoreSnapshotUtils.isEmptySnapshot(newSaveSnapshot) then
				self._saveDataSnapshot = nil
			else
				self._saveDataSnapshot = table.freeze(newSaveSnapshot)
			end
		end
	else
		assert(type(self._saveDataSnapshot) ~= "table", "Case is covered above")
		assert(self._saveDataSnapshot ~= DataStoreDeleteToken, "Case is covered above")
		assert(dataToSave ~= DataStoreDeleteToken, "Case is covered above")
		assert(type(dataToSave) ~= "table", "Case is covered above")

		-- In the none-table scenario move stuff
		if self._saveDataSnapshot == dataToSave then
			self._baseDataSnapshot = dataToSave
			self._saveDataSnapshot = nil
		end
	end

	self:_checkIntegrity()
end

--[=[
	Helper method that when invokes ensures the data view.

	:::tip
	This is a helper method. You probably want [DataStore.LoadAll] instead.
	:::

	@return Promise
]=]
function DataStoreStage.PromiseViewUpToDate(self: DataStoreStage)
	if not self._loadParent then
		error("[DataStoreStage.Load] - Failed to load, no loadParent!")
	end
	if not self._loadName then
		error("[DataStoreStage.Load] - Failed to load, no loadName!")
	end

	return self._loadParent:PromiseViewUpToDate()
end

--[=[
	Ovewrites the full stage with the data specified.

	:::tip
	Use this method carefully as it can lead to data loss in ways that a specific :Store() call
	on the right stage would do better.
	:::

	@param data any
]=]
function DataStoreStage.Overwrite(self: DataStoreStage, data)
	-- Ensure that we at least start loading (and thus the autosave loop) for write
	self:PromiseViewUpToDate()

	if data == nil then
		data = DataStoreDeleteToken
	end

	if type(data) == "table" and data ~= DataStoreDeleteToken then
		local newSaveSnapshot = {}

		local remaining = Set.fromKeys(self._stores)
		for key, store: any in self._stores do
			-- Update each store
			store:Overwrite(data[key])
		end

		for key, value in data do
			remaining[key] = nil
			if self._stores[key] then
				self._stores[key]:Overwrite(value)
			else
				newSaveSnapshot[key] = value
			end
		end

		for key, _ in remaining do
			self._stores[key]:Overwrite(DataStoreDeleteToken)
		end

		self._saveDataSnapshot = table.freeze(newSaveSnapshot)
	else
		for _, store: any in self._stores do
			store:Overwrite(DataStoreDeleteToken)
		end

		self._saveDataSnapshot = data
	end

	self:_updateViewSnapshot()
end

--[=[
	Ovewrites the full stage with the data specified. However, it will merge the data
	to help prevent data-loss.

	:::tip
	Use this method carefully as it can lead to data loss in ways that a specific :Store() call
	on the right stage would do better.
	:::

	@param data any
]=]
function DataStoreStage.OverwriteMerge(self: DataStoreStage, data)
	-- Ensure that we at least start loading (and thus the autosave loop) for write
	self:PromiseViewUpToDate()

	if type(data) == "table" and data ~= DataStoreDeleteToken then
		-- Note we explicitly don't wipe values here! Need delete token if we want to delete!
		for key, value in data do
			self:_storeAtKey(key, value)
		end
	else
		-- Non-tables
		self:Overwrite(data)
	end
end

--[=[
	Whenever the ValueObject changes, stores the resulting value in that entry.

	@param name string | number
	@param valueObj Instance -- ValueBase object to store on
	@return MaidTask -- Cleanup to remove this writer and free the key.
]=]
function DataStoreStage.StoreOnValueChange(self: DataStoreStage, name: DataStoreStageKey, valueObj)
	assert(type(name) == "string" or type(name) == "number", "Bad name")
	assert(typeof(valueObj) == "Instance" or (type(valueObj) == "table" and valueObj.Changed), "Bad valueObj")

	local maid = Maid.new()

	maid:GiveTask(valueObj.Changed:Connect(function()
		self:_storeAtKey(name, valueObj.Value)
	end))

	-- Hopefully this doesn't result in data-loss when writing as
	-- the user leaves.
	self._maid[maid] = maid
	maid:GiveTask(function()
		self._maid[maid] = nil
	end)

	return maid
end

--[=[
	If these is data not yet written then this will return true

	@return boolean
]=]
function DataStoreStage.HasWritableData(self: DataStoreStage): boolean
	if self._saveDataSnapshot ~= nil then
		return true
	end

	for name, store: any in self._stores do
		if not store.Destroy then
			warn(string.format("[DataStoreStage] - Substore %q destroyed", tostring(name)))
			continue
		end

		if store:HasWritableData() then
			return true
		end
	end

	return false
end

--[=[
	Constructs a writer which provides a snapshot of the current data state to write.

	:::tip
	This is automatically invoked during saving and is public so [DataStore] can invoke it.
	:::

	@return DataStoreWriter
]=]
function DataStoreStage.GetNewWriter(self: DataStoreStage): DataStoreWriter.DataStoreWriter
	self:_checkIntegrity()

	local writer = DataStoreWriter.new(self:GetFullPath())

	local fullBaseDataSnapshot = self:_createFullBaseDataSnapshot()

	if self._saveDataSnapshot ~= nil then
		writer:SetSaveDataSnapshot(self._saveDataSnapshot)
	end

	for key, store: any in self._stores do
		if not store.Destroy then
			warn(string.format("[DataStoreStage] - Substore %q destroyed", tostring(key)))
			continue
		end

		if store:HasWritableData() then
			writer:AddSubWriter(key, store:GetNewWriter())
		end
	end

	writer:SetFullBaseDataSnapshot(fullBaseDataSnapshot)

	return writer
end

--[=[
	Invokes all saving callbacks

	:::tip
	This is automatically invoked before saving and is public so [DataStore] can invoke it.
	:::

	@return Promise
]=]
function DataStoreStage.PromiseInvokeSavingCallbacks(self: DataStoreStage)
	local removingPromises: { Promise.Promise<()> } = {}

	for _, func in self._savingCallbacks do
		local result = func()
		if Promise.isPromise(result) then
			table.insert(removingPromises, result :: any)
		end
	end

	for _, substore: any in self._stores do
		local promise = substore:PromiseInvokeSavingCallbacks()
		if promise then
			table.insert(removingPromises, promise)
		end
	end

	return PromiseUtils.all(removingPromises)
end

function DataStoreStage._createFullBaseDataSnapshot(self: DataStoreStage)
	if self._baseDataSnapshot == DataStoreDeleteToken then
		error("BadDataSnapshot cannot be a delete token")
	elseif type(self._baseDataSnapshot) == "table" or self._baseDataSnapshot == nil then
		local newSnapshot
		if type(self._baseDataSnapshot) == "table" then
			newSnapshot = table.clone(self._baseDataSnapshot)
		else
			newSnapshot = {}
		end

		for key, store: any in self._stores do
			if not store.Destroy then
				warn(string.format("[DataStoreStage] - Substore %q destroyed", tostring(key)))
				continue
			end

			if not store:HasWritableData() then
				newSnapshot[key] = store:_createFullBaseDataSnapshot()
			end
		end

		if DataStoreSnapshotUtils.isEmptySnapshot(newSnapshot) then
			return nil
		else
			return table.freeze(newSnapshot)
		end
	else
		return self._baseDataSnapshot
	end
end

function DataStoreStage._updateStoresAndComputeBaseDataSnapshotFromDiffSnapshot(self: DataStoreStage, diffSnapshot)
	if diffSnapshot == DataStoreDeleteToken then
		return nil
	elseif type(diffSnapshot) == "table" then
		assert(not Symbol.isSymbol(diffSnapshot), "diffSnapshot should not be symbol")

		local newBaseDataSnapshot
		if type(self._baseDataSnapshot) == "table" then
			newBaseDataSnapshot = table.clone(self._baseDataSnapshot)
		else
			newBaseDataSnapshot = {}
		end

		-- Merge all of our newly downloaded data here into our base layer.
		for key, value in diffSnapshot do
			newBaseDataSnapshot[key] = self:_updateStoresAndComputeBaseDataSnapshotValueFromDiffSnapshot(key, value)
		end

		return table.freeze(newBaseDataSnapshot)
	elseif diffSnapshot == nil then
		return self._baseDataSnapshot
	else
		return diffSnapshot
	end
end

function DataStoreStage._updateStoresAndComputeBaseDataSnapshotValueFromDiffSnapshot(
	self: DataStoreStage,
	key: DataStoreStageKey,
	value
)
	assert(type(key) == "string" or type(key) == "number", "Bad key")

	if self._stores[key] then
		self._stores[key]:MergeDiffSnapshot(value)
		return nil
	elseif value == DataStoreDeleteToken then
		return nil
	elseif
		type(value) == "table"
		and type(self._baseDataSnapshot) == "table"
		and type(self._baseDataSnapshot[key]) == "table"
	then
		return self:_recurseMergeTable(self._baseDataSnapshot[key], value)
	else
		return value
	end
end

function DataStoreStage._recurseMergeTable(self: DataStoreStage, original, incoming)
	if incoming == DataStoreDeleteToken then
		return nil
	elseif type(incoming) == "table" and type(original) == "table" then
		-- Merge
		local newSnapshot = table.clone(original)

		-- Overwerite with merged values...
		for key, value in incoming do
			newSnapshot[key] = self:_recurseMergeTable(original[key], value)
		end

		return table.freeze(newSnapshot)
	else
		return incoming
	end
end

function DataStoreStage._updateViewSnapshot(self: DataStoreStage)
	self:_checkIntegrity()

	local newViewSnapshot = self:_computeNewViewSnapshot()

	if not Table.deepEquivalent(self._viewSnapshot, newViewSnapshot) then
		local previousViewSnapshot = self._viewSnapshot
		self._viewSnapshot = newViewSnapshot

		-- Fire off changed keys
		local changedKeys = self:_computeChangedKeys(previousViewSnapshot, newViewSnapshot)
		if next(changedKeys) ~= nil then
			if type(newViewSnapshot) == "table" then
				for key, _ in changedKeys do
					self._keySubscriptions:Fire(key, newViewSnapshot[key])
				end
			else
				for key, _ in changedKeys do
					self._keySubscriptions:Fire(key, nil)
				end
			end
		end

		self.Changed:Fire(newViewSnapshot)
	end

	self:_checkIntegrity()
end

function DataStoreStage._computeChangedKeys(_self: DataStoreStage, previousViewSnapshot, newViewSnapshot)
	-- Detect keys that changed
	if type(previousViewSnapshot) == "table" and type(newViewSnapshot) == "table" then
		local changedKeys = {}

		local keys = Set.union(Set.fromKeys(previousViewSnapshot), Set.fromKeys(newViewSnapshot))
		for key, _ in keys do
			if not Table.deepEquivalent(previousViewSnapshot[key], newViewSnapshot[key]) then
				changedKeys[key] = true
			end
		end

		return changedKeys
	elseif type(newViewSnapshot) == "table" then
		-- Swap to table, all keys change
		return Set.fromKeys(newViewSnapshot)
	elseif type(previousViewSnapshot) == "table" then
		-- Swap from table, all keys change
		return Set.fromKeys(previousViewSnapshot)
	else
		return {}
	end
end

function DataStoreStage._updateViewSnapshotAtKey(self: DataStoreStage, key)
	assert(type(key) == "string" or type(key) == "number", "Bad key")

	if type(self._viewSnapshot) ~= "table" then
		self:_updateViewSnapshot()
		return
	end

	local newValue = self:_computeViewValueForKey(key)
	if self._viewSnapshot[key] == newValue then
		return
	end

	local newSnapshot = table.clone(self._viewSnapshot)
	newSnapshot[key] = newValue
	newSnapshot = table.freeze(newSnapshot)

	self._viewSnapshot = newSnapshot
	self._keySubscriptions:Fire(key, newValue)
	self.Changed:Fire(newSnapshot)

	self:_checkIntegrity()
end

function DataStoreStage._computeNewViewSnapshot(self: DataStoreStage)
	-- This prioritizes save data first, then stores, then base data

	if self._saveDataSnapshot == DataStoreDeleteToken then
		return nil
	elseif self._saveDataSnapshot == nil or type(self._saveDataSnapshot) == "table" then
		-- Compute a new view

		-- Start with base data
		local newView
		if type(self._baseDataSnapshot) == "table" then
			newView = table.clone(self._baseDataSnapshot)
		else
			newView = {}
		end

		-- Add in stores
		for key, store in self._stores do
			newView[key] = store._viewSnapshot
		end

		-- Then finally save data
		if type(self._saveDataSnapshot) == "table" then
			for key, value in self._saveDataSnapshot do
				if value == DataStoreDeleteToken then
					newView[key] = nil
				else
					newView[key] = value
				end
			end
		end

		if
			next(newView) == nil
			and not (type(self._baseDataSnapshot) == "table" or type(self._saveDataSnapshot) == "table")
		then
			-- We have no reason to be a table, make sure we return nil
			return nil
		end

		return table.freeze(newView)
	else
		assert(self._saveDataSnapshot ~= nil, "Bad _saveDataSnapshot")
		assert(type(self._saveDataSnapshot) ~= "table", "Bad self._saveDataSnapshot")

		-- If save data isn't nil or a table then we are to return the save table
		return self._saveDataSnapshot
	end
end

function DataStoreStage._computeViewValueForKey(self: DataStoreStage, key)
	-- This prioritizes save data first, then stores, then base data

	if self._saveDataSnapshot == DataStoreDeleteToken then
		return nil
	elseif self._saveDataSnapshot == nil or type(self._saveDataSnapshot) == "table" then
		if type(self._saveDataSnapshot) == "table" then
			if self._saveDataSnapshot[key] ~= nil then
				local value = self._saveDataSnapshot[key]
				if value == DataStoreDeleteToken then
					return nil
				else
					return value
				end
			end
		end

		if self._stores[key] then
			local value = self._stores[key]._viewSnapshot
			if value == DataStoreDeleteToken then
				return nil
			else
				return value
			end
		end

		if type(self._baseDataSnapshot) == "table" then
			if self._baseDataSnapshot[key] ~= nil then
				return self._baseDataSnapshot[key]
			end
		end

		return nil
	else
		-- If save data isn't nil or a table then we are to return nil.
		return nil
	end
end

-- Stores the data for overwrite.
function DataStoreStage._storeAtKey(self: DataStoreStage, key, value)
	assert(type(key) == "string" or type(key) == "number", "Bad key")
	assert(value ~= nil, "Bad value")

	local deepClonedSaveValue
	if type(value) == "table" then
		deepClonedSaveValue = table.freeze(Table.deepCopy(value))
	else
		deepClonedSaveValue = value
	end

	if self._stores[key] then
		self._stores[key]:Overwrite(value)
		return
	end

	local swappedSaveSnapshotType = false
	local newSnapshot

	if type(self._saveDataSnapshot) == "table" then
		newSnapshot = table.clone(self._saveDataSnapshot)
	else
		swappedSaveSnapshotType = true
		newSnapshot = {}
	end

	newSnapshot[key] = deepClonedSaveValue

	self._saveDataSnapshot = table.freeze(newSnapshot)

	self.DataStored:Fire()

	if swappedSaveSnapshotType then
		self:_updateViewSnapshot()
	else
		self:_updateViewSnapshotAtKey(key)
	end
	self:_checkIntegrity()
end

function DataStoreStage._checkSnapshotIntegrity(_self: DataStoreStage, label, result)
	assert(type(label) == "string", "Bad label")

	if not SLOW_INTEGRITY_CHECK_ENABLED then
		return
	end

	if result == DataStoreDeleteToken then
		error(string.format("%s should not be a DataStoreDeleteToken", label))
	end

	local function recurse(innerLabel: string, value)
		if type(value) ~= "table" then
			return
		end

		for key, item in value do
			local keyLabel = innerLabel .. "." .. tostring(key)

			if not (type(key) == "string" or type(key) == "number") then
				error(string.format("%s should be a number or string", keyLabel))
			end

			if item == DataStoreDeleteToken then
				error(string.format("%s should not contain a DataStoreDeleteToken", keyLabel))
			end

			if type(item) == "table" then
				recurse(keyLabel, item)
			end
		end
	end

	recurse(label, result)
end

function DataStoreStage._checkIntegrity(self: DataStoreStage)
	if not SLOW_INTEGRITY_CHECK_ENABLED then
		return
	end

	assert(self._baseDataSnapshot ~= DataStoreDeleteToken, "BaseDataSnapshot should not be DataStoreDeleteToken")
	assert(self._viewSnapshot ~= DataStoreDeleteToken, "ViewSnapshot should not be DataStoreDeleteToken")

	if type(self._baseDataSnapshot) == "table" then
		assert(table.isfrozen(self._baseDataSnapshot), "Base snapshot should be frozen")
		self:_checkSnapshotIntegrity("self._baseDataSnapshot", self._baseDataSnapshot)
	end

	if type(self._saveDataSnapshot) == "table" then
		assert(table.isfrozen(self._saveDataSnapshot), "Save snapshot should be frozen")
	end

	if type(self._viewSnapshot) == "table" then
		assert(table.isfrozen(self._viewSnapshot), "View snapshot should be frozen")
		self:_checkSnapshotIntegrity("self._viewSnapshot", self._viewSnapshot)
	end

	for key, _ in self._stores do
		if type(self._baseDataSnapshot) == "table" and self._baseDataSnapshot[key] ~= nil then
			error(string.format("[DataStoreStage] - Duplicate baseData at key %q", tostring(key)))
		end

		if type(self._saveDataSnapshot) == "table" and self._saveDataSnapshot[key] ~= nil then
			error(string.format("[DataStoreStage] - Duplicate saveData at key %q", tostring(key)))
		end
	end
end

return DataStoreStage