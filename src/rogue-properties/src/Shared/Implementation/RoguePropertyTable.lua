--[=[
	@class RoguePropertyTable
]=]

local require = require(script.Parent.loader).load(script)

local RogueProperty = require("RogueProperty")
local Rx = require("Rx")
local RoguePropertyArrayHelper = require("RoguePropertyArrayHelper")

local RoguePropertyTable = {} -- inherits from RogueProperty
RoguePropertyTable.ClassName = "RoguePropertyTable"
RoguePropertyTable.__index = RoguePropertyTable

function RoguePropertyTable.new(adornee: Instance, serviceBag, roguePropertyTableDefinition)
	local self = setmetatable(RogueProperty.new(adornee, serviceBag, roguePropertyTableDefinition), RoguePropertyTable)

	rawset(self, "_properties", {})

	local arrayDefinitionHelper = self:GetDefinition():GetDefinitionArrayHelper()
	if arrayDefinitionHelper then
		rawset(self, "_arrayHelper", RoguePropertyArrayHelper.new(serviceBag, arrayDefinitionHelper, self))
	end

	return self
end

function RoguePropertyTable:SetCanInitialize(canInitialize: boolean)
	assert(type(canInitialize) == "boolean", "Bad canInitialize")

	RogueProperty.SetCanInitialize(self, canInitialize)

	for _, property in self:GetRogueProperties() do
		property:SetCanInitialize(canInitialize)
	end

	local arrayHelper = rawget(self, "_arrayHelper")
	if arrayHelper then
		arrayHelper:SetCanInitialize(canInitialize)
	end
end

function RoguePropertyTable:ObserveContainerBrio()
	return self._definition:ObserveContainerBrio(self._adornee, self:CanInitialize())
end

function RoguePropertyTable:GetContainer(): Instance
	local cached = rawget(self, "_containerCache")
	if cached and cached:IsDescendantOf(self._adornee) then
		return cached
	end

	local container = self._definition:GetContainer(self._adornee, self:CanInitialize())
	rawset(self, "_containerCache", container)
	return container
end

function RoguePropertyTable:SetBaseValue(newBaseValue)
	assert(self._definition:CanAssign(newBaseValue, false)) -- This has a good error message

	local arrayData = {}

	for propertyName, value in newBaseValue do
		if type(propertyName) == "string" then
			local rogueProperty = self:GetRogueProperty(propertyName)
			if not rogueProperty then
				error(string.format("Bad property %q", tostring(propertyName)))
			end

			rogueProperty:SetBaseValue(value)
		else
			table.insert(arrayData, value)
		end
	end

	if next(arrayData) ~= nil then
		local arrayHelper = rawget(self, "_arrayHelper")
		if arrayHelper then
			arrayHelper:SetArrayBaseData(arrayData)
		else
			error("Had array data but we are not an array")
		end
	end
end

function RoguePropertyTable:SetValue(newValue)
	assert(self._definition:CanAssign(newValue, false)) -- This has a good error message

	local arrayData = {}

	for propertyName, value in newValue do
		if type(propertyName) == "string" then
			local rogueProperty = self:GetRogueProperty(propertyName)
			if not rogueProperty then
				error(string.format("Bad property %q", tostring(propertyName)))
			end

			rogueProperty:SetValue(value)
		else
			table.insert(arrayData, value)
		end
	end

	if next(arrayData) ~= nil then
		local arrayHelper = rawget(self, "_arrayHelper")
		if arrayHelper then
			arrayHelper:SetArrayData(arrayData)
		else
			error("Had array data but we are not an array")
		end
	end
end

function RoguePropertyTable:GetRogueProperties()
	local arrayHelper = rawget(self, "_arrayHelper")
	local properties = arrayHelper and arrayHelper:GetArrayRogueProperties() or {}

	for propertyName, rogueDefinition in pairs(self._definition:GetDefinitionMap()) do
		local rogueProperty = self:GetRogueProperty(rogueDefinition:GetName())
		if not rogueProperty then
			error(string.format("Bad property %q", tostring(rogueDefinition:GetName())))
		end

		properties[propertyName] = rogueProperty
	end

	return properties
