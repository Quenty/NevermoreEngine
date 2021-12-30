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

local CreatorPermissionProvider = setmetatable({}, BasePermissionProvider)
CreatorPermissionProvider.ClassName = "CreatorPermissionProvider"
CreatorPermissionProvider.__index = CreatorPermissionProvider

--[=[
	@param config table
	@return CreatorPermissionProvider
]=]
function CreatorPermissionProvider.new(config)
	local self = setmetatable(BasePermissionProvider.new(config), CreatorPermissionProvider)

	assert(self._config.type == PermissionProviderConstants.SINGLE_USER_CONFIG_TYPE, "Bad configType")
	self._userId = assert(self._config.userId, "No userId")

	return self
end

--[=[
	Returns whether the player is a creator.
	@param player Player
	@return Promise<boolean>
]=]
function CreatorPermissionProvider:PromiseIsCreator(player)
	return Promise.resolved(player.UserId == self._userId
		or RunService:IsStudio())
end

--[=[
	Returns whether the player is an admin.
	@param player Player
	@return Promise<boolean>
]=]
function CreatorPermissionProvider:PromiseIsAdmin(player)
	return Promise.resolved(player.UserId == self._userId
		or RunService:IsStudio())
end

return CreatorPermissionProvider