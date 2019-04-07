--- Wraps the datastore object to provide async cached loading and saving
-- @classmod DataStore

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local DataStoreDeleteToken = require("DataStoreDeleteToken")
local DataStorePromises = require("DataStorePromises")
local DataStoreStage = require("DataStoreStage")
local Maid = require("Maid")
local Promise = require("Promise")
local Signal = require("Signal")

local DEBUG_WRITING = false

local AUTO_SAVE_TIME = 60*5
local CHECK_DIVISION = 15
local JITTER = 20 -- Randomly assign jitter so if a ton of players join at once we don't hit the datastore at once

local DataStore = setmetatable({}, DataStoreStage)
DataStore.ClassName = "DataStore"
DataStore.__index = DataStore

function DataStore.new(robloxDataStore, key)
	local self = setmetatable(DataStoreStage.new(), DataStore)

	self._key = key or error("No key")
	self._robloxDataStore = robloxDataStore or error("No robloxDataStore")

	self.Saving = Signal.new() -- :Fire(promise)

	spawn(function()
		while self.Destroy do
			for _=1, CHECK_DIVISION do
				wait(AUTO_SAVE_TIME/CHECK_DIVISION)
				if not self.Destroy then
					break
				end
			end

			if not self.Destroy then
				break
			end

			-- Apply additional jitter on auto-save
			wait(math.random(1, JITTER))

			if not self.Destroy then
				break
			end

			self:Save()
		end
	end)

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
	end, function()
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
		if DEBUG_WRITING then
			print("[DataStore.Save] - Not saving, nothing staged")
		end
		return Promise.resolved(nil)
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
		assert(data ~= DataStoreDeleteToken, "Cannot delete from UpdateAsync")

		if DEBUG_WRITING then
			print("[DataStore] - Writing", game:GetService("HttpService"):JSONEncode(data))
		end

		return data
	end, function(err)
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

	self._loadPromise = self._maid:GivePromise(DataStorePromises.GetAsync(self._robloxDataStore, self._key)
		:Then(function(data)
			if data == nil then
				return {}
			elseif type(data) == "table" then
				return data
			else
				return Promise.rejected("Failed to load data. Wrong type '" .. type(data) .. "'")
			end
		end, function(err)
			-- Log:
			warn("[DataStore] - Failed to GetAsync data", err)
			return Promise.rejected(err)
		end))

	return self._loadPromise
end

return DataStore