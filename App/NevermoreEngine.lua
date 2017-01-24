-- Simplifies resource loading and networking for a more unified server-client codebase
-- @author Quenty
-- @editor Narrev

-- Services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- DEBUG_MODE helps you identify what libraries are failing to load.
local DEBUG_MODE = false

-- Assertions
assert(script:IsA("ModuleScript"),  "Invalid script type. For NevermoreEngine to work correctly, it should be a ModuleScript named \"NevermoreEngine\" parented to ReplicatedStorage")
assert(script.Name == "NevermoreEngine", "Invalid script name. For NevermoreEngine to work correctly, it should be a ModuleScript named \"NevermoreEngine\" parented to ReplicatedStorage")
assert(script.Parent == ReplicatedStorage,  "Invalid parent. For NevermoreEngine to work correctly, it should be a ModuleScript named \"NevermoreEngine\" parented to ReplicatedStorage")

-- Assemble _LibraryCache
local _LibraryCache = {} do
	
	-- Helper functions
	local Instance = Instance.new

	local function Make(ClassType, Properties)
		--- Make a new Instance of ClassType with Properties
		local Instance = Instance(ClassType) 
		for Index, Value in next, Properties do
			Instance[Index] = Value
		end
		return Instance
	end

	local function CacheChildren(Instance)
		-- Caches children of Instance into _LibraryCache
		-- Note: Parents are always called before children.

		local Children = Instance:GetChildren()
		for a = 1, #Children do
			local Child = Children[a]
			if Child:IsA("ModuleScript") then
				assert(not _LibraryCache[Child.Name], "Error: Duplicate name of \"" .. Child.Name .. "\" already exists")
				_LibraryCache[Child.Name] = Child
			end
			CacheChildren(Child)
		end
	end

	-- Declare local variables
	local ResourceFolder, Repository

	if RunService:IsServer() then
		-- In regular server, run only if it is on the server
		-- Always runs on SoloTestMode, on both client and server
		ResourceFolder = ReplicatedStorage:FindFirstChild("NevermoreResources") or Make("Folder", {
			Parent = ReplicatedStorage;
			Archivable = false;
			Name = "NevermoreResources";
		})

		Repository = ServerScriptService:FindFirstChild("Nevermore")

		if not Repository then
			warn("Warning: No repository of Nevermore modules found (Expected in ServerScriptService with name \"Nevermore\"). Library retrieval will fail.")

			-- Make sure the client Nevermore still loads
			Repository = Instance("Folder", ResourceFolder)
			Repository.Name = "Nevermore"
		end
	else
		-- In regular server, run only if it is on client
		-- Does not run in SoloTestMode
		ResourceFolder = ReplicatedStorage:WaitForChild("NevermoreResources")
		Repository = ResourceFolder:WaitForChild("Modules")
	end

	CacheChildren(Repository)

	if not RunService:IsClient() then
		-- In regular server, run only if it is on server
		-- Does not run in SoloTestMode

		local find = string.find
		local lower = string.lower

		local ReplicationFolder = ResourceFolder:FindFirstChild("Modules") or Make("Folder", {
			Name = "Modules";
			Archivable = false;
			Parent = ResourceFolder;
		})

		for Name, Library in next, _LibraryCache do
			if not find(lower(Name), "server") then -- Anything with Server in the Name is not put in ReplicationFolder
				Library.Parent = ReplicationFolder
			end
		end
	end

end

-- LoadLibrary function
local function LoadLibrary(LibraryName)
	assert(type(LibraryName) == "string", "Error: LibraryName must be a string")
	return require(_LibraryCache[LibraryName] or error("Error: Library \"" .. LibraryName .. "\" does not exist."))
end

if DEBUG_MODE then
	
	local Load = LoadLibrary
	local DebugID = 0
	local RequestDepth = 0
	local rep = string.rep

	function LoadLibrary(LibraryName)
		--- Loads a library from Nevermore's library cache
		-- @param LibraryName The name of the library
		-- @return The library's value

		DebugID = DebugID + 1
		local LocalDebugID = DebugID

		print(rep("\t", RequestDepth), LocalDebugID, "Loading: ", LibraryName)
		RequestDepth = RequestDepth + 1

		local Library = Load(LibraryName)

		RequestDepth = RequestDepth - 1
		print(rep("\t", RequestDepth), LocalDebugID, "Done loading: ", LibraryName)
		return Library
	end
end

-- Return Nevermore / LoadLibrary function
return setmetatable({LoadLibrary = LoadLibrary}, {__call = function(_, LibraryName) return LoadLibrary(LibraryName) end})
