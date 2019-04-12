--- Base of a template retrieval system
-- @classmod TemplateProvider

local TemplateProvider = {}
TemplateProvider.ClassName = "TemplateProvider"
TemplateProvider.__index = TemplateProvider

function TemplateProvider.new(getParentAsync)
	local self = setmetatable({}, TemplateProvider)

	self._getParentAsync = getParentAsync or error("No getParentAsync")

	return self
end

function TemplateProvider:Get(templateName)
	assert(type(templateName) == "string", "templateName must be a string")

	return self._getParentAsync():WaitForChild(templateName)
end

function TemplateProvider:Clone(templateName)
	local item = self:Get(templateName):Clone()
	if templateName:sub(-#("Template")) == "Template" then
		item.Name = templateName:sub(1, -#("Template") - 1)
	end
	return item
end

return TemplateProvider