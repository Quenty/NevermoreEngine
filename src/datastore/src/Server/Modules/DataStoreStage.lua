--[=[
	Provides a data storage facility with an ability to get sub-stores. So you can write
	directly to this store, overwriting all children, or you can have more partial control
	at children level. This minimizes accidently overwriting.
	The big cost here is that we may leave keys that can't be removed.

	@server
	@class DataStoreStage
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local DataStoreDeleteToken = require("DataStoreDeleteToken")
local DataStoreWriter = require("DataStoreWriter")
local Maid = require("Maid")
local Promise = require("Promise")
local PromiseUtils = require("PromiseUtils")
local Signal = require("Signal")
local Table = require("Table")
local Observable = require("Observable")
local ObservableSubscriptionTable = require("ObservableSubscriptionTable")

local DataStoreStage = setmetatable({}, BaseObject)
DataStoreStage.ClassName = "DataStoreStage"
DataStoreStage.__index = DataStoreStage

--[=[
	Constructs a new DataStoreStage to load from. Prefer to use DataStore because this doesn't
	have any way to retrieve this.
	@param loadName string
	@param loadParent DataStoreStage?
	@return DataStoreStage
]=]
function DataStoreStage.new(loadName, loadParent)
	local self = setmetatable(BaseObject.new(), DataStoreStage)

	-- LoadParent is optional, used for loading
	self._loadName = loadName
	self._loadParent = loadParent

	self._savingCallbacks = {} -- [func, ...]
	self._takenKeys = {} -- [name] = true
	self._stores = {} -- [name] = dataSubStore

	self._subsTable = ObservableSubscriptionTable.new()
	self._maid:GiveTask(self._subsTable)

	return self
end

-- Also returns nil for speedyness
function DataStoreStage:_promiseInvokeSavingCallbacks()
	if not next(self._savingCallbacks) then
		return Promise.resolved()
	end

	local removingPromises = {}
	for _, func in pairs(self._savingCallbacks) do
		local result = func()
		if Promise.isPromise(result) then
			table.insert(removingPromises, result)
		end
	end

	for _, substore in pairs(self._stores) do
		local promise = substore:_promiseInvokeSavingCallbacks()
		if promise then
			table.insert(removingPromises, promise)
		end
	end

	return PromiseUtils.all(removingPromises)
end

--[=[
	Adds a callback to be called before save. This may return a promise.
	@param callback function -- May return a promise
	@return function -- Call to remove
]=]
function DataStoreStage:AddSavingCallback(callback)
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
function DataStoreStage:RemoveSavingCallback(callback)
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
function DataStoreStage:GetTopLevelDataStoredSignal()
	if self._topLevelStoreSignal then
		return self._topLevelStoreSignal
	end

	self._topLevelStoreSignal = Signal.new()
	self._maid:GiveTask(self._topLevelStoreSignal)
	return self._topLevelStoreSignal
end

--[=[
	Retrieves the full path of this datastore stage for diagnostic purposes.
	@return string
]=]
function DataStoreStage:GetFullPath()
	if self._loadParent then
		return self._loadParent:GetFullPath() .. "." .. tostring(self._loadName)
	else
		return tostring(self._loadName)
	end
end

--[=[
	Loads the data at the `name`.

	@param name string | number
	@param defaultValue T?
	@return Promise<T>
]=]
function DataStoreStage:Load(name, defaultValue)
	assert(type(name) == "string" or type(name) == "number", "Bad name")

	if self._dataToSave and self._dataToSave[name] ~= nil then
		if self._dataToSave[name] == DataStoreDeleteToken then
			return Promise.resolved(defaultValue)
		else
			return Promise.resolved(self._dataToSave[name])
		end
	end

	return self:_promiseLoadParentContent():Then(function(data)
		return self:_afterLoadGetAndApplyStagedData(name, data, defaultValue)
	end)
end

function DataStoreStage:_mergeNewDataFromWriter(writer)
	-- TODO: Merge all of our newly downloaded data here into our base layer.

	-- TODO: Fire off events

	-- TODO: If the data matches our "write" data then mark the transaction as
	--       complete so we don't sync again with updateAsync. Set self._dataToSave to nil.
end

--[=[
	Observes the current value for the stage itself

	@param name string | number
	@param defaultValue T?
	@return Observable<T>
]=]
function DataStoreStage:Observe(name, defaultValue)
	assert(type(name) == "string" or type(name) == "number", "Bad name")

	return Observable.new(function(sub)
		local maid = Maid.new()

		maid:GiveTask(self._subsTable:Observe(name):Subscribe(sub:GetFireFailComplete()))

		-- Load initially
		maid:GivePromise(self:Load(name, defaultValue))
			:Then(function(value)
				sub:Fire(value)
			end, function(...)
				sub:Fail(...)
			end)

		return maid
	end)
end

-- Protected!
function DataStoreStage:_afterLoadGetAndApplyStagedData(name, data, defaultValue)
	assert(type(name) == "string" or type(name) == "number", "Bad name")

	if self._dataToSave and self._dataToSave[name] ~= nil then
		if self._dataToSave[name] == DataStoreDeleteToken then
			return defaultValue
		else
			return self._dataToSave[name]
		end
	elseif self._stores[name] then
		if self._stores[name]:HasWritableData() then
			local writer = self._stores[name]:GetNewWriter()
			local original = Table.deepCopy(data[name] or {})
			writer:WriteMerge(original, false)
			return original
		end
	end

	if data[name] == nil then
		return defaultValue
	else
		return data[name]
	end
end

--[=[
	Explicitely deletes data at the key

	@param name string | number
]=]
function DataStoreStage:Delete(name)
	assert(type(name) == "string", "Bad name")

	if self._takenKeys[name] then
		error(("[DataStoreStage] - Already have a writer for %q"):format(name))
	end

	self:_doStore(name, DataStoreDeleteToken)
end

--[=[
	Queues up a wipe of all values. Data must load before it can be wiped.
]=]
function DataStoreStage:Wipe()
	return self._loadParent:Load(self._loadName, {})
		:Then(function(data)
			for key, _ in pairs(data) do
				if self._stores[key] then
					self._stores[key]:Wipe()
				else
					self:_doStore(key, DataStoreDeleteToken)
				end
			end
		end)
end

--[=[
	Promises a list of keys in the data store stage

	@return Promise<{ string }>
]=]
function DataStoreStage:PromiseKeyList()
	return self:PromiseKeySet()
		:Then(function(keys)
			local list = {}
			for key, _ in pairs(keys) do
				table.insert(list, key)
			end
			return list
		end)
end

--[=[
	Promises a set of keys in the data store stage

	@return Promise<{ [string]: true }>
]=]
function DataStoreStage:PromiseKeySet()
	return self:_promiseLoadParentContent():Then(function(data)
		local keySet = {}

		for key, value in pairs(data) do
			if value ~= DataStoreDeleteToken then
				keySet[key] = true
			end
		end

		if self._dataToSave then
			for key, value in pairs(self._dataToSave) do
				if value ~= DataStoreDeleteToken then
					keySet[key] = true
				end
			end
		end

		-- Otherwise we assume previous data would have it
		for key, store in pairs(self._stores) do
			if store:HasWritableData() then
				keySet[key] = true
			end
		end

		return keySet
	end)
end

--[=[
	Promises the full content for the datastore

	@return Promise<any>
]=]
function DataStoreStage:LoadAll()
	return self:_promiseLoadParentContent():Then(function(data)
		local result = {}

		for key, value in pairs(data) do
			if value == DataStoreDeleteToken then
				result[key] = nil
			elseif type(value) == "table" then
				result[key] = Table.deepCopy(value)
			else
				result[key] = value
			end
		end

		if self._dataToSave then
			for key, value in pairs(self._dataToSave) do
				if value == DataStoreDeleteToken then
					result[key] = nil
				elseif type(value) == "table" then
					result[key] = Table.deepCopy(value)
				else
					result[key] = value
				end
			end
		end

		for key, store in pairs(self._stores) do
			if store:HasWritableData() then
				local writer = store:GetNewWriter()
				local original = Table.deepCopy(result[key] or {})
				writer:WriteMerge(original, false)
			end
		end

		return result
	end)
end

function DataStoreStage:_promiseLoadParentContent()
	if not self._loadParent then
		error("[DataStoreStage.Load] - Failed to load, no loadParent!")
	end
	if not self._loadName then
		error("[DataStoreStage.Load] - Failed to load, no loadName!")
	end

	return self._loadParent:Load(self._loadName, {})
end

--[=[
	Stores the value, firing off events and queuing the item
	for save.

	@param name string | number
	@param value string
]=]
function DataStoreStage:Store(name, value)
	assert(type(name) == "string", "Bad name")

	if self._takenKeys[name] then
		error(("[DataStoreStage] - Already have a writer for %q"):format(name))
	end

	if value == nil then
		value = DataStoreDeleteToken
	end

	self:_doStore(name, value)
end

--[=[
	Gets a sub-datastore that will write at the given name point

	@param name string | number
	@return DataStoreStage
]=]
function DataStoreStage:GetSubStore(name)
	assert(type(name) == "string" or type(name) == "number", "Bad name")

	if self._stores[name] then
		return self._stores[name]
	end

	if self._takenKeys[name] then
		error(("[DataStoreStage.GetSubStore] - Already have a writer for %q"):format(name))
	end

	local newStore = DataStoreStage.new(name, self)
	self._takenKeys[name] = true
	self._maid:GiveTask(newStore)

	self._stores[name] = newStore

	return newStore
end

--[=[
	Whenever the ValueObject changes, stores the resulting value in that entry.

	@param name string | number
	@param valueObj Instance -- ValueBase object to store on
	@return MaidTask -- Cleanup to remove this writer and free the key.
]=]
function DataStoreStage:StoreOnValueChange(name, valueObj)
	assert(type(name) == "string" or type(name) == "number", "Bad name")
	assert(typeof(valueObj) == "Instance" or (type(valueObj) == "table" and valueObj.Changed), "Bad valueObj")

	if self._takenKeys[name] then
		error(("[DataStoreStage] - Already have a writer for %q"):format(name))
	end

	local maid = Maid.new()

	self._takenKeys[name] = true
	maid:GiveTask(function()
		self._takenKeys[name] = nil
	end)

	maid:GiveTask(valueObj.Changed:Connect(function()
		self:_doStore(name, valueObj.Value)
	end))

	return maid
end

--[=[
	If these is data not yet written then this will return true

	@return boolean
]=]
function DataStoreStage:HasWritableData()
	if self._dataToSave then
		return true
	end

	for name, store in pairs(self._stores) do
		if not store.Destroy then
			warn(("[DataStoreStage] - Substore %q destroyed"):format(name))
			continue
		end

		if store:HasWritableData() then
			return true
		end
	end

	return false
end

--[=[
	Constructs a writer which provides a snapshot of the current data state to write

	@return DataStoreWriter
]=]
function DataStoreStage:GetNewWriter()
	local writer = DataStoreWriter.new()
	if self._dataToSave then
		writer:SetRawData(self._dataToSave)
	end

	for name, store in pairs(self._stores) do
		if not store.Destroy then
			warn(("[DataStoreStage] - Substore %q destroyed"):format(name))
			continue
		end

		if store:HasWritableData() then
			writer:AddWriter(name, store:GetNewWriter())
		end
	end

	return writer
end

-- Stores the data for overwrite.
function DataStoreStage:_doStore(name, value)
	assert(type(name) == "string" or type(name) == "number", "Bad name")
	assert(value ~= nil, "Bad value")

	local newValue
	if value == DataStoreDeleteToken then
		newValue = DataStoreDeleteToken
	elseif type(value) == "table" then
		newValue = Table.deepCopy(value)
	else
		newValue = value
	end

	if not self._dataToSave then
		self._dataToSave = {}
	end

	self._dataToSave[name] = newValue
	if self._topLevelStoreSignal then
		self._topLevelStoreSignal:Fire()
	end

	if newValue == DataStoreDeleteToken then
		self._subsTable:Fire(name, nil)
	else
		self._subsTable:Fire(name, newValue)
	end
end


return DataStoreStage