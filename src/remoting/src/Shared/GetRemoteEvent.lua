--!strict
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
	return function(name: string): RemoteEvent
		local event = Instance.new("RemoteEvent")
		event.Archivable = false
		event.Name = "Mock" .. name

		return event
	end
elseif RunService:IsServer() then
	local function getOrCreateStorage(): Instance
		local storage = ReplicatedStorage:FindFirstChild(ResourceConstants.REMOTE_EVENT_STORAGE_NAME)
		if storage then
			return storage
		end

		local created = Instance.new("Folder")
		created.Name = ResourceConstants.REMOTE_EVENT_STORAGE_NAME
		created.Archivable = false
		created.Parent = ReplicatedStorage
		return created
	end

	return function(name: string): RemoteEvent
		assert(type(name) == "string", "Bad name")

		local storage = getOrCreateStorage()

		local event = storage:FindFirstChild(name)
		if event and event:IsA("RemoteEvent") then
			return event
		end

		local created = Instance.new("RemoteEvent")
		created.Name = name
		created.Archivable = false
		created.Parent = storage

		return created
	end
else -- RunService:IsClient()
	return function(name: string): RemoteEvent
		assert(type(name) == "string", "Bad name")

		local found = ReplicatedStorage:WaitForChild(ResourceConstants.REMOTE_EVENT_STORAGE_NAME):WaitForChild(name)
		if found and found:IsA("RemoteEvent") then
			return found
		end

		error("Could not find remote event " .. name)
	end
end
