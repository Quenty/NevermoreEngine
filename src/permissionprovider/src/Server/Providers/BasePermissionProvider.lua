---
-- @classmod BasePermissionProvider
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local GetRemoteFunction = require("GetRemoteFunction")
local Table = require("Table")

local BasePermissionProvider = setmetatable({}, BaseObject)
BasePermissionProvider.ClassName = "BasePermissionProvider"
BasePermissionProvider.__index = BasePermissionProvider

function BasePermissionProvider.new(config)
	local self = setmetatable(BaseObject.new(), BasePermissionProvider)

	self._config = Table.readonly(assert(config, "Bad config"))
	self._remoteFunctionName = assert(self._config.remoteFunctionName, "Bad config")

	return self
end

function BasePermissionProvider:Start()
	assert(not self._remoteFunction, "No remoteFunction")

	self._remoteFunction = GetRemoteFunction(self._remoteFunctionName)
	self._remoteFunction.OnServerInvoke = function(...)
		return self:_onServerInvoke(...)
	end
end

function BasePermissionProvider:PromiseIsCreator(_player)
	error("Not implemented")
end

function BasePermissionProvider:PromiseIsAdmin(_player)
	error("Not implemented")
end

-- May return false if not loaded
function BasePermissionProvider:IsCreator(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	local promise = self:PromiseIsCreator(player)
	if promise:IsPending() then
		return false -- We won't yield for this
	end

	local ok, result = promise:Yield()
	if not ok then
		warn("[BasePermissionProvider] - %s"):format(tostring(result))
		return false
	end

	return result
end

-- May return false if not loaded
function BasePermissionProvider:IsAdmin(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	local promise = self:PromiseIsAdmin(player)
	if promise:IsPending() then
		return false -- We won't yield for this
	end

	local ok, result = promise:Yield()
	if not ok then
		warn("[BasePermissionProvider] - %s"):format(tostring(result))
		return false
	end

	return result
end

function BasePermissionProvider:_onServerInvoke(player)
	local promise = self:PromiseIsAdmin(player)
	local ok, result = promise:Yield()
	if not ok then
		warn(("[BasePermissionProvider] - Failed retrieval due to %q"):format(tostring(result)))
		return false
	end

	return result and true or false
end


return BasePermissionProvider