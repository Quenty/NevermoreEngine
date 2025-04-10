--!strict
--[=[
	Provides permissions from a group

	@server
	@class GroupPermissionProvider
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local BasePermissionProvider = require("BasePermissionProvider")
local GroupUtils = require("GroupUtils")
local PermissionLevel = require("PermissionLevel")
local PermissionLevelUtils = require("PermissionLevelUtils")
local PermissionProviderConstants = require("PermissionProviderConstants")
local Promise = require("Promise")
local _PermissionProviderUtils = require("PermissionProviderUtils")

local GroupPermissionProvider = setmetatable({}, BasePermissionProvider)
GroupPermissionProvider.__index = GroupPermissionProvider
GroupPermissionProvider.ClassName = "GroupPermissionProvider"

export type GroupPermissionProvider = typeof(setmetatable(
	{} :: {
		_config: _PermissionProviderUtils.GroupRankConfig,
		_groupId: number,
		_minAdminRequiredRank: number,
		_minCreatorRequiredRank: number,
		_adminsCache: { [number]: true },
		_creatorCache: { [number]: true },
		_promiseRankPromisesCache: { [number]: Promise.Promise<number> },
	},
	{} :: typeof({ __index = GroupPermissionProvider })
)) & BasePermissionProvider.BasePermissionProvider

--[=[
	@param config table
	@return GroupPermissionProvider
]=]
function GroupPermissionProvider.new(config: _PermissionProviderUtils.GroupRankConfig): GroupPermissionProvider
	local self = setmetatable(BasePermissionProvider.new(config) :: any, GroupPermissionProvider)

	assert(self._config.type == PermissionProviderConstants.GROUP_RANK_CONFIG_TYPE, "Bad configType")

	self._adminsCache = {} -- [userId] = true
	self._creatorCache = {} -- [userId] = true

	self._promiseRankPromisesCache = {} -- [userId] = promise

	return self
end

--[=[
	Starts the permission provider. Should be done via ServiceBag.
]=]
function GroupPermissionProvider.Start(self: GroupPermissionProvider)
	assert(self._config, "Bad config")

	getmetatable(GroupPermissionProvider).Start(self)

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player: Player)
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

	for _, player in Players:GetPlayers() do
		self:_handlePlayer(player)
	end

	return self
end

--[=[
	Returns whether the player is at a specific permission level

	@param player Player
	@param permissionLevel PermissionLevel
	@return Promise<boolean>
]=]
function GroupPermissionProvider.PromiseIsPermissionLevel(
	self: GroupPermissionProvider,
	player: Player,
	permissionLevel: PermissionLevel.PermissionLevel
): Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(PermissionLevelUtils.isPermissionLevel(permissionLevel), "Bad permissionLevel")

	if permissionLevel == PermissionLevel.ADMIN then
		return self:_promiseIsAdmin(player)
	elseif permissionLevel == PermissionLevel.CREATOR then
		return self:_promiseIsCreator(player)
	else
		error("Unknown permissionLevel")
	end
end

function GroupPermissionProvider._promiseIsCreator(
	self: GroupPermissionProvider,
	player: Player
): Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(player:IsDescendantOf(game), "Bad player")

	if self._creatorCache[player.UserId] then
		return Promise.resolved(true)
	end

	return self:_promiseRankInGroup(player):Then(function(rank)
		return rank >= self._config.minCreatorRequiredRank
	end)
end

function GroupPermissionProvider._promiseIsAdmin(
	self: GroupPermissionProvider,
	player: Player
): Promise.Promise<boolean>
	assert(player:IsDescendantOf(game))

	-- really not saving much time.
	if self._creatorCache[player.UserId] then
		return Promise.resolved(true)
	end

	if self._adminsCache[player.UserId] then
		return Promise.resolved(true)
	end

	return self:_promiseRankInGroup(player):Then(function(rank)
		return rank >= self._config.minAdminRequiredRank
	end)
end

function GroupPermissionProvider._handlePlayer(self: GroupPermissionProvider, player: Player): ()
	assert(player, "Bad player")

	self:_promiseRankInGroup(player):Then(function(rank)
		if rank >= self._config.minAdminRequiredRank then
			self._adminsCache[player.UserId] = true
		end

		if rank >= self._config.minCreatorRequiredRank then
			self._creatorCache[player.UserId] = true
		end
	end)
end

function GroupPermissionProvider._promiseRankInGroup(self: GroupPermissionProvider, player: Player): Promise.Promise<number>
	assert(typeof(player) == "Instance", "Bad player")

	if self._promiseRankPromisesCache[player.UserId] then
		return self._promiseRankPromisesCache[player.UserId]
	end

	self._promiseRankPromisesCache[player.UserId] = GroupUtils.promiseRankInGroup(player, self._config.groupId)
	return self._promiseRankPromisesCache[player.UserId]
end

return GroupPermissionProvider