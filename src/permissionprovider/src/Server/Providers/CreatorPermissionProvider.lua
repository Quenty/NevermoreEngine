--!strict
--[=[
	Provides permissions from a single user creator

	@server
	@class CreatorPermissionProvider
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local BasePermissionProvider = require("BasePermissionProvider")
local PermissionProviderConstants = require("PermissionProviderConstants")
local Promise = require("Promise")
local PermissionLevel = require("PermissionLevel")
local PermissionLevelUtils = require("PermissionLevelUtils")
local _PermissionProviderUtils = require("PermissionProviderUtils")

local CreatorPermissionProvider = setmetatable({}, BasePermissionProvider)
CreatorPermissionProvider.ClassName = "CreatorPermissionProvider"
CreatorPermissionProvider.__index = CreatorPermissionProvider

export type CreatorPermissionProvider = typeof(setmetatable(
	{} :: {
		_config: _PermissionProviderUtils.SingleUserConfig,
		_userId: number,
	},
	{} :: typeof({ __index = CreatorPermissionProvider })
)) & BasePermissionProvider.BasePermissionProvider

--[=[
	@param config table
	@return CreatorPermissionProvider
]=]
function CreatorPermissionProvider.new(config: _PermissionProviderUtils.SingleUserConfig): CreatorPermissionProvider
	local self: CreatorPermissionProvider =
		setmetatable(BasePermissionProvider.new(config) :: any, CreatorPermissionProvider)

	assert(self._config.type == PermissionProviderConstants.SINGLE_USER_CONFIG_TYPE, "Bad configType")
	self._userId = assert(self._config.userId, "No userId")

	return self
end

--[=[
	Returns whether the player is at a specific permission level.

	@param player Player
	@param permissionLevel PermissionLevel
	@return Promise<boolean>
]=]
function CreatorPermissionProvider.PromiseIsPermissionLevel(self: CreatorPermissionProvider, player: Player, permissionLevel: PermissionLevel.PermissionLevel): Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(PermissionLevelUtils.isPermissionLevel(permissionLevel), "Bad permissionLevel")

	if permissionLevel == PermissionLevel.ADMIN
		or permissionLevel == PermissionLevel.CREATOR then
		return Promise.resolved(player.UserId == self._userId or RunService:IsStudio())
	else
		error("Unknown permissionLevel")
	end
end

return CreatorPermissionProvider