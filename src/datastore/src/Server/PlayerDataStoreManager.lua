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

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local DataStore = require("DataStore")
local Maid = require("Maid")
local PendingPromiseTracker = require("PendingPromiseTracker")
local Promise = require("Promise")
local PromiseUtils = require("PromiseUtils")

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
			_keyGenerator: KeyGenerator,
			_datastores: { [PlayerUserId]: DataStore.DataStore },
			_removing: { [PlayerUserId]: boolean },
			_pendingSaves: PendingPromiseTracker.PendingPromiseTracker<any>,
			_removingCallbacks: { RemovingCallback },
			_disableSavingInStudio: boolean?,
		},
		{} :: typeof({ __index = PlayerDataStoreManager })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new PlayerDataStoreManager.

	@param robloxDataStore DataStore
	@param keyGenerator (player) -> string -- Function that takes in a player, and outputs a key
	@param skipBindingToClose boolean?
	@return PlayerDataStoreManager
]=]
function PlayerDataStoreManager.new(
	robloxDataStore: DataStore,
	keyGenerator: KeyGenerator,
	skipBindingToClose: boolean?
): PlayerDataStoreManager
	local self: PlayerDataStoreManager = setmetatable(BaseObject.new() :: any, PlayerDataStoreManager)

	assert(type(skipBindingToClose) == "boolean" or skipBindingToClose == nil, "Bad skipBindingToClose")

	self._robloxDataStore = robloxDataStore or error("No robloxDataStore")
	self._keyGenerator = keyGenerator or error("No keyGenerator")

	self._maid._savingConns = Maid.new()

	self._datastores = {} -- [userId] = datastore
	self._removing = {} -- [player] = true
	self._pendingSaves = PendingPromiseTracker.new()
	self._removingCallbacks = {} -- [func, ...]

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		if self._disableSavingInStudio then
			return
		end

		self:_removePlayerDataStore(player)
	end))

	if skipBindingToClose ~= true then
		game:BindToClose(function()
			if self._disableSavingInStudio then
				return
			end

			self:PromiseAllSaves():Wait()
		end)
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

function PlayerDataStoreManager:_toPlayerUserIdOrError(playerOrUserId: Player | PlayerUserId): PlayerUserId
	if typeof(playerOrUserId) == "Instance" and playerOrUserId:IsA("Player") then
		return playerOrUserId.UserId
	elseif type(playerOrUserId) == "number" then
		return playerOrUserId :: PlayerUserId
	else
		error("Bad playerOrUserId")
	end
end

--[=[
	Removes all player data stores, and returns a promise that
	resolves when all pending saves are saved.
	@return Promise
]=]
function PlayerDataStoreManager.PromiseAllSaves(self: PlayerDataStoreManager): Promise.Promise<()>
	for userId, _ in self._datastores do
		self:_removePlayerDataStore(userId)
	end
	return self._maid:GivePromise(PromiseUtils.all(self._pendingSaves:GetAll()))
end

function PlayerDataStoreManager._createDataStore(
	self: PlayerDataStoreManager,
	userId: PlayerUserId
): DataStore.DataStore
	assert(not self._datastores[userId], "Bad player")

	local maid = Maid.new()

	-- TODO: Destroy DataStore after cleanup
	local datastore = DataStore.new(self._robloxDataStore, self:_getKey(userId))
	datastore:SetSessionLockingEnabled(true)
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

function PlayerDataStoreManager._removePlayerDataStore(self: PlayerDataStoreManager, userId: PlayerUserId)
	local datastore = self._datastores[userId]
	if not datastore then
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

	PromiseUtils.all(removingPromises)
		:Then(function()
			return datastore:SaveAndCloseSession()
		end)
		:Finally(function()
			datastore:Destroy()
			self._removing[userId] = nil
		end)

	-- Prevent double removal or additional issues
	self._datastores[userId] = nil
	self._maid._savingConns[userId] = nil
end

function PlayerDataStoreManager._getKey(self: PlayerDataStoreManager, playerOrUserId: Player | PlayerUserId): string
	return self._keyGenerator(playerOrUserId)
end

return PlayerDataStoreManager
