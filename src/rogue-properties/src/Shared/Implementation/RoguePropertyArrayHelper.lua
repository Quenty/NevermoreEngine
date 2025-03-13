--[=[
	@class RoguePropertyArrayHelper
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local RoguePropertyArrayUtils = require("RoguePropertyArrayUtils")
local Rx = require("Rx")

local RoguePropertyArrayHelper = setmetatable({}, BaseObject)
RoguePropertyArrayHelper.ClassName = "RoguePropertyArrayHelper"
RoguePropertyArrayHelper.__index = RoguePropertyArrayHelper

function RoguePropertyArrayHelper.new(serviceBag, arrayDefinitionHelper, roguePropertyTable)
	local self = setmetatable(BaseObject.new(), RoguePropertyArrayHelper)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._roguePropertyTable = assert(roguePropertyTable, "No roguePropertyTable")
	self._arrayDefinitionHelper = assert(arrayDefinitionHelper, "No arrayDefinitionHelper")

	return self
end

function RoguePropertyArrayHelper:SetCanInitialize(canInitialize: boolean)
	if canInitialize then
		self:GetArrayRogueProperties()
	end
end

function RoguePropertyArrayHelper:GetArrayRogueProperty(index: number)
	assert(type(index) == "number", "Bad index")

	-- TODO: Maybe return something general for that index
	-- TODO: This is slow....
	local rogueProperties = self:GetArrayRogueProperties()

	return rogueProperties[index]
end

function RoguePropertyArrayHelper:GetArrayRogueProperties()
	-- Dynamic construction of the properties based upon when exists
	local container = self._roguePropertyTable:GetContainer()

	-- Force initialization
	if self._roguePropertyTable:CanInitialize() then
		if not (container and container:GetAttribute("HasInitializedArrayComponent")) then
			container:SetAttribute("HasInitializedArrayComponent", true)
			local properties = self:_getDefaultRogueProperties()
			for _, rogueProperty in properties do
				-- Force initialization once and only once...
				rogueProperty:SetCanInitialize(true)
				rogueProperty:SetCanInitialize(false)
			end
		end
	end

	if not container then
		return self:_getDefaultRogueProperties()
	end

	local adornee = self._roguePropertyTable:GetAdornee()


	local definitions = RoguePropertyArrayUtils.createDefinitionsFromContainer(container, self._arrayDefinitionHelper:GetPropertyTableDefinition())
	local rogueProperties = {}

	for index, definition in definitions do
		local property = definition:Get(self._serviceBag, adornee)
		property:SetCanInitialize(false) -- Explicitly not going to reinitialize
		rogueProperties[index] = property
	end

	return rogueProperties
end

function RoguePropertyArrayHelper:_getDefaultRogueProperties()
	if self._defaultRogueProperties then
		return self._defaultRogueProperties
	end

	local defaultRogueProperties = {}
	local adornee = self._roguePropertyTable:GetAdornee()
	for _, definition in self._arrayDefinitionHelper:GetDefaultDefinitions() do
		local property = definition:Get(self._serviceBag, adornee)
		table.insert(defaultRogueProperties, property)
	end

	self._defaultRogueProperties = defaultRogueProperties
	return self._defaultRogueProperties
end

function RoguePropertyArrayHelper:SetArrayBaseData(arrayData)
	assert(self._arrayDefinitionHelper:CanAssign(arrayData, false)) -- This has good error messages

	local container = self._roguePropertyTable:GetContainer()
	if not container then
		warn("[RoguePropertyArrayHelper.SetArrayBaseData] - Failed to get container")
		return
	end

	-- Add all
	local available = self:GetArrayRogueProperties()
	local parentPropertyTableDefinition = self._arrayDefinitionHelper:GetPropertyTableDefinition()
	local adornee = self._roguePropertyTable:GetAdornee()
	local definitions = RoguePropertyArrayUtils.createDefinitionsFromArrayData(arrayData, parentPropertyTableDefinition)

	for index, definition in definitions do
		if available[index] and available[index]:GetDefinition():GetValueType() == definition:GetValueType() then
			available[index]:SetBaseValue(definition:GetDefaultValue())
		else
			-- Cleanup this old one and setup a new one
			if available[index] then
				available[index]:GetBaseValueObject():Destroy()
			end

			local property = definition:Get(self._serviceBag, adornee)

			if self._roguePropertyTable:CanInitialize() then
				property:SetCanInitialize(true) -- Initialize once
				property:SetCanInitialize(false)
			end
		end
	end

	self:_removeUnspecified(container, definitions)
end

function RoguePropertyArrayHelper:SetArrayData(arrayData)
	assert(self._arrayDefinitionHelper:CanAssign(arrayData, false)) -- This has good error messages

	local container = self._roguePropertyTable:GetContainer()
	if not container then
		warn("[RoguePropertyArrayHelper.SetArrayData] - Failed to get container")
		return
	end

	local available = self:GetArrayRogueProperties()
	local parentPropertyTableDefinition = self._arrayDefinitionHelper:GetPropertyTableDefinition()
	local adornee = self._roguePropertyTable:GetAdornee()
	local definitions = RoguePropertyArrayUtils.createDefinitionsFromArrayData(arrayData, parentPropertyTableDefinition)

	for index, definition in definitions do
		if available[index] and available[index]:GetDefinition():GetValueType() == definition:GetValueType() then
			available[index]:SetValue(definition:GetDefaultValue())
		else
			-- Cleanup this old one and setup a new one
			if available[index] then
				available[index]:GetBaseValueObject():Destroy()
			end

			local property = definition:Get(self._serviceBag, adornee)
			property:SetCanInitialize(true) -- Initialize once
			property:SetCanInitialize(false)
		end
	end

	self:_removeUnspecified(container, definitions)
end

function RoguePropertyArrayHelper:_removeUnspecified(container, definitions)
	for _, item in container:GetChildren() do
		local index = RoguePropertyArrayUtils.getIndexFromName(item.Name)
		if index then
			if not definitions[index] then
				item:Destroy()
			end
		end
	end
end

function RoguePropertyArrayHelper:GetArrayBaseValues()
	local result = {}
	for index, rogueProperty in pairs(self:GetArrayRogueProperties()) do
		result[index] = rogueProperty:GetBaseValue()
	end
	return result
end

function RoguePropertyArrayHelper:GetArrayValues()
	local result = {}
	for index, rogueProperty in pairs(self:GetArrayRogueProperties()) do
		result[index] = rogueProperty:GetValue()
	end
	return result
end

function RoguePropertyArrayHelper:ObserveArrayValues()
	warn("[RoguePropertyArrayHelper] - Observing arrays is only partially supported")

	-- TODO: Allow for observing
	local observables = {}

	for _, rogueProperty in self:GetArrayRogueProperties() do
		table.insert(observables, rogueProperty:Observe())
	end

	return Rx.combineLatest(observables)
end

return RoguePropertyArrayHelper