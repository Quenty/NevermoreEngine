---
-- @classmod CreatorPermissionProvider
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local BasePermissionProvider = require("BasePermissionProvider")
local PermissionProviderConstants = require("PermissionProviderConstants")
local Promise = require("Promise")

local CreatorPermissionProvider = setmetatable({}, BasePermissionProvider)
CreatorPermissionProvider.ClassName = "CreatorPermissionProvider"
CreatorPermissionProvider.__index = CreatorPermissionProvider

function CreatorPermissionProvider.new(config)
	local self = setmetatable(BasePermissionProvider.new(config), CreatorPermissionProvider)

	assert(self._config.type == PermissionProviderConstants.SINGLE_USER_CONFIG_TYPE, "Bad configType")
	self._userId = assert(self._config.userId, "No userId")

	return self
end

function CreatorPermissionProvider:PromiseIsCreator(player)
	return Promise.resolved(player.UserId == self._userId
		or RunService:IsStudio())
end

function CreatorPermissionProvider:PromiseIsAdmin(player)
	return Promise.resolved(player.UserId == self._userId
		or RunService:IsStudio())
end

return CreatorPermissionProvider