--[=[
	Permission provider using the remote event. See [PermissionServiceClient].

	@client
	@class PermissionProviderClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local PermissionProviderConstants = require("PermissionProviderConstants")
local Promise = require("Promise")
local PromiseGetRemoteFunction = require("PromiseGetRemoteFunction")

local PermissionProviderClient = {}
PermissionProviderClient.__index = PermissionProviderClient
PermissionProviderClient.ClassName = "PermissionProviderClient"

function PermissionProviderClient.new(remoteFunctionName)
	local self = setmetatable({}, PermissionProviderClient)

	self._remoteFunctionName = remoteFunctionName or PermissionProviderConstants.DEFAULT_REMOTE_FUNCTION_NAME

	return self
end

--[=[
	Returns whether the local player is an admin.

	@param player Player | nil
	@return Promise<boolean>
]=]
function PermissionProviderClient:PromiseIsAdmin(player)
	assert(typeof(player) == "Instance" and player:IsA("Player") or player == nil, "Bad player")

	if player ~= nil then
		assert(player == Players.LocalPlayer, "We only support local player for now")
	end

	if player == nil then
		player = Players.LocalPlayer
	end

	if self._cachedAdminPromise then
		return self._cachedAdminPromise
	end

	self._cachedAdminPromise = self:_promiseRemoteFunction()
		:Then(function(remoteFunction)
			return Promise.spawn(function(resolve, reject)
				local result = nil
				local ok, err = pcall(function()
					result = remoteFunction:InvokeServer()
				end)
				if not ok then
					return reject(err)
				end

				if type(result) ~= "boolean" then
					return reject("Got non-boolean from server")
				end

				return resolve(result)
			end)
		end)

	return self._cachedAdminPromise
end

function PermissionProviderClient:_promiseRemoteFunction()
	if self._remoteFunctionPromise then
		return self._remoteFunctionPromise
	end

	self._remoteFunctionPromise = PromiseGetRemoteFunction(self._remoteFunctionName)
	return self._remoteFunctionPromise
end

return PermissionProviderClient