--!strict
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

	local function handlePlayer(player: Player)
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
	for _, player in Players:GetPlayers() do
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
local Math = require("Math")
local Promise = require("Promise")
local Rx = require("Rx")
local Signal = require("Signal")
local Symbol = require("Symbol")
local ValueObject = require("ValueObject")

local DEFAULT_DEBUG_WRITING = false

local DEFAULT_AUTO_SAVE_TIME_SECONDS = 60 * 5
local DEFAULT_JITTER_PROPORTION = 0.1 -- Randomly assign jitter so if a ton of players join at once we don't hit the datastore at once

local DataStore = setmetatable({}, DataStoreStage)
DataStore.ClassName = "DataStore"
DataStore.__index = DataStore

export type DataStore = typeof(setmetatable(
	{} :: {
		_key: string,
		_userIdList: { number }?,
		_robloxDataStore: DataStorePromises.RobloxDataStore,
		_debugWriting: boolean,
		_autoSaveTimeSeconds: ValueObject.ValueObject<number?>,
		_jitterProportion: ValueObject.ValueObject<number>,
		_syncOnSave: ValueObject.ValueObject<boolean>,
		_loadedOk: ValueObject.ValueObject<boolean>,
		_firstLoadPromise: Promise.Promise<()>,
		Saving: Signal.Signal<Promise.Promise<()>>,
	},
	{} :: typeof({ __index = DataStore })
)) & DataStoreStage.DataStoreStage

--[=[
	Constructs a new DataStore. See [DataStoreStage] for more API.

	```lua
	local dataStore = serviceBag:GetService(PlayerDataStoreService):PromiseDataStore(player):Yield()
	```

	@param robloxDataStore DataStore
	@param key string
	@return DataStore
]=]
function DataStore.new(robloxDataStore: DataStorePromises.RobloxDataStore, key: string)
	local self: DataStore = setmetatable(DataStoreStage.new(key) :: any, DataStore)

	self._key = key or error("No key")
	self._robloxDataStore = robloxDataStore or error("No robloxDataStore")
	self._debugWriting = DEFAULT_DEBUG_WRITING

	self._autoSaveTimeSeconds = self._maid:Add(ValueObject.new(DEFAULT_AUTO_SAVE_TIME_SECONDS :: number?))
	self._jitterProportion = self._maid:Add(ValueObject.new(DEFAULT_JITTER_PROPORTION, "number"))
	self._syncOnSave = self._maid:Add(ValueObject.new(false, "boolean"))
	self._loadedOk = self._maid:Add(ValueObject.new(false, "boolean"))

	self._userIdList = nil

	if self._key == "" then
		error("[DataStore] - Key cannot be an empty string")
	end

	--[=[
	Prop that fires when saving. Promise will resolve once saving is complete.
	@prop Saving Signal<Promise>
	@within DataStore
]=]
	self.Saving = self._maid:Add(Signal.new() :: any) -- :Fire(promise)

	self:_setupAutoSaving()

	return self
end

--[=[
	Set to true to debug writing this data store

	@param debugWriting boolean
]=]
function DataStore.SetDoDebugWriting(self: DataStore, debugWriting: boolean)
	assert(type(debugWriting) == "boolean", "Bad debugWriting")

	self._debugWriting = debugWriting
end

--[=[
	Returns the full path for the datastore
	@return string
]=]
function DataStore.GetFullPath(self: DataStore): string
	return string.format("RobloxDataStore@%s", self._key)
end

--[=[
	How frequent the data store will autosave (or sync) to the cloud. If set to nil then the datastore
	will not do any syncing.

	@param autoSaveTimeSeconds number?
]=]
function DataStore.SetAutoSaveTimeSeconds(self: DataStore, autoSaveTimeSeconds: number?)
	assert(type(autoSaveTimeSeconds) == "number" or autoSaveTimeSeconds == nil, "Bad autoSaveTimeSeconds")

	self._autoSaveTimeSeconds.Value = autoSaveTimeSeconds
end

