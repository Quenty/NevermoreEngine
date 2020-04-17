--- Base of a template retrieval system
-- @classmod TemplateProvider

local TemplateProvider = {}
TemplateProvider.ClassName = "TemplateProvider"
TemplateProvider.__index = TemplateProvider

-- getParentFunc may return a promise too! Executes async.
function TemplateProvider.new(parent)
	local self = setmetatable({}, TemplateProvider)

	assert(typeof(parent) == "Instance")

	self._parent = parent or error("No parent")

	return self
end

function TemplateProvider:Init()
	self._registry = {}
	self:_processFolder(self._parent)
end

function TemplateProvider:IsAvailable(templateName)
	return self._registry[templateName] ~= nil
end

function TemplateProvider:Get(templateName)
	assert(type(templateName) == "string", "templateName must be a string")

	return self._registry[templateName]
end

function TemplateProvider:Clone(templateName)
	local template = self._registry[templateName]
	if not template then
		error(("[TemplateProvider.Clone] - Cannot provide %q"):format(tostring(templateName)))
		return nil
	end

	local newItem = template:Clone()
	if templateName:sub(-#("Template")) == "Template" then
		newItem.Name = templateName:sub(1, -#("Template") - 1)
	end
	return newItem
end

function TemplateProvider:_processFolder(folder)
	for _, instance in pairs(folder:GetChildren()) do
		if instance:IsA("Folder") then
			self:_processFolder(instance)
		else
			self:_addToRegistery(instance)
		end
	end
end

function TemplateProvider:_addToRegistery(instance)
	if self._registry[instance.Name] then
		error(("[TemplateProvider._addToRegistery] - Duplicate %q in registery")
			:format(instance.Name))
	end

	self._registry[instance.Name] = instance
end

return TemplateProvider