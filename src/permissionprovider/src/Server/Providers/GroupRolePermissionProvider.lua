--!strict
--[=[
	Provides permissions from the roles a player holds in a group. See
	[PermissionProviderUtils.createGroupRoleConfig].

	@server
	@class GroupRolePermissionProvider
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local BasePermissionProvider = require("BasePermissionProvider")
local GroupUtils = require("GroupUtils")
local PermissionLevel = require("PermissionLevel")
local PermissionProviderConstants = require("PermissionProviderConstants")
local PermissionProviderUtils = require("PermissionProviderUtils")
local PlayerMock = require("PlayerMock")
local Promise = require("Promise")

local GroupRolePermissionProvider = setmetatable({}, BasePermissionProvider)
GroupRolePermissionProvider.__index = GroupRolePermissionProvider
GroupRolePermissionProvider.ClassName = "GroupRolePermissionProvider"

export type GroupRolePermissionProvider =
	typeof(setmetatable(
		{} :: {
			_config: PermissionProviderUtils.GroupRoleConfig,
			_adminRoleIds: { [number]: true },
			_creatorRoleIds: { [number]: true },
			_promiseRoleIdsCache: { [number]: Promise.Promise<{ number }> },
		},
		{} :: typeof({ __index = GroupRolePermissionProvider })
	))
	& BasePermissionProvider.BasePermissionProvider

local function toSet(list: { number }): { [number]: true }
	local set: { [number]: true } = {}
	for _, value in list do
		set[value] = true
	end
	return set
end

local function getUserId(player: Player): number
	return if PlayerMock.isMock(player) then PlayerMock.read(player, "UserId") else player.UserId
end

--[=[
	@param config GroupRoleConfig
	@return GroupRolePermissionProvider
]=]
function GroupRolePermissionProvider.new(config: PermissionProviderUtils.GroupRoleConfig): GroupRolePermissionProvider
	local self: GroupRolePermissionProvider =
		setmetatable(BasePermissionProvider.new(config) :: any, GroupRolePermissionProvider)

	assert(self._config.type == PermissionProviderConstants.GROUP_ROLE_CONFIG_TYPE, "Bad configType")

	self._creatorRoleIds = toSet(self._config.creatorRoleIds)
	self._adminRoleIds = toSet(self._config.adminRoleIds)
	for roleId in self._creatorRoleIds do
		self._adminRoleIds[roleId] = true
	end

	self._promiseRoleIdsCache = {}

	return self
end

--[=[
	Starts the permission provider. Should be done via ServiceBag.
]=]
function GroupRolePermissionProvider.Start(self: GroupRolePermissionProvider)
	assert(self._config, "Bad config")

	getmetatable(GroupRolePermissionProvider).Start(self)

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player: Player)
		local userId = getUserId(player)
		local promise = self._promiseRoleIdsCache[userId]
		if promise then
			self._promiseRoleIdsCache[userId] = nil
			promise:Reject()
		end
	end))

	self._maid:GiveTask(Players.PlayerAdded:Connect(function(player)
		self:_promiseRoleIds(player)
	end))

	for _, player in Players:GetPlayers() do
		self:_promiseRoleIds(player)
	end

	return self
end

--[=[
	Returns whether the player is at a specific permission level

	@param player Player
	@param permissionLevel PermissionLevel
	@return Promise<boolean>
]=]
function GroupRolePermissionProvider.PromiseIsPermissionLevel(
	self: GroupRolePermissionProvider,
	player: Player,
	permissionLevel: PermissionLevel.PermissionLevel
): Promise.Promise<boolean>
	assert((typeof(player) == "Instance" and player:IsA("Player")) or PlayerMock.isMock(player), "Bad player")
	assert(player:IsDescendantOf(game), "Bad player")
	assert(PermissionLevel:IsValue(permissionLevel))

	local allowedRoleIds
	if permissionLevel == PermissionLevel.ADMIN then
		allowedRoleIds = self._adminRoleIds
	elseif permissionLevel == PermissionLevel.CREATOR then
		allowedRoleIds = self._creatorRoleIds
	else
		error("Unknown permissionLevel")
	end

	return self:_promiseRoleIds(player):Then(function(roleIds: { number })
		for _, roleId in roleIds do
			if allowedRoleIds[roleId] then
				return true
			end
		end
		return false
	end)
end

function GroupRolePermissionProvider._promiseRoleIds(
	self: GroupRolePermissionProvider,
	player: Player
): Promise.Promise<{ number }>
	local userId = getUserId(player)
	local cached = self._promiseRoleIdsCache[userId]
	if cached then
		return cached
	end

	local promise = GroupUtils.promiseRoleIdsInGroup(player, self._config.groupId)
	self._promiseRoleIdsCache[userId] = promise
	promise:Catch(function()
		if self._promiseRoleIdsCache[userId] == promise then
			self._promiseRoleIdsCache[userId] = nil
		end
	end)

	return promise
end

return GroupRolePermissionProvider
