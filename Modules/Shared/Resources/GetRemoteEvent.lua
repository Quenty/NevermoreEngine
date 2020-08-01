--- Provides getting remote events
-- @function GetRemoteEvent

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ResourceConstants = require("ResourceConstants")

if not RunService:IsRunning() then
	return function(name)
		local event = Instance.new("RemoteEvent")
		event.Name = "Mock" .. name

		return event
	end
elseif RunService:IsServer() then
	return function(name)
		assert(type(name) == "string")

		local storage = ReplicatedStorage:FindFirstChild(ResourceConstants.REMOTE_EVENT_STORAGE_NAME)
		if not storage then
			storage = Instance.new("Folder")
			storage.Name = ResourceConstants.REMOTE_EVENT_STORAGE_NAME
			storage.Parent = ReplicatedStorage
		end

		local event = storage:FindFirstChild(name)
		if event then
			return event
		end

		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = storage

		return event
	end
else -- RunService:IsClient()
	return function(name)
		assert(type(name) == "string")

		return ReplicatedStorage:WaitForChild(ResourceConstants.REMOTE_EVENT_STORAGE_NAME):WaitForChild(name)
	end
end