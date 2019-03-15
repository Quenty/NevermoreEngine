--- Wraps the datastore object to provide async cached loading and saving
-- @classmod DataStore

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local DataStorePromises = require("DataStorePromises")
local Promise = require("Promise")
local Table = require("Table")
local Maid = require("Maid")
local Signal = require("Signal")

local DataStore = setmetatable({}, BaseObject)
DataStore.ClassName = "DataStore"
DataStore.__index = DataStore

function DataStore.new(dataStore, key)
	local self = setmetatable(BaseObject.new(), DataStore)

	self._key = key or error("No key")
	self._dataStore = dataStore or error("No dataStore")
	self._writers = {}

	self.Saving = Signal.new() -- :Fire(promise)

	return self
end

function DataStore:IsLoadSuccessful()
	return self._promiseData and self._promiseData:IsFulfilled()
end

function DataStore:PromiseLoadSuccessful()
	return self._maid:GivePromise(self:_promiseData()):Then(function(data)
		return true
	end)
end

function DataStore:AddWriteCallback(name, func)
	assert(type(name) == "string")
	assert(type(func) == "function")
	assert(not self._writers[name])

	self._writers[name] = func
end

function DataStore:Save()
	if not self:IsLoadSuccessful() then
		warn("[DataStore] - Not saving, failed to load")
		return Promise.rejected("Load not successful, not saving")
	end

	local data = {}

	for name, writer in pairs(self._writers) do
		data[name] = writer()
	end

	return self:_saveData(data)
end

function DataStore:Load(name, defaultValue)
	return self:_promiseData()
		:Then(function(data)
			if data[name] == nil then
				return defaultValue
			else
				return data[name]
			end
		end)
end

function DataStore:_saveData(saveDataRaw)
	assert(type(saveDataRaw) == "table")

	local maid = Maid.new()

	local saveDataCopy = Table.DeepCopy(saveDataRaw)
	local promise;
	promise = DataStorePromises.UpdateAsync(self._dataStore, self._key, function(data)
		if promise:IsRejected() then
			-- Cancel if we're already overwritten
			return nil
		end

		for key, value in pairs(saveDataCopy) do
			data[key] = value
		end

		return data
	end):Catch(function(err)
		warn("[DataStore] - Failed to UpdateAsync data", err)
	end)
	maid:GivePromise(self._promiseData)

	self._maid._saveMaid = maid

	self.Saving:Fire(promise)

	return promise
end

function DataStore:_promiseData(breakCache)
	if self._promiseData and (not breakCache) then
		return self._promiseData
	end

	self._promiseData = DataStorePromises.GetAsync(self._dataStore, self._key):Then(function(data)
		if data == nil then
			return {}
		elseif type(data) == "table" then
			return data
		else
			return Promise.rejected("Failed to load data. Wrong type '" .. type(data) .. "'")
		end
	end):Catch(function(err)
		warn("[DataStore] - Failed to GetAsync data", err)
	end)
	self._maid:GivePromise(self._promiseData)

	return self._promiseData
end

return DataStore