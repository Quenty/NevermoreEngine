---
-- @classmod StaticLegacyLoader
-- @author Quenty

local loader = script.Parent
local ScriptInfoUtils = require(script.Parent.ScriptInfoUtils)
local LoaderUtils = require(script.Parent.LoaderUtils)
local BounceTemplateUtils = require(script.Parent.BounceTemplateUtils)

local StaticLegacyLoader = {}
StaticLegacyLoader.ClassName = "StaticLegacyLoader"
StaticLegacyLoader.__index = StaticLegacyLoader

function StaticLegacyLoader.new()
	local self = setmetatable({
		_packageLookups = {};
	}, StaticLegacyLoader)

	return self
end

function StaticLegacyLoader:__call(value)
	return self:Require(value)
end

function StaticLegacyLoader:Lock()
	error("Cannot start loader while not running")
end

function StaticLegacyLoader:Require(root, value)
	if type(value) == "number" then
		return require(value)
	elseif type(value) == "string" then
		-- use very slow module recovery mechanism
		local module = self:_findModule(root, value)
		if module then
			self:_ensureFakeLoader(module)
			return require(module)
		else
			error("Error: Library '" .. tostring(value) .. "' does not exist.", 2)
		end
	elseif typeof(value) == "Instance" and value:IsA("ModuleScript") then
		return require(value)
	else
		error(("Error: module must be a string or ModuleScript, got '%s' for '%s'")
			:format(typeof(value), tostring(value)))
	end
end

function StaticLegacyLoader:_findModule(root, name)
	assert(typeof(root) == "Instance", "Bad root")
	assert(type(name) == "string", "Bad name")

	-- Implement the node_modules recursive find algorithm
	local packageRoot = self:_findPackageRoot(root)
	while packageRoot do
		-- Build lookup
		local highLevelLookup = self:_getOrCreateLookup(packageRoot)
		if highLevelLookup[name] then
			return highLevelLookup[name]
		end

		-- Ok, search our package dependencies
		local dependencies = packageRoot:FindFirstChild(ScriptInfoUtils.DEPENDENCY_FOLDER_NAME)
		if dependencies then
			for _, instance in pairs(dependencies:GetChildren()) do
				if instance:IsA("Folder") and instance.Name:sub(1, 1) == "@" then
					for _, child in pairs(instance:GetChildren()) do
						local lookup = self:_getPackageFolderLookup(child)
						if lookup[name] then
							return lookup[name]
						end
					end
				else
					local lookup = self:_getPackageFolderLookup(instance)
					if lookup[name] then
						return lookup[name]
					end
				end
			end
		end

		-- We failed to find anything... search up a level...
		packageRoot = self:_findPackageRoot(packageRoot)
	end

	return nil
end

function StaticLegacyLoader:GetLoader(moduleScript)
	assert(typeof(moduleScript) == "Instance", "Bad moduleScript")

	return setmetatable({}, {
		__call = function(_self, value)
			return self:Require(moduleScript, value)
		end;
		__index = function(_self, key)
			return self:Require(moduleScript, key)
		end;
	})
end

function StaticLegacyLoader:_getPackageFolderLookup(instance)
	if instance:IsA("ObjectValue") then
		if instance.Value then
			return self:_getOrCreateLookup(instance.Value)
		else
			warn("Bad link in packageFolder")
			return {}
		end
	elseif instance:IsA("Folder") then
		return self:_getOrCreateLookup(instance)
	else
		warn(("Unknown instance in dependencyFolder - %q"):format(instance:GetFullName()))
		return {}
	end
end

function StaticLegacyLoader:_getOrCreateLookup(packageFolder)
	assert(typeof(packageFolder) == "Instance", "Bad packageFolder")

	if self._packageLookups[packageFolder] then
		return self._packageLookups[packageFolder]
	end

	local lookup = {}

	local function search(instance)
		for _, item in pairs(instance:GetChildren()) do
			if item:IsA("Folder") then
				if item.Name ~= ScriptInfoUtils.DEPENDENCY_FOLDER_NAME then
					search(item)
				end
			elseif item:IsA("ModuleScript") then
				lookup[item.Name] = item
			end
		end
	end

	search(packageFolder)

	self._packageLookups[packageFolder] = lookup
	return lookup
end

function StaticLegacyLoader:_findPackageRoot(instance)
	assert(typeof(instance) == "Instance", "Bad instance")

	local current = instance.Parent

	while current and current ~= game do
		if LoaderUtils.isPackage(current) then
			return current
		else
			current = current.Parent
		end
	end

	return nil
end

function StaticLegacyLoader:_ensureFakeLoader(module)
	assert(typeof(module) == "Instance", "Bad module")

	local parent = module.Parent
	if not parent then
		warn("[StaticLegacyLoader] - No parent")
		return
	end

	-- Already have link
	if parent:FindFirstChild("loader") then
		return
	end

	local link = BounceTemplateUtils.create(loader, "loader")
	link.Archivable = false -- Do not save this bad boy
	link.Parent = parent
end

return StaticLegacyLoader