-- @original Quenty
-- @author Narrev
-- @readme https://github.com/Narrev/Nevermore
-- Nevermore Loader

-- Configuration
local DEBUG_MODE = false -- Helps identify which modules fail to load
local ServerScriptService_Module_Folder_Name = "Nevermore"
local Classes = { -- Allows for abbreviations
	Event = "RemoteEvent";
	Function = "RemoteFunction";
}

-- Services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Module
local self = {__metatable = "[Nevermore] Cannot change metatable because Nevermore relies on __index for procedural generation"}
local LibraryCache = {}
local ServerModules = ServerScriptService:FindFirstChild(ServerScriptService_Module_Folder_Name)
local RetrieveObject, Repository

-- Error for incorrect setup
assert(script:IsA("ModuleScript"), "[Nevermore] Nevermore must be a ModuleScript")
assert(script.Name ~= "ModuleScript", "[Nevermore] Nevermore was never given a name")
assert(script.Parent == ReplicatedStorage, "[Nevermore] Nevermore must be parented to ReplicatedStorage")

-- Helper functions
local function extract(...) -- Enables functions to support calling by '.' or ':'
	if ... == self then
		return select(2, ...)
	else
		return ...
	end
end

local function Cache(Object, Name)
	if Object:IsA("ModuleScript") then
		assert(not LibraryCache[Name], "[Nevermore] Duplicate Module with name \"" .. Name .. "\"")
		LibraryCache[Name] = Object
	end
end

local function CacheAssemble(Object)
	local Children = Object:GetChildren()
	for a = 1, #Children do
		local Object = Children[a]
		local Name = Object.Name
		Cache(CacheAssemble(Object), Name) -- Caches objects that lack descendants first
	end
	return Object
end

if RunService:IsServer() then
	function RetrieveObject(Table, Name, Folder, Class) -- This is what allows the client / server to run the same code
		local Object = Folder:FindFirstChild(Name) or Instance.new(Class, Folder)
		Object.Name, Object.Archivable = Name
		Table[Name] = Object
		return Object
	end

	if not RunService:IsStudio() then
		function Cache(Object, Name)
			if Object:IsA("ModuleScript") then
				assert(not LibraryCache[Name], "[Nevermore] Duplicate Module with name \"" .. Name .. "\"")
				LibraryCache[Name] = Object
				Object.Parent = string.find(string.lower(Name), "server") and ServerModules or Repository
			elseif not Object:IsA("Script") then
				Object:Destroy()
			end
		end
	end
else
	function RetrieveObject(Table, Name, Folder) -- This is what allows the client / server to run the same code
		local Object = Folder:WaitForChild(Name)
		Table[Name] = Object
		return Object
	end
end

function self:Folder() -- This gets cleaned by Repository declaration
	return RetrieveObject(self, "NevermoreResources", ReplicatedStorage, "Folder")
end

function self:__index(index) -- Using several strings for the same method (e.g. Event and GetRemoteEvent) is slightly less efficient
	assert(type(index) == "string", "[Nevermore] Method must be a string")
	local originalIndex = index
	local index = string.gsub(index, "^Get", "")
	local Class = Classes[index] or index
	local Table = {}
	local Folder = self:Folder(Class .. "s")

	local function Function(...)
		local Name, Parent = extract(...)
		return Table[Name] or RetrieveObject(Table, Name, Parent or Folder, Class)
	end

	self[originalIndex] = Function
	return Function
end

Repository = self:__index("Folder")("Modules") -- Generates Folder manager and grabs Module folder
CacheAssemble(ServerModules or Repository) -- Assembles table LibraryCache

function self:Module(...)
	local Name = extract(...)
	return type(Name) ~= "string" and error("[Nevermore] ModuleName must be a string") or require(LibraryCache[Name] or error("[Nevermore] Module \"" .. Name .. "\" does not exist."))
end
self.LoadLibrary = self.Module

function self:Append(index) -- Because metatables cannot yield across the C boundary :/
	local Appendage = script:FindFirstChild(index)

	if Appendage and Appendage:IsA("ModuleScript") then
		local func = require(Appendage)
		local function Function(...)
			return func(extract(...))
		end

		self[index] = Function
		return Function
	else
		error("Appendage " .. index .. " doesn't exist")
	end
end

function self:__call(str, ...)
	if ... then
		return self[str](...)
	else
		return self:Module(str)
	end
end

if DEBUG_MODE then
	local GetModule = self.Module
	local DebugID, RequestDepth = 0, 0

	function self:Module(...)
		local Name = extract(...)
		DebugID = DebugID + 1
		local LocalDebugID = DebugID
		print(string.rep("\t", RequestDepth), LocalDebugID, "Loading:", Name)
		RequestDepth = RequestDepth + 1
		local Library = GetModule(Name)
		RequestDepth = RequestDepth - 1
		print(string.rep("\t", RequestDepth), LocalDebugID, "Done loading:", Name)
		return Library
	end
end

return setmetatable(self, self)
