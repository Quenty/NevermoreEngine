--[=[
	Provides getting named global [RemoteEvent] resources.
	@class GetRemoteEvent
]=]

--[=[
	Retrieves a global remote event from the store. On the server, it constructs a new one,
	and on the client, it waits for it to exist.

	:::tip
	Consider using [PromiseGetRemoteEvent] for a non-yielding version
	:::

	```lua
	-- server.lua
	local GetRemoteEvent = require("GetRemoteEvent")

	local remoteEvent = GetRemoteEvent("testing")
	remoteEvent.OnServerEvent:Connect(print)

	-- client.lua
	local GetRemoteEvent = require("GetRemoteEvent")

	local remoteEvent = GetRemoteEvent("testing")
	remoteEvent:FireServer("Hello") --> Hello (on the server)
	```

	:::info
	If the game is not running, then a mock remote event will be created
	for use in testing.
	:::

	@yields
	@function GetRemoteEvent
	@within GetRemoteEvent
	@param name string
	@return RemoteEvent
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ResourceConstants = require("ResourceConstants")

if not RunService:IsRunning() then
	return function(name)
		local event = Instance.new("RemoteEvent")
		event.Archivable = false
		event.Name = "Mock" .. name

		return event
	end
elseif RunService:IsServer() then
	return function(name)
		assert(type(name) == "string", "Bad name")

		local storage = ReplicatedStorage:FindFirstChild(ResourceConstants.REMOTE_EVENT_STORAGE_NAME)
		if not storage then
			storage = Instance.new("Folder")
			storage.Name = ResourceConstants.REMOTE_EVENT_STORAGE_NAME
			storage.Archivable = false
			storage.Parent = ReplicatedStorage
		end

		local event = storage:FindFirstChild(name)
		if event then
			return event
		end

		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Archivable = false
		event.Parent = storage

		return event
	end
else -- RunService:IsClient()
	return function(name)
		assert(type(name) == "string", "Bad name")

		return ReplicatedStorage:WaitForChild(ResourceConstants.REMOTE_EVENT_STORAGE_NAME):WaitForChild(name)
	end
end