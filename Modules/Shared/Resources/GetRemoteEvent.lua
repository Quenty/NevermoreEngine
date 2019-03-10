--- Provides getting remote events
-- @function GetRemoteEvent
-- @author Quenty

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local STORAGE_NAME = "RemoteEvents"

if RunService:IsServer() then
	return function(name)
		assert(type(name) == "string")

		local storage = ReplicatedStorage:FindFirstChild(STORAGE_NAME)
		if not storage then
			storage = Instance.new("Folder")
			storage.Name = STORAGE_NAME
			storage.Parent = ReplicatedStorage
		end

		local event = ReplicatedStorage:FindFirstChild(name)
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

		return ReplicatedStorage:WaitForChild(STORAGE_NAME):WaitForChild(name)
	end
end