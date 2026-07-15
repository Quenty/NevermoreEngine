--!strict
--[=[
	Creates a service that provides modules from a parent module, either by name, or by list!
	@class ModuleProvider
]=]

local ModuleProvider = {}
ModuleProvider.ClassName = "ModuleProvider"
ModuleProvider.ServiceName = "ModuleProvider"
ModuleProvider.__index = ModuleProvider

export type ModuleCheckCallback = (module: any, moduleScript: ModuleScript) -> (boolean, any)
export type ModuleInitCallback = (module: any, moduleScript: ModuleScript) -> ()
export type ModuleSortCallback = (modulesList: { any }) -> ()

export type ModuleProvider = typeof(setmetatable(
	{} :: {
		_parent: Instance,
		_initModule: ModuleInitCallback?,
		_checkModule: ModuleCheckCallback?,
		_sortList: ModuleSortCallback?,
		_modulesList: { any },
		_moduleScriptToModule: { [ModuleScript]: any },
		_registry: { [string]: any },
	},
	{} :: typeof({ __index = ModuleProvider })
))

function ModuleProvider.new(
	parent: Instance,
	checkModule: ModuleCheckCallback?,
	initModule: ModuleInitCallback?,
	sortList: ModuleSortCallback?
): ModuleProvider
	local self: ModuleProvider = setmetatable({} :: any, ModuleProvider)

	assert(typeof(parent) == "Instance", "Bad parent")
	assert(checkModule == nil or type(checkModule) == "function", "Bad checkModule")
	assert(initModule == nil or type(initModule) == "function", "Bad initModule")
	assert(sortList == nil or type(sortList) == "function", "Bad sortList")

	self._parent = parent or error("No parent")

	self._initModule = initModule
	self._checkModule = checkModule
	self._sortList = sortList

	return self
end

function ModuleProvider.Init(self: ModuleProvider): ()
	assert(not (self :: any)._modulesList, "Already initialized")

	self._modulesList = {}
	self._moduleScriptToModule = {}
	self._registry = {}

	self:_processFolder(self._parent)

	if self._sortList then
		self._sortList(self._modulesList)
	end

	if self._initModule then
		for moduleScript, _module in self._moduleScriptToModule do
			self._initModule(_module, moduleScript)
		end
	end

	self._moduleScriptToModule = nil :: any
end

function ModuleProvider.GetModules(self: ModuleProvider): { any }
	assert(self._modulesList, "Not initialized yet")

	return self._modulesList
end

function ModuleProvider.GetFromName(self: ModuleProvider, name: string): any
	assert(self._registry, "Not initialized yet")
	assert(type(name) == "string", "Bad name")

	return self._registry[name]
end

function ModuleProvider._processFolder(self: ModuleProvider, folder: Instance): ()
	for _, moduleScript in folder:GetChildren() do
		if moduleScript:IsA("ModuleScript") then
			self:_addToRegistery(moduleScript)
		else
			self:_processFolder(moduleScript)
		end
	end
end

function ModuleProvider._addToRegistery(self: ModuleProvider, moduleScript: ModuleScript): ()
	if self._registry[moduleScript.Name] then
		error(string.format("[ModuleProvider._addToRegistery] - Duplicate %q in registery", moduleScript.Name))
	end

	local moduleParent = assert(moduleScript.Parent, "No moduleScript.Parent")
	if not moduleParent:FindFirstChild("loader") then
		local fakeLoader = script.Parent.ModuleProviderFakeLoader:Clone()
		fakeLoader.Name = "loader"
		fakeLoader.Archivable = false
		fakeLoader.Parent = moduleParent
	end

	local _module: any
	xpcall(function()
		_module = (require :: any)(moduleScript)
	end, function(err)
		error(
			string.format(
				"[ModuleProvider._addToRegistery] - Failed to load %q due to %q",
				moduleScript:GetFullName(),
				tostring(err)
			)
		)
	end)

	if self._checkModule then
		local ok, err = self._checkModule(_module, moduleScript)
		if not ok then
			error(string.format("[ModuleProvider] - Bad module %q - %q", moduleScript:GetFullName(), tostring(err)))
		end
	end

	table.insert(self._modulesList, _module)
	self._moduleScriptToModule[moduleScript] = _module
	self._registry[moduleScript.Name] = _module
end

return ModuleProvider
