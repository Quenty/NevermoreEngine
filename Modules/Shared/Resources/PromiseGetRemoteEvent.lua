--- Retrieves a remote event as a promise
-- @module PromiseGetRemoteEvent

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GetRemoteEvent = require("GetRemoteEvent")
local Promise = require("Promise")
local ResourceConstants = require("ResourceConstants")

if RunService:IsServer() then
	return function(name)
		return Promise.resolved(GetRemoteEvent(name))
	end
else -- RunService:IsClient()
	return function(name)
		assert(type(name) == "string")

		local storage = ReplicatedStorage:FindFirstChild(ResourceConstants.REMOTE_EVENT_STORAGE_NAME)
		if storage then
			local obj = storage:FindFirstChild(name)
			if obj then
				return Promise.resolved(obj)
			end
		end

		return Promise.spawn(function(resolve, reject)
			resolve(GetRemoteEvent(name))
		end)
	end
end