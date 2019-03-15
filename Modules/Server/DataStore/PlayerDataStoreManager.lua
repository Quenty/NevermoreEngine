--- DataStore manager for player that automatically saves on player leave and game close
-- @classmod PlayerDataStoreManager

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")

local BaseObject = require("BaseObject")
local DataStore = require("DataStore")
local PromiseUtils = require("PromiseUtils")
local PendingPromiseTracker = require("PendingPromiseTracker")
local Maid = require("Maid")

local PlayerDataStoreManager = setmetatable({}, BaseObject)
PlayerDataStoreManager.ClassName = "PlayerDataStoreManager"
PlayerDataStoreManager.__index = PlayerDataStoreManager

-- @param [keyGenerator] Function that takes in a player, and outputs a key
function PlayerDataStoreManager.new(datastore, keyGenerator)
	local self = setmetatable(BaseObject.new(), PlayerDataStoreManager)

	self._datastore = datastore or error("No datastore")
	self._keyGenerator = keyGenerator or error("No keyGenerator")

	self._maid._savingConns = Maid.new()

	self._datastores = {} -- [player] = datastore
	self._removing = {} -- [player] = true

	self._pendingSaves = PendingPromiseTracker.new()

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		self:_removePlayerDataStore(player)
	end))

	game:BindToClose(function()
		self:PromiseFinish():Wait()
	end)

	return self
end

function PlayerDataStoreManager:GetDataStore(player)
	if self._removing[player] then
		warn("[PlayerDataStoreManager.GetDataStore] - Called GetDataStore while player is removing, cannot retrieve")
		return nil
	end

	if self._datastores[player] then
		return self._datastores[player]
	end

	return self:_createDataStore(player)
end

function PlayerDataStoreManager:PromiseFinish()
	for player, _ in pairs(self._datastores) do
		self:_removePlayerDataStore(player)
	end
	return PromiseUtils.all(self._pendingSaves:GetAll())
end

function PlayerDataStoreManager:_createDataStore(player)
	assert(not self._datastores[player])

	local datastore = DataStore.new(self._datastores, self:_getKey(player))

	self._maid._savingConns[player] = datastore.Saving:Connect(function(promise)
		self._pendingSaves:Add(promise)
	end)

	self._datastores[player] = datastore

	return datastore
end

function PlayerDataStoreManager:_removePlayerDataStore(player)
	local datastore = self._datastores[player]
	if not datastore then
		return
	end

	self._removing[player] = true
	datastore:Save():Finally(function()
		datastore:Destroy()
		self._removing[player] = nil
	end)

	-- Prevent double removal or additional issues
	self._datastores[player] = nil
	self._maid._savingConns[player] = nil
end

return PlayerDataStoreManager