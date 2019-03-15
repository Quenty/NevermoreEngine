--- Wraps the datastore object to provide async cached loading and saving
-- @classmod DataStore

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local DataStoreStage = require("DataStoreStage")
local DataStorePromises = require("DataStorePromises")
local Promise = require("Promise")
local Maid = require("Maid")
local Signal = require("Signal")

local DEBUG_WRITING = false

local DataStore = setmetatable({}, DataStoreStage)
DataStore.ClassName = "DataStore"
DataStore.__index = DataStore

function DataStore.new(robloxDataStore, key)
	local self = setmetatable(DataStoreStage.new(), DataStore)

	self._key = key or error("No key")
	self._robloxDataStore = robloxDataStore or error("No robloxDataStore")

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

	local promise = Promise.new()
	promise:Resolve(maid:GivePromise(DataStorePromises.UpdateAsync(self._robloxDataStore, self._key, function(data)
		if promise:IsRejected() then
			-- Cancel if we have another request
			return nil
		end

		data = writer:WriteMerge(data or {})

		if DEBUG_WRITING then
			print("Writing", game:GetService("HttpService"):JSONEncode(data))
		end

		return data
	end):Catch(function(err)
		-- Might be caused by Maid rejecting state
		warn("[DataStore] - Failed to UpdateAsync data", err)
		return Promise.rejected(err)
	end)))

	self._maid._saveMaid = maid

	self.Saving:Fire(promise)

	return promise
end

function DataStore:_promiseLoad()
	if self._loadPromise then
		return self._loadPromise
	end

	self._loadPromise = DataStorePromises.GetAsync(self._robloxDataStore, self._key):Then(function(data)
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