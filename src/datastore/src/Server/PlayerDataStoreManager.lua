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

	local function handlePlayer(player)
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
	for _, player in pairs(Players:GetPlayers()) do
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
local PromiseUtils = require("PromiseUtils")
local PendingPromiseTracker = require("PendingPromiseTracker")
local Maid = require("Maid")
local Promise = require("Promise")

local PlayerDataStoreManager = setmetatable({}, BaseObject)
PlayerDataStoreManager.ClassName = "PlayerDataStoreManager"
PlayerDataStoreManager.__index = PlayerDataStoreManager

--[=[
	Constructs a new PlayerDataStoreManager.

	@param robloxDataStore DataStore
	@param keyGenerator (player) -> string -- Function that takes in a player, and outputs a key
	@param skipBindingToClose boolean?
	@return PlayerDataStoreManager
]=]
function PlayerDataStoreManager.new(robloxDataStore, keyGenerator, skipBindingToClose)
	local self = setmetatable(BaseObject.new(), PlayerDataStoreManager)

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
function PlayerDataStoreManager:DisableSaveOnCloseStudio()
	assert(RunService:IsStudio())

	self._disableSavingInStudio = true
end

--[=[
	Adds a callback to be called before save on removal
	@param callback function -- May return a promise
]=]
function PlayerDataStoreManager:AddRemovingCallback(callback)
	table.insert(self._removingCallbacks, callback)
end

--[=[
	Callable to allow manual GC so things can properly clean up.
	This can be used to pre-emptively cleanup players.

	@param player Player
]=]
function PlayerDataStoreManager:RemovePlayerDataStore(player)
	self:_removePlayerDataStore(player)
end

--[=[
	@param player Player
	@return DataStore
]=]
function PlayerDataStoreManager:GetDataStore(player)
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
function PlayerDataStoreManager:PromiseAllSaves()
	for player, _ in pairs(self._datastores) do
		self:_removePlayerDataStore(player)
	end
	return self._maid:GivePromise(PromiseUtils.all(self._pendingSaves:GetAll()))
end

function PlayerDataStoreManager:_createDataStore(player)
	assert(not self._datastores[player], "Bad player")

	local datastore = DataStore.new(self._robloxDataStore, self:_getKey(player))
	datastore:SetUserIdList({ player.UserId })

	self._maid._savingConns[player] = datastore.Saving:Connect(function(promise)
		self._pendingSaves:Add(promise)
	end)

	self._datastores[player] = datastore

	return datastore
end

function PlayerDataStoreManager:_removePlayerDataStore(player)
	assert(typeof(player) == "Instance", "Bad player")
	assert(player:IsA("Player"), "Bad player")

	local datastore = self._datastores[player]
	if not datastore then
		return
	end

	self._removing[player] = true

	local removingPromises = {}
	for _, func in pairs(self._removingCallbacks) do
		local result = func(player)
		if Promise.isPromise(result) then
			table.insert(removingPromises, result)
		end
	end

	PromiseUtils.all(removingPromises)
		:Then(function()
			return datastore:Save()
		end)
		:Finally(function()
			datastore:Destroy()
			self._removing[player] = nil
		end)

	-- Prevent double removal or additional issues
	self._datastores[player] = nil
	self._maid._savingConns[player] = nil
end

function PlayerDataStoreManager:_getKey(player)
	return self._keyGenerator(player)
end

return PlayerDataStoreManager