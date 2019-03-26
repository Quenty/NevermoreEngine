--- Provides getting remote events
-- @function GetRemoteFunction
-- @author Quenty

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local STORAGE_NAME = "RemoteFunctions"

if RunService:IsServer() then
	return function(name)
		assert(type(name) == "string")

		local storage = ReplicatedStorage:FindFirstChild(STORAGE_NAME)
		if not storage then
			storage = Instance.new("Folder")
			storage.Name = STORAGE_NAME
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

		return ReplicatedStorage:WaitForChild(STORAGE_NAME):WaitForChild(name)
	end
end