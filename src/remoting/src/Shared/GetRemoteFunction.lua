--[=[
	Provides getting named global [RemoteFunction] resources.

	@class GetRemoteFunction
]=]

--[=[
	Retrieves a global remote function from the store. On the server, it constructs a new one,
	and on the client, it waits for it to exist.

	:::tip
	Consider using [PromiseGetRemoteFunction] for a non-yielding version
	:::

	```lua
	-- server.lua
	local GetRemoteFunction = require("GetRemoteFunction")

	local remoteFunction = GetRemoteFunction("testing")
	remoteFunction.OnServerInvoke = function(_player, text)
		return "HI " .. tostring(text)
	end

	-- client.lua
	local GetRemoteFunction = require("GetRemoteFunction")

	local remoteFunction = GetRemoteFunction("testing")
	print(remoteFunction:InvokeServer("Bob")) --> HI Bob
	```

	:::info
	If the game is not running, then a mock remote event will be created
	for use in testing.
	:::

	@yields
	@function GetRemoteFunction
	@within GetRemoteFunction
	@param name string
	@return RemoteFunction
]=]

local require = require(script.Parent.loader).load(script)

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
		assert(type(name) == "string", "Bad name")

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
		assert(type(name) == "string", "Bad name")

		return ReplicatedStorage:WaitForChild(ResourceConstants.REMOTE_FUNCTION_STORAGE_NAME):WaitForChild(name)
	end
end