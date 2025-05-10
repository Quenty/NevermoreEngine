--!strict
--[=[
	Retrieves a remote event as a promise
	@class PromiseGetRemoteEvent
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GetRemoteEvent = require("GetRemoteEvent")
local Promise = require("Promise")
local ResourceConstants = require("ResourceConstants")

--[=[
	Like [GetRemoteEvent] but in promise form.

	@function PromiseGetRemoteEvent
	@within PromiseGetRemoteEvent
	@param name string
	@return Promise<RemoteEvent>
]=]
if not RunService:IsRunning() then
	-- Handle testing
	return function(name)
		return Promise.resolved(GetRemoteEvent(name))
	end
elseif RunService:IsServer() then
	return function(name)
		return Promise.resolved(GetRemoteEvent(name))
	end
else -- RunService:IsClient()
	return function(name)
		assert(type(name) == "string", "Bad name")

		local storage = ReplicatedStorage:FindFirstChild(ResourceConstants.REMOTE_EVENT_STORAGE_NAME)
		if storage then
			local obj = storage:FindFirstChild(name)
			if obj then
				return Promise.resolved(obj)
			end
		end

		return Promise.spawn(function(resolve, _)
			resolve(GetRemoteEvent(name))
		end)
	end
end
