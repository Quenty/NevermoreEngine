---
-- @module PermissionProviderClient
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

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

function PermissionProviderClient:PromiseIsAdmin()
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