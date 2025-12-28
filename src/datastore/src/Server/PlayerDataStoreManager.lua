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

export type KeyGenerator = (Player) -> string
export type PlayerDataStoreManager =
	typeof(setmetatable(
		{} :: {
			_robloxDataStore: any,
			_keyGenerator: KeyGenerator,
			_datastores: { [Player]: DataStore.DataStore },
			_removing: { [Player]: boolean },
			_pendingSaves: PendingPromiseTracker.PendingPromiseTracker<any>,
			_removingCallbacks: { (Player) -> any },
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

	self._datastores = {} -- [player] = datastore
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
function PlayerDataStoreManager.AddRemovingCallback(self: PlayerDataStoreManager, callback)
	table.insert(self._removingCallbacks, callback)
end

--[=[
	Callable to allow manual GC so things can properly clean up.
	This can be used to pre-emptively cleanup players.

	@param player Player
]=]
function PlayerDataStoreManager.RemovePlayerDataStore(self: PlayerDataStoreManager, player: Player): ()
	self:_removePlayerDataStore(player)
end

--[=[
	Gets the datastore for a player. If it does not exist, it will create one.

	:::tip
	Returns nil if the player is in the process of being removed.
	:::

	@param player Player
	@return DataStore?
]=]
function PlayerDataStoreManager.GetDataStore(self: PlayerDataStoreManager, player: Player): DataStore.DataStore?
	assert(typeof(player) == "Instance", "Bad player")
	assert(player:IsA("Player"), "Bad player")

	if self._removing[player] then
		warn("[PlayerDataStoreManager.GetDataStore] - Called GetDataStore while player is removing, cannot retrieve")
		return nil
	end

	if self._datastores[player] then
		return self._datastores[player]
	end

	return self:_createDataStore(player)
end

--[=[
	Removes all player data stores, and returns a promise that
	resolves when all pending saves are saved.
	@return Promise
]=]
function PlayerDataStoreManager.PromiseAllSaves(self: PlayerDataStoreManager): Promise.Promise<()>
	for player, _ in self._datastores do
		self:_removePlayerDataStore(player)
	end
	return self._maid:GivePromise(PromiseUtils.all(self._pendingSaves:GetAll()))
end

function PlayerDataStoreManager._createDataStore(self: PlayerDataStoreManager, player: Player): DataStore.DataStore
	assert(not self._datastores[player], "Bad player")

	local datastore = DataStore.new(self._robloxDataStore, self:_getKey(player))
	datastore:SetSessionLockingEnabled(true)
	datastore:SetUserIdList({ player.UserId })

	datastore:PromiseSessionLockingFailed():Then(function()
		player:Kick("DataStore session lock failed to load. Please message developers.")
	end)

	self._maid._savingConns[player] = datastore.Saving:Connect(function(promise)
		self._pendingSaves:Add(promise)
	end)

	self._datastores[player] = datastore

	return datastore
end

function PlayerDataStoreManager._removePlayerDataStore(self: PlayerDataStoreManager, player: Player)
	assert(typeof(player) == "Instance", "Bad player")
	assert(player:IsA("Player"), "Bad player")

	local datastore = self._datastores[player]
	if not datastore then
		return
	end

	self._removing[player] = true

	local removingPromises = {}
	for _, func in self._removingCallbacks do
		local result = func(player)
		if Promise.isPromise(result) then
			table.insert(removingPromises, result)
		end
	end

	PromiseUtils.all(removingPromises)
		:Then(function()
			return datastore:SaveAndCloseSession()
		end)
		:Finally(function()
			datastore:Destroy()
			self._removing[player] = nil
		end)

	-- Prevent double removal or additional issues
	self._datastores[player] = nil
	self._maid._savingConns[player] = nil
end

function PlayerDataStoreManager._getKey(self: PlayerDataStoreManager, player: Player)
	return self._keyGenerator(player)
end

return PlayerDataStoreManager
