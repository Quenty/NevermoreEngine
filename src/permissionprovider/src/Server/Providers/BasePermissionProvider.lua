--!strict
--[=[
	Basic interface for providing permissions.
	@server
	@class BasePermissionProvider
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local GetRemoteFunction = require("GetRemoteFunction")
local PermissionLevel = require("PermissionLevel")
local PermissionLevelUtils = require("PermissionLevelUtils")
local Table = require("Table")
local _Promise = require("Promise")
local _PermissionProviderUtils = require("PermissionProviderUtils")

local BasePermissionProvider = setmetatable({}, BaseObject)
BasePermissionProvider.ClassName = "BasePermissionProvider"
BasePermissionProvider.__index = BasePermissionProvider

export type BasePermissionProvider = typeof(setmetatable(
	{} :: {
		_config: { remoteFunctionName: string },
		_remoteFunctionName: string,
		_remoteFunction: RemoteFunction?,
	},
	{} :: typeof({ __index = BasePermissionProvider })
)) & BaseObject.BaseObject

--[=[
	Initializes a new permission provider

	@param config { remoteFunctionName: string }
	@return BasePermissionProvider
]=]
function BasePermissionProvider.new(config: _PermissionProviderUtils.PermissionProviderConfig): BasePermissionProvider
	local self: BasePermissionProvider = setmetatable(BaseObject.new() :: any, BasePermissionProvider)

	self._config = Table.readonly(assert(config, "Bad config") :: any)
	self._remoteFunctionName = assert(self._config.remoteFunctionName, "Bad config")

	return self
end

--[=[
	Starts the permission provider. Should be done via ServiceBag.
]=]
function BasePermissionProvider.Start(self: BasePermissionProvider): ()
	assert(not (self :: any)._remoteFunction, "No remoteFunction")

	local remoteFunction = GetRemoteFunction(self._remoteFunctionName)
	remoteFunction.OnServerInvoke = function(...)
		return self:_onServerInvoke(...)
	end
	self._remoteFunction = remoteFunction
end

--[=[
	Returns whether the player is a creator.
	@param player Player
	@param permissionLevel PermissionLevel
	@return Promise<boolean>
]=]
function BasePermissionProvider.PromiseIsPermissionLevel(
	_self: BasePermissionProvider,
	player: Player,
	permissionLevel: PermissionLevel.PermissionLevel
): _Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(PermissionLevelUtils.isPermissionLevel(permissionLevel), "Bad permissionLevel")

	error("Not implemented")
end

--[=[
	Returns whether the player is a creator.
	@param player Player
	@param permissionLevel PermissionLevel
	@return Promise<boolean>
]=]
function BasePermissionProvider.IsPermissionLevel(
	self: BasePermissionProvider,
	player: Player,
	permissionLevel: PermissionLevel.PermissionLevel
): boolean
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(PermissionLevelUtils.isPermissionLevel(permissionLevel), "Bad permissionLevel")

	local promise = self:PromiseIsPermissionLevel(player, permissionLevel)
	if promise:IsPending() then
		return false -- We won't yield for this
	end

	local ok, result = promise:Yield()
	if not ok then
		warn(string.format("[BasePermissionProvider] - %s", tostring(result)))
		return false
	end

	return result
end

--[=[
	Returns whether the player is a creator.
	@param player Player
	@return Promise<boolean>
]=]
function BasePermissionProvider.PromiseIsCreator(
	self: BasePermissionProvider,
	player: Player
): _Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self:PromiseIsPermissionLevel(player, PermissionLevel.CREATOR)
end

--[=[
	Returns whether the player is an admin.
	@param player Player
	@return Promise<boolean>
]=]
function BasePermissionProvider.PromiseIsAdmin(self: BasePermissionProvider, player: Player): _Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self:PromiseIsPermissionLevel(player, PermissionLevel.ADMIN)
end

--[=[
	Returns whether the player is a creator.

	:::info
	May return false if not loaded. Prefer using the promise version.
	:::

	@param player Player
	@return boolean
]=]
function BasePermissionProvider.IsCreator(self: BasePermissionProvider, player: Player): boolean
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self:IsPermissionLevel(player, PermissionLevel.CREATOR)
end

--[=[
	Returns whether the player is an admin.

	:::info
	May return false if not loaded. Prefer using the promise version.
	:::

	@param player Player
	@return boolean
]=]
function BasePermissionProvider.IsAdmin(self: BasePermissionProvider, player: Player): boolean
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self:IsPermissionLevel(player, PermissionLevel.ADMIN)
end

function BasePermissionProvider._onServerInvoke(self: BasePermissionProvider, player: Player): boolean
	local promise = self:PromiseIsAdmin(player)
	local ok, result = promise:Yield()
	if not ok then
		warn(string.format("[BasePermissionProvider] - Failed retrieval due to %q", tostring(result)))
		return false
	end

	return result and true or false
end

return BasePermissionProvider