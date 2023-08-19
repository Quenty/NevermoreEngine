--[=[
	@class RoguePropertyTable
]=]

local require = require(script.Parent.loader).load(script)

local RogueProperty = require("RogueProperty")
local Rx = require("Rx")

local RoguePropertyTable = {} -- inherits from RogueProperty
RoguePropertyTable.ClassName = "RoguePropertyTable"
RoguePropertyTable.__index = RoguePropertyTable

function RoguePropertyTable.new(adornee, serviceBag, roguePropertyTableDefinition)
	local self = setmetatable(RogueProperty.new(adornee, serviceBag, roguePropertyTableDefinition), RoguePropertyTable)

	rawset(self, "_properties", {})

	if self:CanInitialize() then
		self:_setup()
	end

	return self
end

function RoguePropertyTable:SetCanInitialize(canInitialize)
	assert(type(canInitialize) == "boolean", "Bad canInitialize")

	RogueProperty.SetCanInitialize(self, canInitialize)

	for _, property in pairs(self._properties) do
		property:SetCanInitialize(canInitialize)
	end
end

function RoguePropertyTable:ObserveContainerBrio()
	return self._definition:ObserveContainerBrio(self._adornee, self:CanInitialize())
end

function RoguePropertyTable:GetContainer()
	return self._definition:GetContainer(self._adornee, self:CanInitialize())
end

function RoguePropertyTable:SetBaseValue(newBaseValue)
	assert(type(newBaseValue) == "table", "Bad newBaseValue")

	for propertyName, value in pairs(newBaseValue) do
		local rogueProperty = self:GetRogueProperty(propertyName)
		if not rogueProperty then
			error(("Bad property %q"):format(tostring(propertyName)))
		end

		rogueProperty:SetBaseValue(value)
	end
end

function RoguePropertyTable:SetValue(newBaseValue)
	assert(type(newBaseValue) == "table", "Bad newBaseValue")

	for propertyName, value in pairs(newBaseValue) do
		local rogueProperty = self:GetRogueProperty(propertyName)
		if not rogueProperty then
			error(("Bad property %q"):format(tostring(propertyName)))
		end

		rogueProperty:SetValue(value)
	end
end

function RoguePropertyTable:GetValue()
	local values = {}
	for key, rogueDefinition in pairs(self._definition:GetDefinitionMap()) do
		local property = self:GetRogueProperty(rogueDefinition:GetName())
		assert(property, "Failed to get rogue property")

		values[key] = property:GetValue()
	end

	return values
end

function RoguePropertyTable:GetBaseValue()
	local values = {}

	for key, rogueDefinition in pairs(self._definition:GetDefinitionMap()) do
		local property = self:GetRogueProperty(rogueDefinition:GetName())
		assert(property, "Failed to get rogue property")

		values[key] = property:GetBaseValue()
	end

	return values
end

function RoguePropertyTable:Observe()
	-- ok, this is definitely slow
	local toObserve = {}

	for propertyName, rogueDefinition in pairs(self._definition:GetDefinitionMap()) do
		local rogueProperty = self:GetRogueProperty(rogueDefinition:GetName())
		if not rogueProperty then
			error(("Bad property %q"):format(tostring(rogueDefinition:GetName())))
		end

		toObserve[propertyName] = rogueProperty:Observe():Pipe({
			Rx.distinct();
		})
	end

	return Rx.combineLatest(toObserve):Pipe({
		Rx.throttleDefer();
	})
end

function RoguePropertyTable:_setup()
	for definitionName, _ in pairs(self._definition:GetDefinitionMap()) do
		self:GetRogueProperty(definitionName)
	end
end

function RoguePropertyTable:GetRogueProperty(name)
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
	else
		error(string.format("Bad index %q", tostring(index)))
	end
end

function RoguePropertyTable:__index(index)
	assert(type(index) == "string", "Bad index")

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
			error(("Bad index %q"):format(tostring(index)))
		end
		return property
	else
		error(("Bad index %q"):format(tostring(index)))
	end
end

return RoguePropertyTable