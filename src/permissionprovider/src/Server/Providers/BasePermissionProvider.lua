--[=[
	Basic interface for providing permissions.
	@server
	@class BasePermissionProvider
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local GetRemoteFunction = require("GetRemoteFunction")
local Table = require("Table")

local BasePermissionProvider = setmetatable({}, BaseObject)
BasePermissionProvider.ClassName = "BasePermissionProvider"
BasePermissionProvider.__index = BasePermissionProvider

--[=[
	Initializes a new permission provider

	@param config { remoteFunctionName: string }
	@return BasePermissionProvider
]=]
function BasePermissionProvider.new(config)
	local self = setmetatable(BaseObject.new(), BasePermissionProvider)

	self._config = Table.readonly(assert(config, "Bad config"))
	self._remoteFunctionName = assert(self._config.remoteFunctionName, "Bad config")

	return self
end

--[=[
	Starts the permission provider. Should be done via ServiceBag.
]=]
function BasePermissionProvider:Start()
	assert(not self._remoteFunction, "No remoteFunction")

	self._remoteFunction = GetRemoteFunction(self._remoteFunctionName)
	self._remoteFunction.OnServerInvoke = function(...)
		return self:_onServerInvoke(...)
	end
end

--[=[
	Returns whether the player is a creator.
	@param player Player
	@return Promise<boolean>
]=]
function BasePermissionProvider:PromiseIsCreator(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	error("Not implemented")
end

--[=[
	Returns whether the player is an admin.
	@param player Player
	@return Promise<boolean>
]=]
function BasePermissionProvider:PromiseIsAdmin(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	error("Not implemented")
end

--[=[
	Returns whether the player is a creator.

	:::info
	May return false if not loaded. Prefer using the promise version.
	:::

	@param player Player
	@return boolean
]=]
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

--[=[
	Returns whether the player is an admin.

	:::info
	May return false if not loaded. Prefer using the promise version.
	:::

	@param player Player
	@return boolean
]=]
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