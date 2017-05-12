-- @author Validark
-- @readme https://github.com/NevermoreFramework/Nevermore

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Configuration
local FolderName = "Modules" -- Name of Module Folder in ModuleRepositoryLocation
local ModuleRepositoryLocation = ServerScriptService
local ResourcesLocation = ReplicatedStorage -- Where the "Resources" folder is, it will be generated if needed

local Classes = { -- Allows for abbreviations
	Event = "RemoteEvent"; -- You can use Nevermore:GetEvent() instead of GetRemoteEvent()
	Function = "RemoteFunction";
}

local Plurals = { -- If you want to name the folder something besides [Name .. "s"]
	Accessory = "Accessories";
	Folder = script.Name;
}

if script.Name == "ModuleScript" then error("[Nevermore] Nevermore was never given a name") end
if script.ClassName ~= "ModuleScript" then error("[Nevermore] Nevermore must be a ModuleScript") end
if script.Parent ~= ReplicatedStorage then error("[Nevermore] Nevermore must be parented to ReplicatedStorage") end

local function GetFirstChild(Parent, Name, Class) -- This is what allows the client / server to run the same code
	local Object, Bool = Parent:FindFirstChild(Name)

	if not Object then
		Object = Instance.new(Class, Parent)
		Object.Name = Name
		Bool = true
	end

	return Object, Bool
end

local function Error(Parent, Name, Class)
	return Parent:FindFirstChild(Name) or error(("[Nevermore] %s \"%s\" is not installed."):format(Class, Name))
end

local Nevermore = {GetFirstChild = GetFirstChild}
local SmartFolder = {}
local Retrieve, LocalResourcesLocation = GetFirstChild

function SmartFolder:__call(this, Name, Parent)
	if this ~= Nevermore then -- Enables functions to support calling by '.' or ':'
		Name, Parent = this, Name
	end
	local Contents = self.Contents
	local Object, Bool = Contents[Name]
	if not Object then
		local Folder, Class = self.Folder, self.Class
		if not Folder then
			Folder = self.GetFolder(Plurals[Class] or Class .. "s")
			self.Folder = Folder
		end
		Object, Bool = self.Retrieve(Parent or Folder, Name, Class)
		if not Parent then
			Contents[Name] = Object
		end
	end
	return Object, Bool or false
end

local GetFolder = setmetatable({
	Class = "Folder";
	Contents = {};
	Retrieve = GetFirstChild;
	GetFolder = function() -- Placeholder for first time `CreateResourceManager` runs; gets overwritten
		return GetFirstChild(ResourcesLocation, "Resources", "Folder")
	end;
}, SmartFolder)

local GetLocalFolder = setmetatable({
	Class = "Folder";
	Contents = {};
	Retrieve = Retrieve;
	GetFolder = function() -- Placeholder for first time `CreateResourceManager` runs; gets overwritten
		return Retrieve(LocalResourcesLocation, "Resources", "Folder")
	end;
}, SmartFolder)

