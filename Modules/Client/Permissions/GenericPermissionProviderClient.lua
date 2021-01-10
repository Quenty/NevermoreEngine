---
-- @module GenericPermissionProviderClient
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local GenericPermissionProviderConstants = require("GenericPermissionProviderConstants")
local PromiseGetRemoteFunction = require("PromiseGetRemoteFunction")
local Promise = require("Promise")

local GenericPermissionProviderClient = {}
GenericPermissionProviderClient.__index = GenericPermissionProviderClient
GenericPermissionProviderClient.ClassName = "GenericPermissionProviderClient"

function GenericPermissionProviderClient.new(remoteFunctionName)
	local self = setmetatable({}, GenericPermissionProviderClient)

	self._remoteFunctionName = remoteFunctionName or GenericPermissionProviderConstants.REMOTE_FUNCTION_NAME

	return self
end

function GenericPermissionProviderClient:PromiseIsAdmin()
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

function GenericPermissionProviderClient:_promiseRemoteFunction()
	return PromiseGetRemoteFunction(self._remoteFunctionName)
end

return GenericPermissionProviderClient