--!strict
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
	If the game is not running, then a mock remote function will be created
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
	return function(name: string): RemoteFunction
		local func = Instance.new("RemoteFunction")
		func.Name = "Mock" .. name
		func.Archivable = false

		return func
	end
elseif RunService:IsServer() then
	local function getOrCreateStorage(): Instance
		local storage = ReplicatedStorage:FindFirstChild(ResourceConstants.REMOTE_FUNCTION_STORAGE_NAME)
		if storage then
			return storage
		end

		local created = Instance.new("Folder")
		created.Name = ResourceConstants.REMOTE_FUNCTION_STORAGE_NAME
		created.Archivable = false
		created.Parent = ReplicatedStorage

		return created
	end

	return function(name: string): RemoteFunction
		assert(type(name) == "string", "Bad name")

		local storage = getOrCreateStorage()
		local func = storage:FindFirstChild(name)
		if func and func:IsA("RemoteFunction") then
			return func
		end

		local created = Instance.new("RemoteFunction")
		created.Name = name
		created.Archivable = false
		created.Parent = storage

		return created
	end
else -- RunService:IsClient()
	return function(name: string): RemoteFunction
		assert(type(name) == "string", "Bad name")

		local found = ReplicatedStorage:WaitForChild(ResourceConstants.REMOTE_FUNCTION_STORAGE_NAME):WaitForChild(name)
		if found and found:IsA("RemoteFunction") then
			return found
		end

		error("Could not find remote function " .. name)
	end
end
