---
-- @module PermissionProvider
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")

local PermissionProviderConstants = require("PermissionProviderConstants")
local GetRemoteFunction = require("GetRemoteFunction")
local Promise = require("Promise")
local BaseObject = require("BaseObject")
local GroupUtils = require("GroupUtils")
local Table = require("Table")

local PermissionProvider = setmetatable({}, BaseObject)
PermissionProvider.__index = PermissionProvider
PermissionProvider.ClassName = "PermissionProvider"

function PermissionProvider.new(config)
	local self = setmetatable(BaseObject.new(), PermissionProvider)


	self._config = Table.readonly(assert(config))
	assert(self._config.type == PermissionProviderConstants.GROUP_RANK_CONFIG_TYPE,
		"Only one supported config type")
	self._remoteFunctionName = assert(self._config.remoteFunctionName)

	self._adminsCache = {} -- [userId] = true
	self._creatorCache = {} -- [userId] = true

	self._promiseRankPromisesCache = {} -- [userId] = promise

	return self
end

function PermissionProvider:Init()
	assert(self._config)

	self._remoteFunction = GetRemoteFunction(self._remoteFunctionName)
	self._remoteFunction.OnServerInvoke = function(...)
		return self:_onServerInvoke(...)
	end

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId

		self._adminsCache[userId] = nil
		self._creatorCache[userId] = nil

		local promise = self._promiseRankPromisesCache[userId]
		if promise then
			promise:Reject()
			self._promiseRankPromisesCache[userId] = nil
		end
	end))

	self._maid:GiveTask(Players.PlayerAdded:Connect(function(player)
		self:_handlePlayer(player)
	end))

	for _, player in pairs(Players:GetPlayers()) do
		self:_handlePlayer(player)
	end

	return self
end

-- May return false if not loaded
function PermissionProvider:IsCreator(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"))

	return self._creatorCache[player.UserId]
end

-- May return false if not loaded
function PermissionProvider:IsAdmin(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"))

	return self._adminsCache[player.UserId]
end

function PermissionProvider:PromiseIsCreator(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"))
	assert(player:IsDescendantOf(game))

	return self:_promiseRankInGroup(player)
		:Then(function(rank)
			return rank >= self._config.minCreatorRequiredRank
		end)
end

function PermissionProvider:PromiseIsAdmin(player)
	assert(player:IsDescendantOf(game))

	-- really not saving much time.
	if self._creatorCache[player.UserId] then
		return Promise.resolved(true)
	end

	return self:_promiseRankInGroup(player)
		:Then(function(rank)
			return rank >= self._config.minRequiredRank
		end)
end

function PermissionProvider:_onServerInvoke(player)
	local promise = self:_promiseRankInGroup(player)
	local ok, result = promise:Yield()
	if not ok then
		warn(("[PermissionProvider] - Failed retrieval due to %q"):format(tostring(result)))
		return false
	end

	return result and true or false
end

function PermissionProvider:_handlePlayer(player)
	assert(player)

	self:_promiseRankInGroup(player)
		:Then(function(rank)
			if rank >= self._config.minAdminRequiredRank then
				self._adminsCache[player.UserId] = true
			end

			if rank >= self._config.minCreatorRequiredRank then
				self._creatorCache[player.UserId] = true
			end
		end)
end

function PermissionProvider:_promiseRankInGroup(player)
	assert(typeof(player) == "Instance")

	if self._promiseRankPromisesCache[player.UserId] then
		return self._promiseRankPromisesCache[player.UserId]
	end

	self._promiseRankPromisesCache[player.UserId] = GroupUtils.promiseRankInGroup(player, self._config.groupId)
	return self._promiseRankPromisesCache[player.UserId]
end

return PermissionProvider