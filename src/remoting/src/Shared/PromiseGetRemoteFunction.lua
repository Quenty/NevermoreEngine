--!strict
--[=[
	Retrieves a remote function as a promise
	@class PromiseGetRemoteFunction
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GetRemoteFunction = require("GetRemoteFunction")
local Promise = require("Promise")
local ResourceConstants = require("ResourceConstants")

--[=[
	Like [GetRemoteFunction] but in promise form.

	@function PromiseGetRemoteFunction
	@within PromiseGetRemoteFunction
	@param name string
	@return Promise<RemoteFunction>
]=]

if not RunService:IsRunning() then
	-- Handle testing
	return function(name)
		return Promise.resolved(GetRemoteFunction(name))
	end
elseif RunService:IsServer() then
	return function(name)
		return Promise.resolved(GetRemoteFunction(name))
	end
else -- RunService:IsClient()
	return function(name)
		assert(type(name) == "string", "Bad name")

		local storage = ReplicatedStorage:FindFirstChild(ResourceConstants.REMOTE_FUNCTION_STORAGE_NAME)
		if storage then
			local obj = storage:FindFirstChild(name)
			if obj then
				return Promise.resolved(obj)
			end
		end

		return Promise.spawn(function(resolve, _)
			resolve(GetRemoteFunction(name))
		end)
	end
end