--[=[
	How frequent the data store will autosave (or sync) to the cloud

	@param syncEnabled boolean
]=]
function DataStore.SetSyncOnSave(self: DataStore, syncEnabled: boolean)
	assert(type(syncEnabled) == "boolean", "Bad syncEnabled")

	self._syncOnSave.Value = syncEnabled
end

--[=[
	Returns whether the datastore failed.
	@return boolean
]=]
function DataStore.DidLoadFail(self: DataStore): boolean
	if not self._firstLoadPromise then
		return false
	end

	if self._firstLoadPromise:IsRejected() then
		return true
	end

	return false
end

--[=[
	Returns whether the datastore has loaded successfully.\

	@return Promise<boolean>
]=]
function DataStore.PromiseLoadSuccessful(self: DataStore): Promise.Promise<boolean>
	return self._maid:GivePromise(self:PromiseViewUpToDate()):Then(function()
		return true
	end, function()
		return false
	end)
end

--[=[
	Saves all stored data.
	@return Promise
]=]
function DataStore.Save(self: DataStore): Promise.Promise<()>
	return self:_syncData(false)
end

--[=[
	Same as saving the data but it also loads fresh data from the datastore, which may consume
	additional data-store query calls.

	@return Promise
]=]
function DataStore.Sync(self: DataStore): Promise.Promise<()>
	return self:_syncData(true)
end

--[=[
	Sets the user id list associated with this datastore. Can be useful for GDPR compliance.

	@param userIdList { number }?
]=]
function DataStore.SetUserIdList(self: DataStore, userIdList: { number }?)
	assert(type(userIdList) == "table" or userIdList == nil, "Bad userIdList")
	assert(not Symbol.isSymbol(userIdList), "Should not be symbol")

	self._userIdList = userIdList
end

--[=[
	Returns a list of user ids or nil

	@return { number }?
]=]
function DataStore.GetUserIdList(self: DataStore): { number }?
	return self._userIdList
end

--[=[
	Overridden helper method for data store stage below.

	@return Promise
]=]
function DataStore.PromiseViewUpToDate(self: DataStore): Promise.Promise<()>
	if self._firstLoadPromise then
		return self._firstLoadPromise
	end

	local promise = self:_promiseGetAsyncNoCache()
	self._firstLoadPromise = promise

	promise:Tap(function()
		self._loadedOk.Value = true
	end)

	return promise
end

function DataStore._setupAutoSaving(self: DataStore)
	local startTime = os.clock()

	self._maid:GiveTask(Rx.combineLatest({
		autoSaveTimeSeconds = self._autoSaveTimeSeconds:Observe(),
		jitterProportion = self._jitterProportion:Observe(),
		syncOnSave = self._syncOnSave:Observe(),
		loadedOk = self._loadedOk:Observe(),
	}):Subscribe(function(state)
		if state.autoSaveTimeSeconds and state.loadedOk then
			local maid = Maid.new()
			if self._debugWriting then
				print("Auto-saving loop started")
			end

			-- TODO: First jitter is way noisier to differentiate servers
			maid:GiveTask(task.spawn(function()
				while true do
					local jitterBase = math.random()
					local timeElapsed = os.clock() - startTime
					local totalWaitTime = Math.jitter(
						state.autoSaveTimeSeconds,
						state.jitterProportion * state.autoSaveTimeSeconds,
						jitterBase
					)
					local timeRemaining = totalWaitTime - timeElapsed

					if timeRemaining > 0 then
						task.wait(timeRemaining)
					end

					startTime = os.clock()

					if state.syncOnSave then
						self:Sync()
					else
						self:Save()
					end

					task.wait(0.1)
				end
			end))

			self._maid._autoSavingMaid = maid
		else
			self._maid._autoSavingMaid = nil
		end
	end))
end