end

function RoguePropertyTable:GetValue()
	local arrayHelper = rawget(self, "_arrayHelper")
	local values = arrayHelper and arrayHelper:GetArrayValues() or {}

	for key, rogueDefinition in pairs(self._definition:GetDefinitionMap()) do
		local property = self:GetRogueProperty(rogueDefinition:GetName())
		assert(property, "Failed to get rogue property")

		values[key] = property:GetValue()
	end

	return values
end

function RoguePropertyTable:GetBaseValue()
	local arrayHelper = rawget(self, "_arrayHelper")
	local values = arrayHelper and arrayHelper:GetArrayBaseValues() or {}

	for key, rogueDefinition in pairs(self._definition:GetDefinitionMap()) do
		local property = self:GetRogueProperty(rogueDefinition:GetName())
		assert(property, "Failed to get rogue property")

		values[key] = property:GetBaseValue()
	end

	return values
end

function RoguePropertyTable:Observe()
	local arrayHelper = rawget(self, "_arrayHelper")
	if arrayHelper then
		return arrayHelper:ObserveArrayValues()
	end

	return self:_observeDictionary()
end

function RoguePropertyTable:_observeDictionary()
	-- ok, this is definitely slow

	local toObserve = {}

	for propertyName, rogueDefinition in pairs(self._definition:GetDefinitionMap()) do
		local rogueProperty = self:GetRogueProperty(rogueDefinition:GetName())
		if not rogueProperty then
			error(string.format("Bad property %q", tostring(rogueDefinition:GetName())))
		end

		toObserve[propertyName] = rogueProperty:Observe()
	end

	if next(toObserve) == nil then
		return Rx.of({})
	end

	return Rx.combineLatest(toObserve)
end

function RoguePropertyTable:GetRogueProperty(name: string)
	assert(type(name) == "string", "Bad name")

	-- Caching these things doesn't do a whole lot, but saves on table allocation.
	if self._properties[name] then
		return self._properties[name]
	end

	local definition = self._definition:GetDefinition(name)
	if definition then
		local newProperty = definition:Get(self._serviceBag, self._adornee)
		newProperty:SetCanInitialize(self:CanInitialize())

		self._properties[name] = newProperty
		return newProperty
	else
		return nil
	end
end

function RoguePropertyTable:__newindex(index, value)
	if index == "Value" then
		self:SetValue(value)
	elseif index == "Changed" then
		error("Cannot set .Changed event")
	elseif RoguePropertyTable[index] then
		error(string.format("Cannot set %q", tostring(index)))
	elseif type(index) == "string" then
		local property = self:GetRogueProperty(index)
		if not property then
			error(string.format("Bad index %q", tostring(index)))
		end

		error(string.format("Use RoguePropertyTable.%s.Value to assign", index))
	else
		error(string.format("Bad index %q", tostring(index)))
	end
end

function RoguePropertyTable:__index(index)
	assert(type(index) == "string" or type(index) == "number", "Bad index")

	if RoguePropertyTable[index] then
		return RoguePropertyTable[index]
	elseif rawget(RogueProperty, index) ~= nil then
		return rawget(RogueProperty, index)
	elseif index == "Value" then
		return self:GetValue()
	elseif index == "Changed" then
		return self:GetChangedEvent()
	elseif type(index) == "string" then
		local property = self:GetRogueProperty(index)
		if not property then
			error(string.format("Bad index %q", tostring(index)))
		end
		return property
	elseif type(index) == "number" then
		local arrayHelper = rawget(self, "_arrayHelper")
		if arrayHelper then
			local result = arrayHelper:GetArrayRogueProperty(index)

			if result then
				return result
			else
				error(string.format("Bad index %q", tostring(index)))
			end
		else
			error(string.format("Bad index %q - We are not an array", tostring(index)))
		end
	else
		error(string.format("Bad index %q", tostring(index)))
	end
end

return RoguePropertyTable
