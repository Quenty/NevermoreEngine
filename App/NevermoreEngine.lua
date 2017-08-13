-- Intent: To simply resource loading and networking so a more unified server / client codebased can be used
-- @author Quenty

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- DEBUG_MODE helps you identify what libraries are failing to load.
local DEBUG_MODE = false

assert(script:IsA("ModuleScript"),  "Invalid script type. For NevermoreEngine to work correctly, it should be a ModuleScript named \"NevermoreEngine\" parented to ReplicatedStorage")
assert(script.Name == "NevermoreEngine", "Invalid script name. For NevermoreEngine to work correctly, it should be a ModuleScript named \"NevermoreEngine\" parented to ReplicatedStorage")
assert(script.Parent == ReplicatedStorage,  "Invalid parent. For NevermoreEngine to work correctly, it should be a ModuleScript named \"NevermoreEngine\" parented to ReplicatedStorage")

local Nevermore = {}

local function CallOnChildren(Instance, FunctionToCall)
	-- Calls a function on each of the children of a certain object, using recursion.  
	-- Exploration note: Parents are always called before children.
	
	FunctionToCall(Instance)

	for _, Child in next, Instance:GetChildren() do
		CallOnChildren(Child, FunctionToCall)
	end
end

local function HandleRetrieving(Retrieving, Function, Argument)
	-- Handles yielded operations by caching the retrieval process
	assert(type(Retrieving) == "table", "Error: Retrieving must be a table")
	assert(type(Function) == "function", "Error: Function must be a function")

	local Signal = Instance.new("BindableEvent")
	local Result
	Retrieving[Argument] = function()
		return Result ~= nil and Result or Signal.Event:wait()
	end;

	Result = Function(Argument)
	Retrieving[Argument] = nil
	Signal:Fire(Result)
	
	return Result
end

local function Cache(Function)
	-- Caches single argument, single output only

	assert(type(Function) == "function", "Error: Function must be a userdata")

	local Cache = {}
	local Retrieving = {}

	return function(Argument)
		assert(Argument ~= nil, "Error: ARgument ")
		if Cache[Argument] then
			return Cache[Argument]
		elseif Retrieving[Argument] then
			return Retrieving[Argument]()
		else
			Cache[Argument] = HandleRetrieving(Retrieving, Function, Argument)
			return Cache[Argument]
		end
	end
end

local function Retrieve(Parent, ClassName)
	assert(type(ClassName) == "string", "Error: ClassName must be a string")
	assert(type(Parent) == "userdata", "Error: Parent must be a userdata")

	return RunService:IsServer() and function(Name)
		local Item = Parent:FindFirstChild(Name)
		if not Item then
			Item = Instance.new(ClassName)
			Item.Archivable = false
			Item.Name = Name
			Item.Parent = Parent
		end
		return Item
	end or function(Name)
		return Parent:WaitForChild(Name)
	end
end

local ResourceFolder = Retrieve(ReplicatedStorage, "Folder")("NevermoreResources")

local _LibraryCache = {} do
	local Repository
	if RunService:IsServer() then
		Repository = ServerScriptService:FindFirstChild("Nevermore")

		if not Repository then
			warn("Warning: No repository of Nevermore modules found (Expected in ServerScriptService with name \"Nevermore\"). Library retrieval will fail.")

			-- Make sure the client Nevermore still loads
			Repository = Instance.new("Folder")
			Repository.Name = "Nevermore"
		end
	else
		Repository = ResourceFolder:WaitForChild("Modules")
	end

	CallOnChildren(Repository, function(Child)
		if Child:IsA("ModuleScript") then
			assert(not _LibraryCache[Child.Name], "Error: Duplicate name of '" .. Child.Name .. "' already exists")

			_LibraryCache[Child.Name] = Child
		end
	end)

	if not RunService:IsClient() then -- Written in this "not" fashion specifically so SoloTestMode doesn't move items.
		local ReplicationFolder = ResourceFolder:FindFirstChild("Modules") 
		
		if not ReplicationFolder then
			ReplicationFolder = Instance.new("Folder")
			ReplicationFolder.Name = "Modules"
			ReplicationFolder.Archivable = false
			ReplicationFolder.Parent = ResourceFolder
		end
		
		for Name, Library in pairs(_LibraryCache) do
			if not Name:lower():find("server") then
				Library.Parent = ReplicationFolder
			end
		end
	end
end

do
	local SecondCache = {}
	local DebugID = 0
	local RequestDepth = 0

	function Nevermore.LoadLibrary(LibraryName)
		--- Loads a library from Nevermore's library cache
		-- @param LibraryName The name of the library
		-- @return The library's value
		assert(type(LibraryName) == "string", "Error: LibraryName must be a string")

		if SecondCache[LibraryName] then
			return SecondCache[LibraryName]
		end

		DebugID = DebugID + 1
		local LocalDebugID = DebugID

		if DEBUG_MODE then
			print(("\t"):rep(RequestDepth), LocalDebugID, "Loading: ", LibraryName)
			RequestDepth = RequestDepth + 1
		end

		local Library = require(_LibraryCache[LibraryName] or error("Error: Library '" .. LibraryName .. "' does not exist."))
		SecondCache[LibraryName] = Library

		if DEBUG_MODE then
			RequestDepth = RequestDepth - 1
			print(("\t"):rep(RequestDepth), LocalDebugID, "Done loading: ", LibraryName)
		end

		return Library
	end
end

Nevermore.GetRemoteEvent = Cache(
	Retrieve(Retrieve(ResourceFolder, "Folder")("RemoteEvents"), -- Folder of remote events
	"RemoteEvent")) -- Specify remote events to retrieve
Nevermore.GetRemoteFunction = Cache(
	Retrieve(Retrieve(ResourceFolder, "Folder")("RemoteFunctions"), -- Folder of remote functions
	"RemoteFunction")) -- Specify remote functions to retrieve

return Nevermore