function DataStore._syncData(self: DataStore, doMergeNewData: boolean)
	if self:DidLoadFail() then
		warn("[DataStore] - Not syncing, failed to load")
		return Promise.rejected("Load not successful, not syncing")
	end

	return self._maid
		:GivePromise(self:PromiseViewUpToDate())
		:Then(function()
			return self._maid:GivePromise(self:PromiseInvokeSavingCallbacks())
		end)
		:Then(function(): Promise.Promise<()>?
			if not self:HasWritableData() then
				if doMergeNewData then
					-- Reads are cheaper than update async calls
					return self:_promiseGetAsyncNoCache()
				end

				-- Nothing to save, don't update anything
				if self._debugWriting then
					print("[DataStore] - Not saving, nothing staged")
				end

				return nil
			else
				return self:_doDataSync(self:GetNewWriter(), doMergeNewData)
			end
		end)
end

function DataStore._doDataSync(self: DataStore, writer, doMergeNewData: boolean): Promise.Promise<()>
	assert(type(doMergeNewData) == "boolean", "Bad doMergeNewData")

	-- Cache user id list
	writer:SetUserIdList(self:GetUserIdList())

	local maid = Maid.new()

	local promise = Promise.new()

	if writer:IsCompleteWipe() then
		if self._debugWriting then
			print(string.format("[DataStore] - DataStorePromises.removeAsync(%q)", self._key))
		end

		-- This is, of course, dangerous, because we won't merge
		promise:Resolve(
			maid:GivePromise(DataStorePromises.removeAsync(self._robloxDataStore, self._key)):Then(function(): any
				if doMergeNewData then
					-- Write our data
					self:MarkDataAsSaved(writer)

					-- Do syncing after
					return self:_promiseGetAsyncNoCache()
				end

				return nil
			end)
		)
	else
		if self._debugWriting then
			print(
				string.format(
					"[DataStore] - DataStorePromises.updateAsync(%q) with doMergeNewData = %s",
					self._key,
					tostring(doMergeNewData)
				)
			)
		end

		promise:Resolve(
			maid:GivePromise(
				DataStorePromises.updateAsync(self._robloxDataStore, self._key, function(original, datastoreKeyInfo)
					if promise:IsRejected() then
						-- Cancel if we have another request
						return nil
					end

					local diffSnapshot
					if doMergeNewData then
						diffSnapshot = writer:ComputeDiffSnapshot(original)
					end

					local result = writer:WriteMerge(original)

					if result == DataStoreDeleteToken or result == nil then
						result = {}
					end

					self:_checkSnapshotIntegrity("writer:WriteMerge(original)", result)

					if self._debugWriting then
						print("[DataStore] - Writing", result)
					end

					if doMergeNewData then
						-- This prevents resaving at high frequency
						self:MarkDataAsSaved(writer)
						self:MergeDiffSnapshot(diffSnapshot)
					end

					local userIdList = writer:GetUserIdList()
					if datastoreKeyInfo then
						userIdList = datastoreKeyInfo:GetUserIds()
					end

					local metadata = nil
					if datastoreKeyInfo then
						metadata = datastoreKeyInfo:GetMetadata()
					end

					return result, userIdList, metadata
				end)
			)
		)
	end

	promise:Tap(nil, function(err)
		-- Might be caused by Maid rejecting state
		warn("[DataStore] - Failed to sync data", err)
	end)

	self._maid._saveMaid = maid

	if self.Saving.Destroy then
		self.Saving:Fire(promise)
	end

	return promise
end

function DataStore._promiseGetAsyncNoCache(self: DataStore): Promise.Promise<()>
	return self._maid:GivePromise(DataStorePromises.getAsync(self._robloxDataStore, self._key))
		:Catch(function(err)
			warn(string.format("DataStorePromises.getAsync(%q) -> warning - %s", tostring(self._key), tostring(err or "empty error")))
			return Promise.rejected(err)
		end)
		:Then(function(data)
			local writer = self:GetNewWriter()
			local diffSnapshot = writer:ComputeDiffSnapshot(data)

			self:MergeDiffSnapshot(diffSnapshot)

			if self._debugWriting then
				print(string.format("DataStorePromises.getAsync(%q) -> Got ", tostring(self._key)), data, "with diff snapshot", diffSnapshot, "to view", self._viewSnapshot)
				-- print(string.format("DataStorePromises.getAsync(%q) -> Got ", self._key), data)
			end
		end)
end

return DataStore