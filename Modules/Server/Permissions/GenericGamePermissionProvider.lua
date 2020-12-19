---
-- @module GenericPermissionProvider
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GenericPermissionProviderConstants = require("GenericPermissionProviderConstants")
local GetRemoteFunction = require("GetRemoteFunction")
local Promise = require("Promise")
local BaseObject = require("BaseObject")

local GenericPermissionProvider = setmetatable({}, BaseObject)
GenericPermissionProvider.__index = "GenericPermissionProvider"
GenericPermissionProvider.ClassName = "GenericPermissionProvider"

function GenericPermissionProvider.new(config, remoteFunctionName)
	local self = setmetatable(BaseObject.new(), GenericPermissionProvider)


	self._config = assert(config)
	assert(self._config.type == GenericPermissionProviderConstants.GROUP_RANK_CONFIG_TYPE)

	self._adminsCache = {} -- [userId] = true

	self._remoteFunction = GetRemoteFunction(remoteFunctionName or GenericPermissionProviderConstants.REMOTE_FUNCTION_NAME)

	return self
end

function GenericPermissionProvider:Init()
	assert(self._config)

	self._remoteFunction.OnServerInvoke = function(...)
		return self:_onServerInvoke(...)
	end

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		self._adminsCache[player.UserId] = nil
	end))

	self._maid:GiveTask(Players.PlayerAdded:Connect(function(player)
		self:_handlePlayer(player)
	end))

	for _, player in pairs(Players:GetPlayers()) do
		self:_handlePlayer(player)
	end

	return self
end


function GenericPermissionProvider:PromiseIsCreator(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"))
	assert(player:IsDescendantOf(game))

	local userId = player.UserId
	if self._creatorPromiseCache[userId] then
		return self._creatorPromiseCache[userId]
	else
		-- Initialize and assume player joined will resolve it
		self._creatorPromiseCache[userId] = Promise.new()
		return self._creatorPromiseCache[userId]
	end
end

function GenericPermissionProvider:IsAdmin(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"))

	if self._adminsCache[player.UserId]then
		return true
	end

	return false
end

function GenericPermissionProvider:_onServerInvoke(player)
	return self:IsAdmin(player)
end

function GenericPermissionProvider:_handlePlayer(player)
	if RunService:IsStudio() then
		self._adminsCache[player.UserId] = true
		return
	end

	self._maid:GivePromise(Promise.spawn(function(resolve, reject)
		local rank = nil
		local ok, err = pcall(function()
			rank = player:GetRankInGroup(self._config.groupId)
		end)

		if not ok then
			return reject(err)
		end

		if not rank then
			return reject()
		end

		return resolve(rank)
	end)):Then(function(rank)
		if rank >= self._config.minRequiredRank then
			self._adminsCache[player.UserId] = true
		end
	end)
end

return GenericPermissionProvider