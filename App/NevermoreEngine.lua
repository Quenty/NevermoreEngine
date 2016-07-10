-- Simplifies module loading for the purpose of creating a unified server-client codebase
-- @author Quenty
-- @author Narrev

local DEBUG_MODE = false -- Helps identify which libraries fail to load

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

assert(script:IsA("ModuleScript"), "[NevermoreEngine] NevermoreEngine must be a ModuleScript")
assert(script.Name == "NevermoreEngine", "[NevermoreEngine] NevermoreEngine must be named \"NevermoreEngine\"")
assert(script.Parent == ReplicatedStorage, "[NevermoreEngine] NevermoreEngine must be parented to ReplicatedStorage")

local LibraryCache = {} do -- Assemble Library Cache
	local ReplicationFolder, Repository

	local function AssembleCache(Instance)
		local Children = Instance:GetChildren()
		for a = 1, #Children do
			local Child = Children[a]
			local Name = Child.Name
			AssembleCache(Child)
			
			if Child:IsA("ModuleScript") then
				assert(not LibraryCache[Name], "[NevermoreEngine] Duplicate Library with name of \"" .. Name .. "\"")
				LibraryCache[Name] = Child
				if ReplicationFolder then
					Child.Parent, Child.Archivable = string.find(string.lower(Name), "server") and Repository or ReplicationFolder
				end
			elseif ReplicationFolder and not Child:IsA("Script") then
				Child:Destroy()
			end
		end
	end

	if RunService:IsServer() then
		local function CreateFolder(Parent, Name)
			local Instance = Parent:FindFirstChild(Name) or Instance.new("Folder", Parent)
			Instance.Name, Instance.Archivable = Name
			return Instance
		end		
		local ResourceFolder = CreateFolder(ReplicatedStorage, "NevermoreResources")
		ReplicationFolder = not RunService:IsStudio() and CreateFolder(ResourceFolder, "Modules")
		Repository = CreateFolder(game:GetService("ServerScriptService"), "Nevermore")
	else
		Repository = ReplicatedStorage:WaitForChild("NevermoreResources"):WaitForChild("Modules")
	end
	AssembleCache(Repository)
end

local function LoadLibrary(LibraryName)
	return type(LibraryName) ~= "string" and error("[NevermoreEngine] LibraryName must be a string") or require(LibraryCache[LibraryName] or error("[NevermoreEngine] Library \"" .. LibraryName .. "\" does not exist."))
end

if DEBUG_MODE then
	local Load = LoadLibrary
	local DebugID, RequestDepth = 0, 0

	function LoadLibrary(LibraryName)
		DebugID = DebugID + 1
		local LocalDebugID = DebugID
		print(string.rep("\t", RequestDepth), LocalDebugID, "Loading:", LibraryName)
		RequestDepth = RequestDepth + 1
		local Library = Load(LibraryName)
		RequestDepth = RequestDepth - 1
		print(string.rep("\t", RequestDepth), LocalDebugID, "Done loading:", LibraryName)
		return Library
	end
end

local Nevermore = {LoadLibrary = LoadLibrary, Load = LoadLibrary}

function Nevermore:__index(i) -- Nevermore calls from RemoteManager if indexed
	self.__index = LoadLibrary("RemoteManager")
	return self[i]
end

function Nevermore:__call(LibraryName)
	return LoadLibrary(LibraryName)
end

return setmetatable(Nevermore, Nevermore)
