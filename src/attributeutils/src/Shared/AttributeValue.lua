---
-- @classmod AttributeValue
-- @author Quenty

local AttributeValue = {}
AttributeValue.ClassName = "AttributeValue"
AttributeValue.__index = AttributeValue

function AttributeValue.new(object, attributeName, defaultValue)
	local self = {
		_object = object;
		_attributeName = attributeName;
		_defaultValue = defaultValue;
	}

	if defaultValue ~= nil and self._object:GetAttribute(self._attributeName) == nil then
		self._object:SetAttribute(rawget(self, "_attributeName"), defaultValue)
	end

	return setmetatable(self, AttributeValue)
end

function AttributeValue:__index(index)
	if index == "Value" then
		local result = self._object:GetAttribute(rawget(self, "_attributeName"))
		local default = rawget(self, "_defaultValue")
		if result == nil then
			return default
		else
			return result
		end
	elseif index == "Changed" then
		return self._object:GetAttributeChangedSignal(self._attributeName)
	elseif AttributeValue[index] then
		return AttributeValue[index]
	else
		error(("%q is not a member of AttributeValue"):format(tostring(index)))
	end
end

function AttributeValue:__newindex(index, value)
	if index == "Value" then
		self._object:SetAttribute(rawget(self, "_attributeName"), value)
	else
		error(("%q is not a member of AttributeValue"):format(tostring(index)))
	end
end

return AttributeValue