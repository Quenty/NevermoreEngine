--[=[
	@class RoguePropertyDefinitionArrayHelper
]=]

local require = require(script.Parent.loader).load(script)

local RoguePropertyArrayUtils = require("RoguePropertyArrayUtils")

local RoguePropertyDefinitionArrayHelper = {}
RoguePropertyDefinitionArrayHelper.ClassName = "RoguePropertyDefinitionArrayHelper"
RoguePropertyDefinitionArrayHelper.__index = RoguePropertyDefinitionArrayHelper

function RoguePropertyDefinitionArrayHelper.new(propertyTableDefinition, defaultArrayData, requiredPropertyDefinition)
	local self = setmetatable({}, RoguePropertyDefinitionArrayHelper)

	self._propertyTableDefinition = assert(propertyTableDefinition, "No propertyTableDefinition")
	self._defaultArrayData = assert(defaultArrayData, "No defaultArrayData")
	self._requiredPropertyDefinition = assert(requiredPropertyDefinition, "No requiredPropertyDefinition")

	return self
end

function RoguePropertyDefinitionArrayHelper:IsArray(): boolean
	return self._defaultArrayData ~= nil
end

function RoguePropertyDefinitionArrayHelper:GetDefaultArrayData()
	return self._defaultArrayData
end

function RoguePropertyDefinitionArrayHelper:GetPropertyTableDefinition()
	return self._propertyTableDefinition
end

function RoguePropertyDefinitionArrayHelper:GetDefaultDefinitions()
	if self._defaultDefinitions then
		return self._defaultDefinitions
	end

	self._defaultDefinitions =
		RoguePropertyArrayUtils.createDefinitionsFromArrayData(self._defaultArrayData, self._propertyTableDefinition)
	return self._defaultDefinitions
end

function RoguePropertyDefinitionArrayHelper:GetRequiredPropertyDefinition()
	return self._requiredPropertyDefinition
end

function RoguePropertyDefinitionArrayHelper:CanAssign(arrayValue, strict): boolean
	if type(arrayValue) ~= "table" then
		return false, string.format("got %q, expected %q", self._valueType, typeof(arrayValue))
	end

	for key, value in arrayValue do
		if type(key) == "number" then
			local canAssign, message = self._requiredPropertyDefinition:CanAssign(value, strict)
			if not canAssign then
				return false,
					string.format(
						"Array at %s was %q, cannot assign due to %q",
						tostring(key),
						typeof(value),
						tostring(message)
					)
			end
		end
	end

	return true
end

function RoguePropertyDefinitionArrayHelper:CanAssignAsArrayMember(value, strict): boolean
	assert(type(strict) == "boolean", "Bad strict")

	return self._requiredPropertyDefinition:CanAssign(value, strict)
end

return RoguePropertyDefinitionArrayHelper