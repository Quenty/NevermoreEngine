--- Wraps the datastore object to provide async cached loading and saving
-- @classmod DataStore

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local DataStoreStage = require("DataStoreStage")
local DataStorePromises = require("DataStorePromises")
local Promise = require("Promise")
local Table = require("Table")
local Maid = require("Maid")
local Signal = require("Signal")

local DataStore = setmetatable({}, DataStoreStage)
DataStore.ClassName = "DataStore"
DataStore.__index = DataStore

function DataStore.new(dataStore, key)
	local self = setmetatable(DataStoreStage.new(), DataStore)

	self._key = key or error("No key")
	self._dataStore = dataStore or error("No dataStore")

	self.Saving = Signal.new() -- :Fire(promise)

	return self
end

function DataStore:DidLoadFail()
	if not self._loadPromise then
		return false
	end

	if self._loadPromise:IsRejected() then
		return true
	end

	return false
end

function DataStore:PromiseLoadSuccessful()
	return self._maid:GivePromise(self:_promiseLoad()):Then(function()
		return true
	end):Catch(function()
		return false
	end)
end

-- Saves all stored data
function DataStore:Save()
	if self:DidLoadFail() then
		warn("[DataStore] - Not saving, failed to load")
		return Promise.rejected("Load not successful, not saving")
	end

	if not self:HasWritableData() then
		-- Nothing to save, don't update anything
		print("[DataStore.Save] - Not saving, nothing staged")
		return Promise.fulfilled(nil)
	end

	return self:_saveData(self:GetNewWriter())
end

-- Loads data. This returns the originally loaded data.
function DataStore:Load(name, defaultValue)
	return self:_promiseLoad()
		:Then(function(data)
			if data[name] == nil then
				return defaultValue
			else
				return data[name]
			end
		end)
end

function DataStore:_saveData(writer)
	local maid = Maid.new()

	local promise;
	promise = DataStorePromises.UpdateAsync(self._dataStore, self._key, function(data)
		if promise:IsRejected() then
			-- Cancel if we're already overwritten
			return nil
		end

		data = data or {}

		writer:WriteMerge(data)

		return data
	end):Catch(function(err)
		warn("[DataStore] - Failed to UpdateAsync data", err)
	end)
	maid:GivePromise(promise)

	self._maid._saveMaid = maid

	self.Saving:Fire(promise)

	return promise
end

function DataStore:_promiseLoad()
	if self._loadPromise then
		return self._loadPromise
	end

	self._loadPromise = DataStorePromises.GetAsync(self._dataStore, self._key):Then(function(data)
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
	self._maid:GivePromise(self._loadPromise)

	return self._loadPromise
end

return DataStore