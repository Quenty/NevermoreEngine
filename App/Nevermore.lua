--- Nevermore module loader.
-- Used to simply resource loading and networking so a more unified server / client codebased can be used
-- @module Nevermore

local DEBUG_MODE = false -- Set to true to help identify what libraries have circular dependencies

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

assert(script:IsA("ModuleScript"), "Invalid script type. For Nevermore to work correctly, it should be " ..
	"a ModuleScript named \"Nevermore\" parented to ReplicatedStorage")
assert(script.Name == "Nevermore", "Invalid script name. For Nevermore to work correctly, it should be " ..
	"a ModuleScript named \"Nevermore\" parented to ReplicatedStorage")
assert(script.Parent == ReplicatedStorage, "Invalid parent. For Nevermore to work correctly, it should be " ..
	"a ModuleScript named \"Nevermore\" parented to ReplicatedStorage")

local AsyncMemoizer = {}
AsyncMemoizer.ClassName = "AsyncMemoizer"
AsyncMemoizer.__index = AsyncMemoizer

--- Caches single argument of an asyncronious function
function AsyncMemoizer.new(func)
	assert(type(func) == "function", "func must be a function")
	local self = setmetatable({}, AsyncMemoizer)

	self._func = func
	self._cache = {}
	self._pending = {}

	return function(arg)
		return self:_pend(arg)
	end
end

function AsyncMemoizer:_pend(arg)
	if self._cache[arg] ~= nil then
		return self._cache[arg]
	end

	if self._pending[arg] then
		self._pending[arg].Event:Wait()
		return self._cache[arg]
	end

	self._pending[arg] = Instance.new("BindableEvent")

	local result = self._func(arg)
	assert(result ~= nil, "result cannot be nil")

	self._cache[arg] = result

	self._pending[arg]:Fire()
	self._pending[arg]:Destroy()
	self._pending[arg] = nil

	return result
end

--- Retrieves an instance from a parent
local function retrieve(parent, className)
	assert(type(className) == "string", "Error: className must be a string")
	assert(typeof(parent) == "Instance", ("Error: parent must be an Instance, got '%s'"):format(typeof(parent)))

	return RunService:IsServer() and function(name)
		local rbxObject = parent:FindFirstChild(name)
		if not rbxObject then
			rbxObject = Instance.new(className)
			rbxObject.Archivable = false
			rbxObject.Name = name
			rbxObject.Parent = parent
		end
		return rbxObject
	end or function(name)
		local resource = parent:WaitForChild(name, 5)

		if resource then
			return resource
		end

		warn(("Warning: No '%s' found, be sure to require '%s' on the server. Yielding for '%s'")
			:format(tostring(name), tostring(name), className))

		return parent:WaitForChild(name)
	end
end

local function getRepository(getSubFolder)
	if RunService:IsServer() then
		local repositoryFolder = ServerScriptService:FindFirstChild("Nevermore")

		if not repositoryFolder then
			warn("Warning: No repository of Nevermore modules found (Expected in ServerScriptService with name \"Nevermore\")" ..
				". Library retrieval will fail.")

			repositoryFolder = Instance.new("Folder")
			repositoryFolder.Name = "Nevermore"
		end

		return repositoryFolder
	else
		return getSubFolder("Modules")
	end
end

local function getLibraryCache(repositoryFolder)
	local libCache = {}

	for _, child in pairs(repositoryFolder:GetDescendants()) do
		if child:IsA("ModuleScript") and not child:FindFirstAncestorOfClass("ModuleScript") then
			if libCache[child.Name] then
				warn(("Warning: Duplicate name of '%s' already exists! Using first found!"):format(child.Name))
			end

			libCache[child.Name] = child
		end
	end

	return libCache
end

local function replicateRepository(replicationFolder, libCache)
	for name, library in pairs(libCache) do
		if not name:lower():find("server") then
			library.Parent = replicationFolder
		end
	end
end

local function debugLoading(func)
	local count = 0
	local depth = 0

	return function(module, ...)
		count = count + 1
		local LibraryID = count
		local StartTime = tick()

		if DEBUG_MODE then
			print(("\t"):rep(depth), LibraryID, "Loading: ", module)
			depth = depth + 1
		end

		local result = func(module, ...)

		if DEBUG_MODE then
			depth = depth - 1
			print(("\t"):rep(depth), LibraryID, "Done loading: ", module, "in", tick() - StartTime)
		end

		return result
	end
end

local function getLibraryLoader(libCache)
	return function(module)
		if typeof(module) == "Instance" and module:IsA("ModuleScript") then
			return require(module)
		elseif type(module) == "string" then
			local moduleScript = libCache[module] or error("Error: Library '" .. module .. "' does not exist.", 2)
			return require(moduleScript)
		else
			error(("Error: module must be a string or ModuleScript, got '%s' for '%s'"):format(typeof(module), tostring(module)))
		end
	end
end

local resourceFolder = retrieve(ReplicatedStorage, "Folder")("NevermoreResources")
local getSubFolder = retrieve(resourceFolder, "Folder")
local repositoryFolder = getRepository(getSubFolder)
local libCache = getLibraryCache(repositoryFolder)
if RunService:IsServer() and not RunService:IsClient() then -- Don't move in SoloTestMode
	replicateRepository(getSubFolder("Modules"), libCache)
end

local lib = {}

--- Load a library
-- @function LoadLibrary
-- @tparam Variant LibraryName Can either be a ModuleScript or string
-- @treturn Variant Library
lib.LoadLibrary = AsyncMemoizer.new(debugLoading(getLibraryLoader(libCache)))
lib.require = lib.LoadLibrary

--- Get a remote event
-- @function GetRemoteEvent
-- @tparam string RemoteEventName
-- @treturn RemoteEvent RemoteEvent
lib.GetRemoteEvent = AsyncMemoizer.new(retrieve(getSubFolder("RemoteEvents"), "RemoteEvent"))

--- Get a remote function
-- @function GetRemoteFunction
-- @tparam string RemoteFunctionName
-- @treturn RemoteFunction RemoteFunction
lib.GetRemoteFunction = AsyncMemoizer.new(retrieve(getSubFolder("RemoteFunctions"), "RemoteFunction"))

setmetatable(lib, {
	__call = function(self, ...)
		return self.LoadLibrary(...)
	end;
	__index = function(self, index)
		return lib.LoadLibrary(index)
	end;
})

return lib