-- Simplifies resource loading and networking for a more unified server-client codebase
-- @author Quenty
-- @editor Narrev

-- Services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- DEBUG_MODE helps you identify what libraries are failing to load.
local DEBUG_MODE = false

-- Localize Functions
local rep = string.rep
local find = string.find
local lower = string.lower
local Instance = Instance.new

assert(script:IsA("ModuleScript"),  "Invalid script type. For NevermoreEngine to work correctly, it should be a ModuleScript named \"NevermoreEngine\" parented to ReplicatedStorage")
assert(script.Name == "NevermoreEngine", "Invalid script name. For NevermoreEngine to work correctly, it should be a ModuleScript named \"NevermoreEngine\" parented to ReplicatedStorage")
assert(script.Parent == ReplicatedStorage,  "Invalid parent. For NevermoreEngine to work correctly, it should be a ModuleScript named \"NevermoreEngine\" parented to ReplicatedStorage")

-- Assemble _LibraryCache
local _LibraryCache = {} do
	
	-- Helper functions
	local function Make(ClassType, Properties)
		--- Make a new Instance of ClassType with Properties
		assert(type(Properties) == "table", "Properties is not a table")
		local Instance = Instance(ClassType) 
		for Index, Value in next, Properties do
			Instance[Index] = Value
		end
		return Instance
	end

	local function WaitForChild(Parent, Name, TimeLimit)
		-- Waits for a child to appear. Not efficient, but it shoudln't have to be. It helps with debugging. 
		-- Useful when ROBLOX lags out, and doesn't replicate quickly.
		-- @param TimeLimit If TimeLimit is given, then it will return after the timelimit, even if it hasn't found the child.

		assert(Parent ~= nil, "Parent is nil")
		assert(type(Name) == "string", "Name is not a string.")

		local Child     = Parent:FindFirstChild(Name)
		local StartTime = tick()
		local Warned    = false

		while not Child do
			wait(0)
			Child = Parent:FindFirstChild(Name)
			if not Warned and StartTime + (TimeLimit or 5) <= tick() then
				Warned = true
					warn("Warning: Infinite yield possible for WaitForChild(" .. Parent:GetFullName() .. ", " .. Name .. ")")
				if TimeLimit then
					return Parent:FindFirstChild(Name)
				end
			end
		end

		return Child
	end

	local function CallOnChildren(Instance, FunctionToCall)
		-- Calls a function on each of the children of a certain object, using recursion.  
		-- Note: Parents are always called before children.
		FunctionToCall(Instance)
		local Children = Instance:GetChildren()
		for a = 1, #Children do
			CallOnChildren(Children[a], FunctionToCall)
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
		ResourceFolder = WaitForChild(ReplicatedStorage, "NevermoreResources")
		Repository = WaitForChild(ResourceFolder, "Modules")
	end

	CallOnChildren(Repository, function(Child)
		if Child:IsA("ModuleScript") then
			assert(not _LibraryCache[Child.Name], "Error: Duplicate name of '" .. Child.Name .. "' already exists")

			_LibraryCache[Child.Name] = Child
		end
	end)

	if not RunService:IsClient() then
		-- In regular server, run only if it is on server
		-- Does not run in SoloTestMode
		local ReplicationFolder = ResourceFolder:FindFirstChild("Modules") or Make("Folder", {
			Name = "Modules";
			Archivable = false;
			Parent = ResourceFolder;
		})
		for Name, Library in pairs(_LibraryCache) do
			if not find(lower(Name), "server") then
				Library.Parent = ReplicationFolder
			end
		end
	end
end

-- LoadLibrary function
local LoadLibrary do
	if not DEBUG_MODE then
		function LoadLibrary(LibraryName)
			assert(type(LibraryName) == "string", "Error: LibraryName must be a string")
			return require(_LibraryCache[LibraryName] or error("Error: Library \"" .. LibraryName .. "\" does not exist."))
		end
	else
		local DebugID = 0
		local RequestDepth = 0

		function LoadLibrary(LibraryName)
			--- Loads a library from Nevermore's library cache
			-- @param LibraryName The name of the library
			-- @return The library's value
			assert(type(LibraryName) == "string", "Error: LibraryName must be a string")

			DebugID = DebugID + 1
			local LocalDebugID = DebugID

			print(rep("\t", RequestDepth), LocalDebugID, "Loading: ", LibraryName)
			RequestDepth = RequestDepth + 1

			local Library = require(_LibraryCache[LibraryName] or error("Error: Library \"" .. LibraryName .. "\" does not exist."))

			RequestDepth = RequestDepth - 1
			print(rep("\t", RequestDepth), LocalDebugID, "Done loading: ", LibraryName)
			return Library
		end
	end
end

-- Return Nevermore / LoadLibrary function
return setmetatable({LoadLibrary = LoadLibrary}, {__call = function(_, LibraryName) return LoadLibrary(LibraryName) end})
