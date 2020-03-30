--- Provides modules behind
-- @classmod ModuleProvider

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")

local ModuleProvider = setmetatable({}, BaseObject)
ModuleProvider.ClassName = "ModuleProvider"
ModuleProvider.__index = ModuleProvider

function ModuleProvider.new(parent, checker, process)
	local self = setmetatable(BaseObject.new(), ModuleProvider)

	self._parent = parent or error("No parent")
	self._checker = checker or error("No checker")
	self._process = process or error("No process")

	return self
end

function ModuleProvider:Init()
	assert(not self._modulesList)

	self._modulesList = {}
	self._registry = {}

	self:_processParent(self._parent)
end


function ModuleProvider:GetModules()
	assert(self._modulesList)

	return self._modulesList
end

function ModuleProvider:GetFromName(name)
	return self._registry[name]
end

function ModuleProvider:_processParent(parent)
	for _, moduleScript in pairs(parent:GetChildren()) do
		if moduleScript:IsA("ModuleScript") then
			self:_addToRegistery(moduleScript)
		else
			self:_processParent(moduleScript)
		end
	end
end

function ModuleProvider:_addToRegistery(moduleScript)
	if self._registry[moduleScript.Name] then
		error(("[BehaviorNodeClassRegistery._addToRegistery] - Duplicate %q in registery")
			:format(moduleScript.Name))
	end

	local _module = require(moduleScript)
	local ok, err = self._checker(_module)
	if not ok then
		error(("[ModuleProvider._addToRegistery] - Bad module %q due to %q")
			:format(moduleScript.Name, tostring(err)))
	end

	self._process(_module)
	table.insert(self._modulesList, _module)

	self._registry[moduleScript.Name] = require(moduleScript)
end

return ModuleProvider