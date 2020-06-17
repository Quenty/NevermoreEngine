--- Creates a service that provides modules from a parent module, either by name, or by list!
-- @classmod ModuleProvider

local ModuleProvider = {}
ModuleProvider.ClassName = "ModuleProvider"
ModuleProvider.__index = ModuleProvider

function ModuleProvider.new(parent, checkModule, initModule, sortList)
	local self = setmetatable({}, ModuleProvider)

	assert(typeof(parent) == "Instance")
	assert(checkModule == nil or type(checkModule) == "function")
	assert(initModule == nil or type(initModule) == "function")
	assert(sortList == nil or type(sortList) == "function")

	self._parent = parent or error("No parent")

	self._initModule = initModule
	self._checkModule = checkModule
	self._sortList = sortList

	return self
end

function ModuleProvider:Init()
	assert(not self._modulesList)

	self._modulesList = {}
	self._moduleScriptToModule = {}
	self._registry = {}

	self:_processFolder(self._parent)

	if self._sortList then
		self._sortList(self._modulesList)
	end

	if self._initModule then
		for moduleScript, _module in pairs(self._moduleScriptToModule) do
			self._initModule(_module, moduleScript)
		end
	end

	self._moduleScriptToModule = nil
end

function ModuleProvider:GetModules()
	assert(self._modulesList, "Not initialized yet")

	return self._modulesList
end

function ModuleProvider:GetFromName(name)
	assert(self._registry, "Not initialized yet")
	assert(type(name) == "string")

	return self._registry[name]
end

function ModuleProvider:_processFolder(folder)
	for _, moduleScript in pairs(folder:GetChildren()) do
		if moduleScript:IsA("ModuleScript") then
			self:_addToRegistery(moduleScript)
		else
			self:_processFolder(moduleScript)
		end
	end
end

function ModuleProvider:_addToRegistery(moduleScript)
	if self._registry[moduleScript.Name] then
		error(("[ModuleProvider._addToRegistery] - Duplicate %q in registery")
			:format(moduleScript.Name))
	end

	local _module
	xpcall(function()
		_module = require(moduleScript)
	end, function(err)
		error(("[ModuleProvider._addToRegistery] - Failed to load %q due to %q")
			:format(moduleScript:GetFullName(), tostring(err)))
	end)

	if self._checkModule then
		local ok, err = self._checkModule(_module, moduleScript)
		if not ok then
			error(("[ModuleProvider] - Bad module %q - %q")
				:format(moduleScript:GetFullName(), tostring(err)))
		end
	end

	table.insert(self._modulesList, _module)
	self._moduleScriptToModule[moduleScript] = _module
	self._registry[moduleScript.Name] = _module
end

return ModuleProvider