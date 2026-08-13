--!strict
--[=[
	DataStore manager for player that automatically saves on player leave and game close.

	:::tip
	Consider using [PlayerDataStoreService] instead, which wraps one PlayerDataStoreManager.
	:::

	This will ensure that the datastores are reused between different services and other things integrating
	with Nevermore.

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

		maid:GivePromise(playerDataStoreService:PromiseDataStore(Players)):Then(function(dataStore)
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
	@class PlayerDataStoreManager
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local BindToCloseService = require("BindToCloseService")
local DataStore = require("DataStore")
local DataStoreLockUtils = require("DataStoreLockUtils")
local DataStorePromises = require("DataStorePromises")
local Maid = require("Maid")
local PendingPromiseTracker = require("PendingPromiseTracker")
local PlayerMock = require("PlayerMock")
local Promise = require("Promise")
local PromiseRetryUtils = require("PromiseRetryUtils")
local PromiseUtils = require("PromiseUtils")
local ServiceBag = require("ServiceBag")

local PlayerDataStoreManager = setmetatable({}, BaseObject)
PlayerDataStoreManager.ClassName = "PlayerDataStoreManager"
PlayerDataStoreManager.__index = PlayerDataStoreManager

export type PlayerUserId = number
export type KeyGenerator = (Player | PlayerUserId) -> string
export type RemovingCallback = (Player?) -> Promise.Promise<any>?

export type PlayerDataStoreManager =
	typeof(setmetatable(
		{} :: {
			_robloxDataStore: any,
			_serviceBag: ServiceBag.ServiceBag,
			_keyGenerator: KeyGenerator,
			_datastores: { [PlayerUserId]: DataStore.DataStore },
			_removing: { [PlayerUserId]: boolean },
			_removingPromises: { [PlayerUserId]: Promise.Promise<any> },
			_pendingSaves: PendingPromiseTracker.PendingPromiseTracker<any>,
			_removingCallbacks: { RemovingCallback },
			_disableSavingInStudio: boolean?,
			_hasCreatedDataStore: boolean,
			_loadRetryOptions: PromiseRetryUtils.RetryOptions?,
			_autoSaveTimeSeconds: number?,
			_autoSaveTimeSecondsSet: boolean,
			_sessionMessagingCloseDelaySeconds: number?,
		},
		{} :: typeof({ __index = PlayerDataStoreManager })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new PlayerDataStoreManager.

	Unless `skipBindingToClose` is true, this resolves [BindToCloseService] from the serviceBag to
	save on game close, so that service must be registered before the serviceBag starts.

	@param robloxDataStore DataStore
	@param keyGenerator (player) -> string -- Function that takes in a player, and outputs a key
	@param skipBindingToClose boolean?
	@return PlayerDataStoreManager
]=]
function PlayerDataStoreManager.new(
	serviceBag: ServiceBag.ServiceBag,
	robloxDataStore: DataStore,
	keyGenerator: KeyGenerator,
	skipBindingToClose: boolean?
): PlayerDataStoreManager
	local self: PlayerDataStoreManager = setmetatable(BaseObject.new() :: any, PlayerDataStoreManager)

	assert(type(skipBindingToClose) == "boolean" or skipBindingToClose == nil, "Bad skipBindingToClose")

	self._robloxDataStore = assert(robloxDataStore, "No robloxDataStore")
	self._keyGenerator = assert(keyGenerator, "No keyGenerator")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._maid._savingConns = Maid.new()

	self._datastores = {} -- [userId] = datastore
	self._removing = {} -- [player] = true
	self._removingPromises = {} -- [player] = removal promise
	self._pendingSaves = PendingPromiseTracker.new()
	self._removingCallbacks = {} -- [func, ...]
	self._hasCreatedDataStore = false
	self._autoSaveTimeSecondsSet = false

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		if self._disableSavingInStudio then
			return
		end

		self:_removePlayerDataStore(player.UserId)
	end))

	if skipBindingToClose ~= true then
		-- Route through BindToCloseService so the callback is unregistered on :Destroy()
		-- (unlike a raw game:BindToClose, which can never be unbound and would leak on hot reload).
		local bindToCloseService = self._serviceBag:GetService(BindToCloseService) :: any
		self._maid:GiveTask(bindToCloseService:RegisterPromiseOnCloseCallback(function()
			if self._disableSavingInStudio then
				return Promise.resolved()
			end

			return self:PromiseAllSaves()
		end))
	end

	return self
end

--[=[
	For if you want to disable saving in studio for faster close time!
]=]
function PlayerDataStoreManager.DisableSaveOnCloseStudio(self: PlayerDataStoreManager): ()
	assert(RunService:IsStudio(), "Must invoke in studio")

	self._disableSavingInStudio = true
end

--[=[
	Overrides the load retry backoff on every datastore this manager creates. See
	[DataStore.SetLoadRetryOptions].

	This is the knob that decides how long a player waits on a lock held by a dead server: the ladder
	runs, and only once it is exhausted is the lock stolen unconditionally. Defaults to ~49s.

	:::info
	Must be set before the first datastore is created.
	:::

	@param options RetryOptions
]=]
function PlayerDataStoreManager.SetLoadRetryOptions(
	self: PlayerDataStoreManager,
	options: PromiseRetryUtils.RetryOptions
): ()
	assert(not self._hasCreatedDataStore, "Must configure before the first datastore is created")
	assert(type(options) == "table", "Bad options")

	self._loadRetryOptions = options
end

--[=[
	Sets the autosave interval on every datastore this manager creates. See
	[DataStore.SetAutoSaveTimeSeconds]. Passing nil disables syncing entirely.

	:::info
	Must be set before the first datastore is created.
	:::

	@param autoSaveTimeSeconds number?
]=]
function PlayerDataStoreManager.SetAutoSaveTimeSeconds(self: PlayerDataStoreManager, autoSaveTimeSeconds: number?): ()
	assert(not self._hasCreatedDataStore, "Must configure before the first datastore is created")
	assert(type(autoSaveTimeSeconds) == "number" or autoSaveTimeSeconds == nil, "Bad autoSaveTimeSeconds")

	self._autoSaveTimeSeconds = autoSaveTimeSeconds
	self._autoSaveTimeSecondsSet = true
end

--[=[
	Sets the post-graceful-close replication delay on every datastore this manager creates. See
	[DataStore.SetSessionMessagingCloseDelaySeconds].

	:::info
	Must be set before the first datastore is created.
	:::

	@param seconds number
]=]
function PlayerDataStoreManager.SetSessionMessagingCloseDelaySeconds(self: PlayerDataStoreManager, seconds: number): ()
	assert(not self._hasCreatedDataStore, "Must configure before the first datastore is created")
	assert(type(seconds) == "number" and seconds >= 0, "Bad seconds")

	self._sessionMessagingCloseDelaySeconds = seconds
end

--[=[
	Adds a callback to be called before save on removal
	@param callback function -- May return a promise
]=]
function PlayerDataStoreManager.AddRemovingCallback(self: PlayerDataStoreManager, callback: RemovingCallback)
	table.insert(self._removingCallbacks, callback)
end

--[=[
	Callable to allow manual GC so things can properly clean up.
	This can be used to pre-emptively cleanup players.

]=]
function PlayerDataStoreManager.RemovePlayerDataStore(
	self: PlayerDataStoreManager,
	playerOrUserId: Player | PlayerUserId
): ()
	local userId = self:_toPlayerUserIdOrError(playerOrUserId)

	self:_removePlayerDataStore(userId)
end

--[=[
	Gets the datastore for a player. If it does not exist, it will create one.

	:::tip
	Returns nil if the player is in the process of being removed.
	:::

	@return DataStore?
]=]
function PlayerDataStoreManager.GetDataStore(
	self: PlayerDataStoreManager,
	playerOrUserId: Player | PlayerUserId
): DataStore.DataStore?
	local userId = self:_toPlayerUserIdOrError(playerOrUserId)

	if self._removing[userId] then
		warn("[PlayerDataStoreManager.GetDataStore] - Called GetDataStore while player is removing, cannot retrieve")
		return nil
	end

	if self._datastores[userId] then
		return self._datastores[userId]
	end

	return self:_createDataStore(userId)
end

--[=[
	Gets the datastore for a player, waiting for any in-progress removal/save first.
	Use this in async flows to safely support fast leave/rejoin behavior.

	@return Promise<DataStore>
]=]
function PlayerDataStoreManager.PromiseDataStore(
	self: PlayerDataStoreManager,
	playerOrUserId: Player | PlayerUserId
): Promise.Promise<DataStore.DataStore>
	local userId = self:_toPlayerUserIdOrError(playerOrUserId)

	return self:_promiseDataStoreByUserId(userId)
end

function PlayerDataStoreManager._promiseDataStoreByUserId(
	self: PlayerDataStoreManager,
	userId: PlayerUserId
): Promise.Promise<DataStore.DataStore>
	local dataStore = self:GetDataStore(userId)
	if dataStore then
		return Promise.resolved(dataStore)
	end

	return self:_promiseWaitForRemoving(userId):Then(function()
		return self:_promiseDataStoreByUserId(userId)
	end)
end

function PlayerDataStoreManager._promiseWaitForRemoving(
	self: PlayerDataStoreManager,
	userId: PlayerUserId
): Promise.Promise<()>
	local removingPromise = self._removingPromises[userId]
	if removingPromise then
		return removingPromise:Then(function()
			return nil
		end)
	end

	if self._removing[userId] then
		return Promise.defer(function(resolve, reject)
			local elapsed = 0
			while self._removing[userId] do
				elapsed += task.wait()

				if elapsed >= 15 then
					warn(
						`[PlayerDataStoreManager] - Last session cleanup for {userId} taking longer than 15 seconds. Rejecting.`
					)
					reject()
					break
				end
			end
			resolve()
		end)
	end

	return Promise.resolved()
end

function PlayerDataStoreManager:_toPlayerUserIdOrError(playerOrUserId: Player | PlayerUserId): PlayerUserId
	if type(playerOrUserId) == "number" then
		return playerOrUserId :: PlayerUserId
	end

	assert(
		typeof(playerOrUserId) == "Instance" and (playerOrUserId:IsA("Player") or PlayerMock.isMock(playerOrUserId)),
		"Bad playerOrUserId"
	)
	return (
		if PlayerMock.isMock(playerOrUserId) then PlayerMock.read(playerOrUserId, "UserId") else playerOrUserId.UserId
	) :: PlayerUserId
end

--[=[
	Reads the session lock on a player's key without opening a session on it.

	This is the read side of the tooling path: it answers "who holds this key, and how stale is that
	claim", whether or not the player is in this server. Resolves nil when the key is unlocked or
	absent. Reads the stored key, so for a player in this server it reflects their last save rather
	than unsaved in-memory state.

	@param playerOrUserId Player | number
	@return Promise<LockData?>
]=]
function PlayerDataStoreManager.PromiseReadSessionLock(
	self: PlayerDataStoreManager,
	playerOrUserId: Player | PlayerUserId
): Promise.Promise<DataStoreLockUtils.LockData?>
	local userId = self:_toPlayerUserIdOrError(playerOrUserId)

	return DataStorePromises.getAsync(self._robloxDataStore, self:_getKey(userId)):Then(function(data)
		return DataStoreLockUtils.readLock(data)
	end)
end

--[=[
	Clears the session lock on a player's key with a raw write, releasing a claim left behind by a
	server that died without closing its session.

	:::warning
	This is a soft lock. A loading session steals it anyway once its retry ladder is exhausted (see
	[PlayerDataStoreManager.SetLoadRetryOptions]) -- clearing it early only saves the player that wait.
	:::

	:::danger
	Permitted against a session this server holds, which desynchronizes that session from the key --
	its next save either re-writes the lock or reads this as a theft and kicks the player. That is a
	debug/stress-test capability, not a normal one.
	:::

	@param playerOrUserId Player | number
	@return Promise<LockData?> -- the lock that was cleared, or nil if it was already unlocked
]=]
function PlayerDataStoreManager.PromiseUnlockSession(
	self: PlayerDataStoreManager,
	playerOrUserId: Player | PlayerUserId
): Promise.Promise<DataStoreLockUtils.LockData?>
	return self:_promiseWriteRawSessionLock(self:_toPlayerUserIdOrError(playerOrUserId), nil)
end

--[=[
	Claims a player's key with a raw write, under a session this server will never answer for. Parks
	the key so an inspection is not racing a live server.

	:::warning
	This is a soft lock, and holds only for as long as a loading session's retry ladder. It is not a
	way to keep a player out of their data.
	:::

	:::danger
	Permitted against a session this server holds, with the same desynchronizing effect described on
	[PlayerDataStoreManager.PromiseUnlockSession].
	:::

	@param playerOrUserId Player | number
	@return Promise<LockData?> -- the lock that was replaced, or nil if it was unlocked
]=]
function PlayerDataStoreManager.PromiseLockSession(
	self: PlayerDataStoreManager,
	playerOrUserId: Player | PlayerUserId
): Promise.Promise<DataStoreLockUtils.LockData?>
	local userId = self:_toPlayerUserIdOrError(playerOrUserId)

	return self:_promiseWriteRawSessionLock(
		userId,
		DataStoreLockUtils.createLockData({
			SessionId = HttpService:GenerateGUID(false),
			PlaceId = game.PlaceId,
			JobId = game.JobId,
		})
	)
end

function PlayerDataStoreManager._promiseWriteRawSessionLock(
	self: PlayerDataStoreManager,
	userId: PlayerUserId,
	lockData: DataStoreLockUtils.LockData?
): Promise.Promise<DataStoreLockUtils.LockData?>
	-- Deliberately unguarded against a session this server owns. A raw write underneath one
	-- desynchronizes that session from the key: on its next save it either re-writes this lock, or
	-- reads it as a theft and kicks the player. That is precisely the failure the lock/unlock tools
	-- exist to provoke, so stress-testing against a live local session is allowed rather than refused.
	-- Callers reaching for this outside of debug tooling want the live [DataStore] instead.
	local previousLock: DataStoreLockUtils.LockData? = nil

	return DataStorePromises.updateAsync(self._robloxDataStore, self:_getKey(userId), function(data, datastoreKeyInfo)
		previousLock = DataStoreLockUtils.readLock(data)

		-- Nothing stored and nothing to clear, so cancel rather than create an empty entry.
		if data == nil and lockData == nil then
			return nil
		end

		-- UpdateAsync drops both when the transform omits them, so carry them through untouched.
		local userIdList = if datastoreKeyInfo then datastoreKeyInfo:GetUserIds() else { userId }
		local metadata = if datastoreKeyInfo then datastoreKeyInfo:GetMetadata() else nil

		return DataStoreLockUtils.withLock(data, lockData), userIdList, metadata
	end):Then(function()
		return previousLock
	end)
end

--[=[
	Removes all player data stores, and returns a promise that
	resolves when all pending saves are saved.

	On a closing server Roblox fires PlayerRemoving for every player, so a removal is usually already
	in flight by the time this runs. Those removals do the real save-and-close themselves; this waits
	for them rather than starting anything of its own.

	@return Promise
]=]
function PlayerDataStoreManager.PromiseAllSaves(self: PlayerDataStoreManager): Promise.Promise<()>
	for userId, _ in self._datastores do
		self:_removePlayerDataStore(userId)
	end

	local promises: { Promise.Promise<any> } = {}

	-- Wait on the removals still in flight, not just on _pendingSaves. A removal only reaches its write
	-- after the removing callbacks and then DataStore's own saving callbacks resolve, and Saving fires at
	-- the very end of that sync -- so _pendingSaves can be empty while a PlayerRemoving triggered moments
	-- earlier is still working toward its UpdateAsync. Resolving on that empty set lets BindToClose
	-- return and the server die mid-write, leaving the session locked with nobody able to release it: a
	-- lock belongs to the server that holds it, so the next server can only recover by grinding the
	-- graceful-close handshake against a dead JobId and then stealing it.
	for _, removalPromise in self._removingPromises do
		table.insert(promises, removalPromise :: any)
	end

	for _, savePromise in self._pendingSaves:GetAll() do
		table.insert(promises, savePromise :: any)
	end

	return self._maid:GivePromise(PromiseUtils.all(promises))
end

function PlayerDataStoreManager._createDataStore(
	self: PlayerDataStoreManager,
	userId: PlayerUserId
): DataStore.DataStore
	assert(not self._datastores[userId], "Bad player")

	local maid = Maid.new()

	self._hasCreatedDataStore = true

	-- DataStore is cleaned up very carefully in _removePlayerDataStore
	local datastore = DataStore.new(self._robloxDataStore, self:_getKey(userId))

	if self._loadRetryOptions then
		datastore:SetLoadRetryOptions(self._loadRetryOptions)
	end
	if self._autoSaveTimeSecondsSet then
		datastore:SetAutoSaveTimeSeconds(self._autoSaveTimeSeconds)
	end
	if self._sessionMessagingCloseDelaySeconds then
		datastore:SetSessionMessagingCloseDelaySeconds(self._sessionMessagingCloseDelaySeconds)
	end

	datastore:SetSessionLockingEnabled(true)
	datastore:SetSessionMessagingEnabled(true, self._serviceBag)
	datastore:SetUserIdList({ userId })

	maid:GivePromise(datastore:PromiseSessionLockingFailed()):Then(function()
		local player = Players:GetPlayerByUserId(userId)
		if player then
			player:Kick("DataStore session lock failed to load. Please message developers.")
		end

		self:_removePlayerDataStore(userId)
	end)

	maid:GiveTask(datastore.SessionStolen:Connect(function()
		local player = Players:GetPlayerByUserId(userId)
		if player then
			player:Kick("DataStore session stolen by another active session. Please message developers.")
		end
		self:_removePlayerDataStore(userId)
	end))

	maid:GiveTask(datastore.SessionCloseRequested:Connect(function()
		local player = Players:GetPlayerByUserId(userId)
		if player then
			player:Kick("DataStore is activating in another game.")
		end
		self:_removePlayerDataStore(userId)
	end))

	maid:GiveTask(datastore.Saving:Connect(function(promise)
		self._pendingSaves:Add(promise)
	end))

	self._maid._savingConns[userId] = maid
	self._datastores[userId] = datastore

	return datastore
end

function PlayerDataStoreManager._removePlayerDataStore(self: PlayerDataStoreManager, userId: PlayerUserId): ()
	local datastore = self._datastores[userId]
	if not datastore then
		return
	end

	if self._removing[userId] then
		return
	end

	self._removing[userId] = true

	local removingPromises: { Promise.Promise<any?> } = {}
	for _, func in self._removingCallbacks do
		local player = Players:GetPlayerByUserId(userId)
		local result = func(player)
		if Promise.isPromise(result) then
			table.insert(removingPromises, result :: any)
		end
	end

	local removalPromise = PromiseUtils.all(removingPromises)
		:Then(function()
			return datastore:SaveAndCloseSession()
		end)
		:Finally(function()
			datastore:Destroy()
			self._removing[userId] = nil
		end)

	self._removingPromises[userId] = removalPromise
	removalPromise:Finally(function()
		if self._removingPromises[userId] == removalPromise then
			self._removingPromises[userId] = nil
		end
	end)

	-- Prevent double removal or additional issues
	self._datastores[userId] = nil
	self._maid._savingConns[userId] = nil
end

function PlayerDataStoreManager._getKey(self: PlayerDataStoreManager, playerOrUserId: Player | PlayerUserId): string
	return self._keyGenerator(playerOrUserId)
end

return PlayerDataStoreManager
