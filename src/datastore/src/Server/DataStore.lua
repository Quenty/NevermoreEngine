--[=[
	Wraps the datastore object to provide async cached loading and saving. See [DataStoreStage] for more API.

	Has the following features
	* Automatic saving every 5 minutes
	* Jitter (doesn't save all at the same time)
	* De-duplication (only updates data it needs)
	* Battle tested across multiple top games.

	```lua
	local playerMoneyValue = Instance.new("IntValue")
	playerMoneyValue.Value = 0

	local dataStore = DataStore.new(DataStoreService:GetDataStore("test"), "test-store")
	dataStore:Load("money", 0):Then(function(money)
		playerMoneyValue.Value = money
		dataStore:StoreOnValueChange("money", playerMoneyValue)
	end):Catch(function()
		-- TODO: Notify player
	end)
	```

	To use a datastore for a player, it's recommended you use the [PlayerDataStoreService]. This looks
	something like this. See [ServiceBag] for more information on service initialization.

	```lua
	local serviceBag = ServiceBag.new()
	local playerDataStoreService = serviceBag:GetService(require("PlayerDataStoreService"))

	serviceBag:Init()
	serviceBag:Start()

	local topMaid = Maid.new()

	local function handlePlayer(player)
		local maid = Maid.new()

		local playerMoneyValue = Instance.new("IntValue")
		playerMoneyValue.Name = "Money"
		playerMoneyValue.Value = 0
		playerMoneyValue.Parent = player

		maid:GivePromise(playerDataStoreService:PromiseDataStore(player)):Then(function(dataStore)
			maid:GivePromise(dataStore:Load("money", 0))
				:Then(function(money)
					playerMoneyValue.Value = money
					maid:GiveTask(dataStore:StoreOnValueChange("money", playerMoneyValue))
				end)
		end)

		topMaid[player] = maid
	end
	Players.PlayerAdded:Connect(handlePlayer)
	Players.PlayerRemoving:Connect(function(player)
		topMaid[player] = nil
	end)
	for _, player in pairs(Players:GetPlayers()) do
		task.spawn(handlePlayer, player)
	end
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
local Math = require("Math")

local DEBUG_WRITING = true

local DEFAULT_AUTO_SAVE_TIME_SECONDS = 60*5
local DEFAULT_JITTER_PROPORTION = 0.1 -- Randomly assign jitter so if a ton of players join at once we don't hit the datastore at once

local DataStore = setmetatable({}, DataStoreStage)
DataStore.ClassName = "DataStore"
DataStore.__index = DataStore

--[=[
	Constructs a new DataStore. See [DataStoreStage] for more API.
	@param robloxDataStore DataStore
	@param key string
	@return DataStore
]=]
function DataStore.new(robloxDataStore, key)
	local self = setmetatable(DataStoreStage.new(), DataStore)

	self._key = key or error("No key")
	self._robloxDataStore = robloxDataStore or error("No robloxDataStore")
	self._autoSaveTimeSeconds = DEFAULT_AUTO_SAVE_TIME_SECONDS
	self._jitterProportion = DEFAULT_JITTER_PROPORTION
	self._autoSaveAlsoSyncs = false

	if self._key == "" then
		error("[DataStore] - Key cannot be an empty string")
	end

--[=[
	Prop that fires when saving. Promise will resolve once saving is complete.
	@prop Saving Signal<Promise>
	@within DataStore
]=]
	self.Saving = Signal.new() -- :Fire(promise)
	self._maid:GiveTask(self.Saving)

	self._maid:GiveTask(task.spawn(function()
		while true do
			local startTime = os.clock()
			local jitterBase = math.random()

			repeat
				local timeElapsed = os.clock() - startTime
				local totalWaitTime = Math.jitter(self._autoSaveTimeSeconds, self._jitterProportion*self._autoSaveTimeSeconds, jitterBase)

			  	if timeElapsed > totalWaitTime then
			  		break
			  	end

			  	local totalLeft = totalWaitTime - timeElapsed

			  	-- Wait at most 1 second
				task.wait(math.min(totalLeft, 1))

				timeElapsed = os.clock() - startTime
			until timeElapsed > totalWaitTime

			if self._autoSaveAlsoSyncs then
				self:Sync()
			else
				self:Save()
			end
		end
	end))

	return self
end

--[=[
	Returns the full path for the datastore
	@return string
]=]
function DataStore:GetFullPath()
	return ("RobloxDataStore@%s"):format(self._key)
end

function DataStore:SetAutoSaveTimeSeconds(autoSaveTimeSeconds)
	assert(type(autoSaveTimeSeconds) == "number", "Bad autoSaveTimeSeconds")

	self._autoSaveTimeSeconds = autoSaveTimeSeconds
end

function DataStore:SetAutoSaveAlsoSyncs(autoSaveAlsoSyncs)
	assert(type(autoSaveAlsoSyncs) == "boolean", "Bad autoSaveAlsoSyncs")

	self._autoSaveAlsoSyncs = autoSaveAlsoSyncs
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

--[=[
	Returns whether the datastore has loaded successfully.\

	@return Promise<boolean>
]=]
function DataStore:PromiseLoadSuccessful()
	return self._maid:GivePromise(self:LoadAll()):Then(function()
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
	return self:_syncData(false)
end

--[=[
	Same as saving the data but it also loads fresh data from the datastore, which may consume
	additional data-store query calls.

	@return Promise
]=]
function DataStore:Sync()
	return self:_syncData(true)
end

function DataStore:_syncData(doMergeNewData)
	if self:DidLoadFail() then
		warn("[DataStore] - Not syncing, failed to load")
		return Promise.rejected("Load not successful, not syncing")
	end

	if DEBUG_WRITING then
		print("[DataStore._syncData] - Starting sync routine")
	end

	return self:_promiseInvokeSavingCallbacks()
		:Then(function()
			if not self:HasWritableData() then
				if not doMergeNewData then
					-- Nothing to save, don't update anything
					if DEBUG_WRITING then
						print("[DataStore._syncData] - Not saving, nothing staged")
					end

					return nil
				end

				if DEBUG_WRITING then
					print("[DataStore._syncData] - Merging data from a get API call")
				end

				-- Reads are cheaper than writes
				return self:_promiseLoadNoCache()
			else
				return self:_doDataSync(self:GetNewWriter(), doMergeNewData)
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
	return self:LoadAll()
		:Then(function(data)
			return self:_afterLoadGetAndApplyStagedData(keyName, data, defaultValue)
		end)
end

function DataStore:_doDataSync(writer, doMergeNewData)
	assert(type(doMergeNewData) == "boolean", "Bad doMergeNewData")

	local maid = Maid.new()

	local promise = Promise.new()
	promise:Resolve(maid:GivePromise(DataStorePromises.updateAsync(self._robloxDataStore, self._key, function(data)
		if promise:IsRejected() then
			-- Cancel if we have another request
			return nil
		end

		writer:StoreDifference(data or {})

		data = writer:WriteMerge(data or {})
		assert(data ~= DataStoreDeleteToken, "Cannot delete from UpdateAsync")

		if DEBUG_WRITING then
			print("[DataStore] - Writing", game:GetService("HttpService"):JSONEncode(data))
		end

		if doMergeNewData then
			-- This prevents resaving at high frequency
			self:MarkDataAsSaved(writer)
			self:PromiseMergeNewBaseData(writer)
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

function DataStore:LoadAll()
	if self._loadPromise then
		return self._loadPromise
	end

	self._loadPromise = self:_promiseLoadNoCache()
	return self._loadPromise
end

function DataStore:_promiseLoadNoCache()
	return self._maid:GivePromise(DataStorePromises.getAsync(self._robloxDataStore, self._key)
		:Then(function(data)
			if data == nil then
				return {}
			elseif type(data) == "table" then
				return data
			else
				return Promise.rejected("[DataStore] - Failed to load data. Wrong type '" .. type(data) .. "'")
			end
		end, function(err)
			-- Log:
			warn("[DataStore] - Failed to GetAsync data", err)
			return Promise.rejected(err)
		end))
		:Then(function(data)
			local writer = self:GetNewWriter()
			writer:StoreDifference(data or {})

			return self:PromiseMergeNewBaseData(writer)
		end)
end

return DataStore