local Modules do -- Assembles table `Modules`
	if RunService:IsServer() then
		LocalResourcesLocation = ServerStorage
		local ModuleRepository = ModuleRepositoryLocation:FindFirstChild(FolderName) or LocalResourcesLocation:FindFirstChild("Resources") and LocalResourcesLocation.Resources:FindFirstChild("Modules")
		if ModuleRepository then
			ModuleRepository.Name = ModuleRepository.Name .. " " -- This is just in-case we try to create a new folder of the same name
			local Repository, ServerRepository, ServerStuff -- Repository folders
			local Boundaries = {} -- This is a system for keeping track of which items should be stored in ServerStorage (vs ReplicatedStorage)
			local Count, BoundaryCount = 0, 0
			local NumDescendants, CurrentBoundary = 1, 1
			local LowerBoundary, SetsEnabled
			Modules = {ModuleRepository}

			repeat -- Most efficient way of iterating over every descendant of the Module Repository
				Count = Count + 1
				local Child = Modules[Count]
				local Name = Child.Name
				local ClassName = Child.ClassName
				local GrandChildren = Child:GetChildren()
				local NumGrandChildren = #GrandChildren

				if SetsEnabled then
					if not LowerBoundary and Count > Boundaries[CurrentBoundary] then
						LowerBoundary = true
					elseif LowerBoundary and Count > Boundaries[CurrentBoundary + 1] then
						CurrentBoundary = CurrentBoundary + 2
						local Boundary = Boundaries[CurrentBoundary]

						if Boundary then
							LowerBoundary = Count > Boundary
						else
							SetsEnabled = false
							LowerBoundary = false
						end
					end
				end

				local Server = LowerBoundary or Name:lower():find("server")

				if NumGrandChildren ~= 0 then
					if Server then
						SetsEnabled = true
						Boundaries[BoundaryCount + 1] = NumDescendants
						BoundaryCount = BoundaryCount + 2
						Boundaries[BoundaryCount] = NumDescendants + NumGrandChildren
					end

					for a = 1, NumGrandChildren do
						Modules[NumDescendants + a] = GrandChildren[a]
					end
					NumDescendants = NumDescendants + NumGrandChildren
				end

				if ClassName == "ModuleScript" then
					if Server then
						Modules[Name] = Child
						if not ServerRepository then
							ServerRepository = GetLocalFolder("Modules")
						end
						Child.Parent = ServerRepository
					else
						if not Repository then
							Repository = GetFolder("Modules")
						end
						Child.Parent = Repository
						if not Modules[Name] then
							Modules[Name] = Child
						end
					end
				elseif ClassName ~= "Folder" and Child.Parent.ClassName == "Folder" then
					if not ServerStuff then
						ServerStuff = GetLocalFolder("Server", ServerScriptService)
					end
					Child.Parent = ServerStuff
				end
				Modules[Count] = nil
			until Count == NumDescendants
			ModuleRepository:Destroy()
		else
			warn(("[Nevermore] Couldn't find the module repository. It should be a descendant of %s named %s. This can be changed in the configuration section at the top of this module"):format(ModuleRepositoryLocation.Name, FolderName))
		end
	else
		LocalResourcesLocation = game:GetService("Players").LocalPlayer
		GetFirstChild = game.WaitForChild
		GetFolder.Retrieve = GetFirstChild
	end
end

local GetModule = setmetatable({
	Class = "Module";
	Contents = Modules or {};
	Retrieve = GetFirstChild == Retrieve and Error or GetFirstChild;
	GetFolder = GetFolder;
}, SmartFolder)

local LibraryCache = {}

function Nevermore:LoadLibrary(Name) -- Custom Require function
	Name = self ~= Nevermore and self or Name
	local Library = LibraryCache[Name]
	if Library == nil then
		Library = require(GetModule(Name))
		LibraryCache[Name] = Library or false -- caches "nil" as false
	end
	return Library
end

Nevermore.GetModule = GetModule
Nevermore.GetFolder = GetFolder
Nevermore.GetLocalFolder = GetLocalFolder

return setmetatable(Nevermore, {
	__call = Nevermore.LoadLibrary;
	__index = function(self, FullName)
		if type(FullName) == "string" then
			local GetFirstChild = GetFirstChild
			local Name, Local = FullName:gsub("^Get", ""):gsub("^Local", "")
			local Class = Classes[Name] or Name
			local ResourceManager = {
				Class = Class;
				Contents = {};
				Retrieve = GetFirstChild;
			}

			if Local == 0 then
				ResourceManager.GetFolder = GetFolder
			else
				ResourceManager.GetFolder = GetLocalFolder
				GetFirstChild = Retrieve
			end

			if GetFirstChild == Retrieve then
				local Success, Object = pcall(Instance.new, Class)
				ResourceManager.Retrieve = Success and not Object:Destroy() and GetFirstChild or Error
			end

			self[FullName] = ResourceManager
			return setmetatable(ResourceManager, SmartFolder)
		else
			error("[Nevermore] Attempt to index Nevermore with invalid key: string expected, got " .. type(FullName))
		end
	end;
	__metatable = "[Nevermore] Nevermore's metatable is locked";
})
