--[=[
	@class RoguePropertyArrayUtils
]=]

local require = require(script.Parent.loader).load(script)

local RoguePropertyArrayConstants = require("RoguePropertyArrayConstants")
local String = require("String")
local DefaultValueUtils = require("DefaultValueUtils")

local RoguePropertyArrayUtils = {}

function RoguePropertyArrayUtils.getNameFromIndex(index: number): string
	return RoguePropertyArrayConstants.ARRAY_ENTRY_PERFIX .. tostring(index)
end

function RoguePropertyArrayUtils.getIndexFromName(name: string): number?
	return tonumber(String.removePrefix(name, RoguePropertyArrayConstants.ARRAY_ENTRY_PERFIX))
end

function RoguePropertyArrayUtils.createRequiredPropertyDefinitionFromArray(arrayData, parentPropertyTableDefinition)
	local expectedType = typeof(arrayData[1])
	if expectedType == "table" then
		return RoguePropertyArrayUtils.createRequiredTableDefinition(arrayData, parentPropertyTableDefinition)
	elseif expectedType == "nil" then
		return nil, "Missing array data"
	end

	for index, item in arrayData do
		if typeof(item) ~= expectedType then
			expectedType = nil
			-- TODO: Maybe union?
			return nil, string.format("Expected type %q on %q, got %q", expectedType, tostring(index), typeof(item))
		end
	end

	return RoguePropertyArrayUtils.createRequiredPropertyDefinitionFromType(expectedType, parentPropertyTableDefinition)
end

function RoguePropertyArrayUtils.createRequiredTableDefinition(arrayData, parentPropertyTableDefinition)
	local RoguePropertyTableDefinition = (require :: any)("RoguePropertyTableDefinition")

	local entry = arrayData[1]
	if type(entry) ~= "table" then
		return nil, "Result was not a table"
	end

	-- Check shared state against this...
	local propertyDefinition = RoguePropertyTableDefinition.new()
	propertyDefinition:SetName("<ArrayIndex>")
	propertyDefinition:SetParentPropertyTableDefinition(parentPropertyTableDefinition)
	propertyDefinition:SetDefaultValue(DefaultValueUtils.toDefaultValue(entry))

	for _, item in arrayData do
		local canAssign, message = propertyDefinition:CanAssign(item, true)
		if not canAssign then
			return nil, string.format("Cannot assign due to %q", message)
		end
	end

	return propertyDefinition
end

function RoguePropertyArrayUtils.createRequiredPropertyDefinitionFromType(
	expectedType: string,
	parentPropertyTableDefinition
)
	local RoguePropertyDefinition = (require :: any)("RoguePropertyDefinition")

	local default = DefaultValueUtils.getDefaultValueForType(expectedType)
	if default == nil then
		return nil, "Default value is nil"
	end

	local propertyDefinition = RoguePropertyDefinition.new()
	propertyDefinition:SetName("<ArrayIndex>")
	propertyDefinition:SetParentPropertyTableDefinition(parentPropertyTableDefinition)
	propertyDefinition:SetDefaultValue(default)

	return propertyDefinition
end

function RoguePropertyArrayUtils.createDefinitionsFromContainer(container: Instance, parentPropertyTableDefinition)
	local RoguePropertyTableDefinition = (require :: any)("RoguePropertyTableDefinition")
	local RoguePropertyDefinition = (require :: any)("RoguePropertyDefinition")

	local value = {}

	for _, item in container:GetChildren() do
		local index = RoguePropertyArrayUtils.getIndexFromName(item.Name)
		if not index then
			continue
		end

		local definition
		if item:IsA("Folder") then
			definition = RoguePropertyTableDefinition.new(item.Name)
			definition:SetName(item.Name)
			definition:SetParentPropertyTableDefinition(parentPropertyTableDefinition)
			definition:SetDefaultValue(RoguePropertyArrayUtils.getDefaultValueMapFromContainer(item))
		elseif item:IsA("ValueBase") then
			definition = RoguePropertyDefinition.new()
			definition:SetName(item.Name)
			definition:SetParentPropertyTableDefinition(parentPropertyTableDefinition)
			definition:SetDefaultValue(item.Value)
		end

		value[index] = definition
	end

	return value
end

function RoguePropertyArrayUtils.getDefaultValueMapFromContainer(container: Instance)
	local value = {}

	for _, item in container:GetChildren() do
		local index = RoguePropertyArrayUtils.getIndexFromName(item.Name)
		if index then
			if item:IsA("Folder") then
				value[index] = RoguePropertyArrayUtils.getDefaultValueMapFromContainer(item)
			elseif item:IsA("ValueBase") then
				value[index] = item.Value
			end
		else
			if item:IsA("Folder") then
				value[item.Name] = RoguePropertyArrayUtils.getDefaultValueMapFromContainer(item)
			else
				value[item.Name] = item.Value
			end
		end
	end

	return value
end

function RoguePropertyArrayUtils.createDefinitionsFromArrayData(arrayData, propertyTableDefinition)
	local RoguePropertyTableDefinition = (require :: any)("RoguePropertyTableDefinition")
	local RoguePropertyDefinition = (require :: any)("RoguePropertyDefinition")

	local definitions = {}
	for index, defaultValue in arrayData do
		local name = RoguePropertyArrayUtils.getNameFromIndex(index)

		if type(defaultValue) == "table" then
			local tableDefinition = RoguePropertyTableDefinition.new()
			tableDefinition:SetName(name)
			tableDefinition:SetParentPropertyTableDefinition(propertyTableDefinition)
			tableDefinition:SetDefaultValue(defaultValue)
			definitions[index] = tableDefinition
		else
			local definition = RoguePropertyDefinition.new()
			definition:SetName(name)
			definition:SetParentPropertyTableDefinition(propertyTableDefinition)
			definition:SetDefaultValue(defaultValue)
			definitions[index] = definition
		end
	end

	return definitions
end

return RoguePropertyArrayUtils