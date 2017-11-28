-- Intent: To simply resource loading and networking so a more unified server / client codebased can be used

local DEBUG_MODE = false -- Set to true to help identify what libraries have circular dependencies

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

assert(script:IsA("ModuleScript"), "Invalid script type. For NevermoreEngine to work correctly, it should be a ModuleScript named \"NevermoreEngine\" parented to ReplicatedStorage")
assert(script.Name == "NevermoreEngine", "Invalid script name. For NevermoreEngine to work correctly, it should be a ModuleScript named \"NevermoreEngine\" parented to ReplicatedStorage")
assert(script.Parent == ReplicatedStorage, "Invalid parent. For NevermoreEngine to work correctly, it should be a ModuleScript named \"NevermoreEngine\" parented to ReplicatedStorage")


--- Handles yielded operations by caching the retrieval process
local function _handleRetrieving(Retrieving, Function, Argument)
	assert(type(Retrieving) == "table", "Error: Retrieving must be a table")
	assert(type(Function) == "function", "Error: Function must be a function")

	local Signal = Instance.new("BindableEvent")
	local Result
	Retrieving[Argument] = function()
		if Result ~= nil and Result then
			return Result
		end
		
		Signal.Event:wait()
		return Result
	end

	Result = Function(Argument)
	assert(Result ~= nil, "Result cannot be nil")
	Retrieving[Argument] = nil
	Signal:Fire()
	Signal:Destroy()

	return Result
end

--- Caches single argument, single output only
local function _asyncCache(Function)
	assert(type(Function) == "function", "Error: Function must be a userdata")

	local Cache = {}
	local Retrieving = {}

	return function(Argument)
		assert(Argument ~= nil, "Error: ARgument ")
		if Cache[Argument] ~= nil then
			return Cache[Argument]
		elseif Retrieving[Argument] then
			return Retrieving[Argument]()
		else
			Cache[Argument] = _handleRetrieving(Retrieving, Function, Argument)
			return Cache[Argument]
		end
	end
end

--- Retrieves an instance from a parent
local function _retrieve(Parent, ClassName)
	assert(type(ClassName) == "string", "Error: ClassName must be a string")
	assert(typeof(Parent) == "Instance", "Error: Parent must be an Instance")

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
		local Resource = Parent:WaitForChild(Name, 5)
		if not Resource then
			warn(("Warning: No '%s' found, be sure to require '%s' on the server. Yielding for '%s'"):format(tostring(Name), tostring(Name), ClassName))
			return Resource:WaitForChild(Name)
		end
	end
end

local function _getRepository(GetSubFolder)
	if RunService:IsServer() then
		local RepositoryFolder = ServerScriptService:FindFirstChild("Nevermore")

		if not RepositoryFolder then
			warn("Warning: No repository of Nevermore modules found (Expected in ServerScriptService with name \"Nevermore\"). Library retrieval will fail.")
			RepositoryFolder = Instance.new("Folder")
			RepositoryFolder.Name = "Nevermore"
		end

		return RepositoryFolder
	else
		return GetSubFolder("Modules")
	end
end

local function _getLibraryCache(RepositoryFolder)
	local LibraryCache = {}
	
	for _, Child in pairs(RepositoryFolder:GetDescendants()) do
		if Child:IsA("ModuleScript") then
			if LibraryCache[Child.Name] then
				error(("Error: Duplicate name of '%s' already exists"):format(Child.Name))
			end

			LibraryCache[Child.Name] = Child
		end
	end

	return LibraryCache
end

local function _replicateRepository(ReplicationFolder, LibraryCache)	
	for Name, Library in pairs(LibraryCache) do
		if not Name:lower():find("server") then
			Library.Parent = ReplicationFolder
		end
	end
end

local function _debugLoading(Function)
	local Count = 0
	local RequestDepth = 0

	return function(Module, ...)
		Count = Count + 1
		local LibraryID = Count
		
		if DEBUG_MODE then
			print(("\t"):rep(RequestDepth), LibraryID, "Loading: ", Module)
			RequestDepth = RequestDepth + 1
		end

		local Result = Function(Module, ...)

		if DEBUG_MODE then
			RequestDepth = RequestDepth - 1
			print(("\t"):rep(RequestDepth), LibraryID, "Done loading: ", Module)
		end

		return Result
	end
end

--- Loads a library from Nevermore's library cache
-- @param Module The name of the library or a module
-- @return The library's value
local function _getLibraryLoader(LibraryCache)
	return function(Module)
		if typeof(Module) == "Instance" and Module:IsA("ModuleScript") then
			return require(Module)
		elseif type(Module) == "string" then
			local ModuleScript = LibraryCache[Module] or error("Error: Library '" .. Module .. "' does not exist.", 2)
			return require(ModuleScript)
		else
			error(("Error: Module must be a string or ModuleScript, got '%s'"):format(typeof(Module)))
		end
	end
end

local ResourceFolder = _retrieve(ReplicatedStorage, "Folder")("NevermoreResources")
local GetSubFolder = _retrieve(ResourceFolder, "Folder")
local RepositoryFolder = _getRepository(GetSubFolder)
local LibraryCache = _getLibraryCache(RepositoryFolder)
if RunService:IsServer() and not RunService:IsClient() then -- Don't move in SoloTestMode
	_replicateRepository(GetSubFolder("Modules"), LibraryCache)
end

local Nevermore = {}

Nevermore.LoadLibrary = _asyncCache(_debugLoading(_getLibraryLoader(LibraryCache)))
Nevermore.GetRemoteEvent = _asyncCache(_retrieve(GetSubFolder("RemoteEvents"), "RemoteEvent"))
Nevermore.GetRemoteFunction = _asyncCache(_retrieve(GetSubFolder("RemoteFunctions"), "RemoteFunction"))

setmetatable(Nevermore, {
	__call = Nevermore.LoadLibrary;
	__index = function(self, Index)
		error(("'%s is not a valid member of Nevermore"):format(tostring(Index)))
	end;
})

return Nevermore