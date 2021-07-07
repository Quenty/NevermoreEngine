--- Provides getting remote events
-- @function GetRemoteFunction

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ResourceConstants = require("ResourceConstants")

if not RunService:IsRunning() then
	return function(name)
		local event = Instance.new("RemoteFunction")
		event.Name = "Mock" .. name

		return event
	end
elseif RunService:IsServer() then
	return function(name)
		assert(type(name) == "string")

		local storage = ReplicatedStorage:FindFirstChild(ResourceConstants.REMOTE_FUNCTION_STORAGE_NAME)
		if not storage then
			storage = Instance.new("Folder")
			storage.Name = ResourceConstants.REMOTE_FUNCTION_STORAGE_NAME
			storage.Parent = ReplicatedStorage
		end

		local func = storage:FindFirstChild(name)
		if func then
			return func
		end

		func = Instance.new("RemoteFunction")
		func.Name = name
		func.Parent = storage

		return func
	end
else -- RunService:IsClient()
	return function(name)
		assert(type(name) == "string")

		return ReplicatedStorage:WaitForChild(ResourceConstants.REMOTE_FUNCTION_STORAGE_NAME):WaitForChild(name)
	end
end