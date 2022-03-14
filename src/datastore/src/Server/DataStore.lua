--[=[
	Wraps the datastore object to provide async cached loading and saving. See [DataStoreStage] for more API.

	Has the following features
	* Automatic save
	* Jitter
	* De-duplication (only updates data it needs)

	```lua
	local playerMoneyValue = Instance.new("IntValue")
	playerMoneyValue.Value = 0

	local dataStore = DataStore.new(DataStoreService:GetDataStore("test"), test-store")
	dataStore:Load("money", 0):Then(function(money)
		playerMoneyValue.Value = money
		dataStore:StoreOnValueChange("money", playerMoneyValue)
	end):Catch(function()
		-- TODO: Notify player
	end)

	```

	@server
	@class DataStore
]=]

local require = require(script.Parent.loader).load(script)

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

--[=[
	Constructs a new DataStore. See [DataStoreStage] for more API.
	@param robloxDataStore DataStore
	@param key string
]=]
function DataStore.new(robloxDataStore, key)
	local self = setmetatable(DataStoreStage.new(), DataStore)

	self._key = key or error("No key")
	self._robloxDataStore = robloxDataStore or error("No robloxDataStore")

--[=[
	Prop that fires when saving. Promise will resolve once saving is complete.
	@prop Saving Signal<Promise>
	@within DataStore
]=]
	self.Saving = Signal.new() -- :Fire(promise)
	self._maid:GiveTask(self.Saving)

	task.spawn(function()
		while self.Destroy do
			for _=1, CHECK_DIVISION do
				task.wait(AUTO_SAVE_TIME/CHECK_DIVISION)
				if not self.Destroy then
					break
				end
			end

			if not self.Destroy then
				break
			end

			-- Apply additional jitter on auto-save
			task.wait(math.random(1, JITTER))

			if not self.Destroy then
				break
			end

			self:Save()
		end
	end)

	return self
end

--[=[
	Returns the full path for the datastore
	@return string
]=]
function DataStore:GetFullPath()
	return ("RobloxDataStore@%s"):format(self._key)
end

--[=[
	Returns whether the datastore failed.
	@return boolean
]=]
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

--[=[
	Saves all stored data.
	@return Promise
]=]
function DataStore:Save()
	if self:DidLoadFail() then
		warn("[DataStore] - Not saving, failed to load")
		return Promise.rejected("Load not successful, not saving")
	end

	if DEBUG_WRITING then
		print("[DataStore.Save] - Starting save routine")
	end

	-- Avoid constructing promises for every callback down the datastore
	-- upon save.
	return (self:_promiseInvokeSavingCallbacks() or Promise.resolved())
		:Then(function()
			if not self:HasWritableData() then
				-- Nothing to save, don't update anything
				if DEBUG_WRITING then
					print("[DataStore.Save] - Not saving, nothing staged")
				end
				return nil
			else
				return self:_saveData(self:GetNewWriter())
			end
		end)
end

--[=[
	Loads data. This returns the originally loaded data.
	@param keyName string
	@param defaultValue any?
	@return any?
]=]
function DataStore:Load(keyName, defaultValue)
	return self:_promiseLoad()
		:Then(function(data)
			return self:_afterLoadGetAndApplyStagedData(keyName, data, defaultValue)
		end)
end

function DataStore:_saveData(writer)
	local maid = Maid.new()

	local promise = Promise.new()
	promise:Resolve(maid:GivePromise(DataStorePromises.updateAsync(self._robloxDataStore, self._key, function(data)
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

	if self.Saving.Destroy then
		self.Saving:Fire(promise)
	end

	return promise
end

function DataStore:_promiseLoad()
	if self._loadPromise then
		return self._loadPromise
	end

	self._loadPromise = self._maid:GivePromise(DataStorePromises.getAsync(self._robloxDataStore, self._key)
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