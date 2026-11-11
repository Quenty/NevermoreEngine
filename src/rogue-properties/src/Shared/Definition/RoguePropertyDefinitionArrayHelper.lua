--!strict
--[=[
	@class RoguePropertyDefinitionArrayHelper
]=]

local require = require(script.Parent.loader).load(script)

local RoguePropertyArrayUtils = require("RoguePropertyArrayUtils")

local RoguePropertyDefinitionArrayHelper = {}
RoguePropertyDefinitionArrayHelper.ClassName = "RoguePropertyDefinitionArrayHelper"
RoguePropertyDefinitionArrayHelper.__index = RoguePropertyDefinitionArrayHelper

export type RoguePropertyDefinitionArrayHelper = typeof(setmetatable(
	{} :: {
		_propertyTableDefinition: any,
		_defaultArrayData: { any },
		_requiredPropertyDefinition: any,
		_defaultDefinitions: { [number]: any }?,
		_valueType: string?,
	},
	{} :: typeof({ __index = RoguePropertyDefinitionArrayHelper })
))

function RoguePropertyDefinitionArrayHelper.new(
	propertyTableDefinition: any,
	defaultArrayData: { any },
	requiredPropertyDefinition: any
): RoguePropertyDefinitionArrayHelper
	local self: RoguePropertyDefinitionArrayHelper = setmetatable({} :: any, RoguePropertyDefinitionArrayHelper)

	self._propertyTableDefinition = assert(propertyTableDefinition, "No propertyTableDefinition")
	self._defaultArrayData = assert(defaultArrayData, "No defaultArrayData")
	self._requiredPropertyDefinition = assert(requiredPropertyDefinition, "No requiredPropertyDefinition")

	return self
end

function RoguePropertyDefinitionArrayHelper.IsArray(self: RoguePropertyDefinitionArrayHelper): boolean
	return self._defaultArrayData ~= nil
end

function RoguePropertyDefinitionArrayHelper.GetDefaultArrayData(self: RoguePropertyDefinitionArrayHelper): { any }
	return self._defaultArrayData
end

function RoguePropertyDefinitionArrayHelper.GetPropertyTableDefinition(self: RoguePropertyDefinitionArrayHelper): any
	return self._propertyTableDefinition
end

function RoguePropertyDefinitionArrayHelper.GetDefaultDefinitions(
	self: RoguePropertyDefinitionArrayHelper
): { [number]: any }
	if self._defaultDefinitions then
		return self._defaultDefinitions
	end

	local defaultDefinitions =
		RoguePropertyArrayUtils.createDefinitionsFromArrayData(self._defaultArrayData, self._propertyTableDefinition)
	self._defaultDefinitions = defaultDefinitions
	return defaultDefinitions
end

function RoguePropertyDefinitionArrayHelper.GetRequiredPropertyDefinition(self: RoguePropertyDefinitionArrayHelper): any
	return self._requiredPropertyDefinition
end

function RoguePropertyDefinitionArrayHelper.CanAssign(
	self: RoguePropertyDefinitionArrayHelper,
	arrayValue: any,
	strict: boolean?
): (boolean, string?)
	if type(arrayValue) ~= "table" then
		return false, string.format("got %q, expected %q", tostring(self._valueType), typeof(arrayValue))
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

function RoguePropertyDefinitionArrayHelper.CanAssignAsArrayMember(
	self: RoguePropertyDefinitionArrayHelper,
	value: any,
	strict: boolean
): (boolean, string?)
	assert(type(strict) == "boolean", "Bad strict")

	return self._requiredPropertyDefinition:CanAssign(value, strict)
end

return RoguePropertyDefinitionArrayHelper
