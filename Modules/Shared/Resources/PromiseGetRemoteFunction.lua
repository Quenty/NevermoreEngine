--- Retrieves a remote function as a promise
-- @module PromiseGetRemoteFunction

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GetRemoteFunction = require("GetRemoteFunction")
local Promise = require("Promise")
local ResourceConstants = require("ResourceConstants")

if RunService:IsServer() then
	return function(name)
		return Promise.resolved(GetRemoteFunction(name))
	end
else -- RunService:IsClient()
	return function(name)
		assert(type(name) == "string")

		local storage = ReplicatedStorage:FindFirstChild(ResourceConstants.REMOTE_FUNCTION_STORAGE_NAME)
		if storage then
			local obj = storage:FindFirstChild(name)
			if obj then
				return Promise.resolved(obj)
			end
		end

		return Promise.spawn(function(resolve, reject)
			resolve(GetRemoteFunction(name))
		end)
	end
end