--!strict
--[=[
	@class RoguePropertyTable
]=]

local require = require(script.Parent.loader).load(script)

local Observable = require("Observable")
local RogueProperty = require("RogueProperty")
local RoguePropertyArrayHelper = require("RoguePropertyArrayHelper")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local ServiceBag = require("ServiceBag")

local RoguePropertyTable = {} -- inherits from RogueProperty
RoguePropertyTable.ClassName = "RoguePropertyTable"
RoguePropertyTable.__index = RoguePropertyTable

-- Built on a RogueProperty (shares its fields/methods via the intersection). Holds a
-- table of child properties, so it is RogueProperty<{ [any]: any }>. The dynamic
-- `.Value`/`.Changed`/child-property access goes through the function `__index` below.
export type RoguePropertyTable =
	typeof(setmetatable(
		{} :: {
			_properties: { [string]: any },
			_arrayHelper: any,
		},
		{} :: typeof({ __index = RoguePropertyTable })
	))
	& RogueProperty.RogueProperty<{ [any]: any }>

function RoguePropertyTable.new(
	adornee: Instance,
	serviceBag: ServiceBag.ServiceBag,
	roguePropertyTableDefinition: any
): RoguePropertyTable
	local self: RoguePropertyTable =
		setmetatable(RogueProperty.new(adornee, serviceBag, roguePropertyTableDefinition) :: any, RoguePropertyTable)

	rawset(self :: any, "_properties", {})

	local arrayDefinitionHelper = self:GetDefinition():GetDefinitionArrayHelper()
	if arrayDefinitionHelper then
		rawset(self :: any, "_arrayHelper", RoguePropertyArrayHelper.new(serviceBag, arrayDefinitionHelper, self))
	end

	return self
end

function RoguePropertyTable.SetCanInitialize(self: RoguePropertyTable, canInitialize: boolean)
	assert(type(canInitialize) == "boolean", "Bad canInitialize")

	if self:CanInitialize() ~= canInitialize then
		RogueProperty.SetCanInitialize(self :: any, canInitialize)

		for _, property in self:GetRogueProperties() do
			property:SetCanInitialize(canInitialize)
		end

		local arrayHelper = rawget(self :: any, "_arrayHelper")
		if arrayHelper then
			arrayHelper:SetCanInitialize(canInitialize)
		end
	end
end

function RoguePropertyTable.ObserveContainerBrio(self: RoguePropertyTable): any
	local cache = rawget(self :: any, "_observeContainerCache")
	if cache then
		return cache
	end

	local parentDefinition = self._definition:GetParentPropertyDefinition()
	if parentDefinition then
		local parentTable = parentDefinition:Get(self._serviceBag, self._adornee)

		if self:CanInitialize() then
			parentTable:GetContainer()
		end

		cache = (parentTable:ObserveContainerBrio() :: any):Pipe({
			RxBrioUtils.switchMapBrio(function(parent)
				return RxInstanceUtils.observeLastNamedChildBrio(parent, "Folder", self._definition:GetName())
			end),
			Rx.cache(),
		})
	else
		cache = (RxInstanceUtils.observeLastNamedChildBrio(self._adornee, "Folder", self._definition:GetName()) :: any):Pipe({
			Rx.cache(),
		})
	end

	cache = cache
	rawset(self :: any, "_observeContainerCache", cache)
	return cache
end

function RoguePropertyTable.GetContainer(self: RoguePropertyTable): Instance?
	local cached = rawget(self :: any, "_containerCache")
	if cached then
		if cached:IsDescendantOf(self._adornee) then
			return cached
		else
			rawset(self :: any, "_containerCache", nil)
		end
	end

	local parent
	local parentDefinition = self._definition:GetParentPropertyDefinition()
	if parentDefinition then
		local parentTable = parentDefinition:Get(self._serviceBag, self._adornee)
		parent = parentTable:GetContainer()
	else
		parent = self._adornee
	end

	if not parent then
		return nil
	end

	local container
	if self:CanInitialize() then
		container = self._definition:GetOrCreateInstance(parent)
	else
		container = self._definition:FindInstance(parent)
	end

	rawset(self :: any, "_containerCache", container)
	return container
end

function RoguePropertyTable.SetBaseValue(self: RoguePropertyTable, newBaseValue: any)
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
		local arrayHelper = rawget(self :: any, "_arrayHelper")
		if arrayHelper then
			arrayHelper:SetArrayBaseData(arrayData)
		else
			error("Had array data but we are not an array")
		end
	end
end

function RoguePropertyTable.SetValue(self: RoguePropertyTable, newValue: any)
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
		local arrayHelper = rawget(self :: any, "_arrayHelper")
		if arrayHelper then
			arrayHelper:SetArrayData(arrayData)
		else
			error("Had array data but we are not an array")
		end
	end
end

function RoguePropertyTable.GetRogueProperties(self: RoguePropertyTable): { [any]: any }
	local arrayHelper = rawget(self :: any, "_arrayHelper")
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

function RoguePropertyTable.GetValue(self: RoguePropertyTable): { [any]: any }
	local arrayHelper = rawget(self :: any, "_arrayHelper")
	local values = arrayHelper and arrayHelper:GetArrayValues() or {}

	for key, rogueDefinition in pairs(self._definition:GetDefinitionMap()) do
		local property = self:GetRogueProperty(rogueDefinition:GetName())
		assert(property, "Failed to get rogue property")

		values[key] = property:GetValue()
	end

	return values
end

function RoguePropertyTable.GetBaseValue(self: RoguePropertyTable): { [any]: any }
	local arrayHelper = rawget(self :: any, "_arrayHelper")
	local values = arrayHelper and arrayHelper:GetArrayBaseValues() or {}

	for key, rogueDefinition in pairs(self._definition:GetDefinitionMap()) do
		local property = self:GetRogueProperty(rogueDefinition:GetName())
		assert(property, "Failed to get rogue property")

		values[key] = property:GetBaseValue()
	end

	return values
end

function RoguePropertyTable.Observe(self: RoguePropertyTable): Observable.Observable<any>
	local arrayHelper = rawget(self :: any, "_arrayHelper")
	if arrayHelper then
		return arrayHelper:ObserveArrayValues()
	end

	return self:_observeDictionary()
end

function RoguePropertyTable._observeDictionary(self: RoguePropertyTable): any
	-- ok, this is definitely slow
	local cache = rawget(self :: any, "_observeDictionaryCache")
	if cache then
		return cache
	end

	local toObserve = {}

	for propertyName, rogueDefinition in pairs(self._definition:GetDefinitionMap()) do
		local rogueProperty = self:GetRogueProperty(rogueDefinition:GetName())
		if not rogueProperty then
			error(string.format("Bad property %q", tostring(rogueDefinition:GetName())))
		end

		toObserve[propertyName] = rogueProperty:Observe()
	end

	if next(toObserve) == nil then
		cache = Rx.of({})
	else
		cache = (Rx.combineLatest(toObserve) :: any):Pipe({
			Rx.cache(),
		})
	end

	rawset(self :: any, "_observeDictionaryCache", cache)

	return cache
end

function RoguePropertyTable.GetRogueProperty(self: RoguePropertyTable, name: string): any
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

local rawRoguePropertyTable = RoguePropertyTable :: any

rawRoguePropertyTable.__newindex = function(self: RoguePropertyTable, index: any, value: any)
	if index == "Value" then
		self:SetValue(value)
	elseif index == "Changed" then
		error("Cannot set .Changed event")
	elseif rawRoguePropertyTable[index] then
		error(string.format("Cannot set %q on %s", tostring(index), self._definition:GetFullName()))
	elseif type(index) == "string" then
		local property = self:GetRogueProperty(index)
		if not property then
			error(string.format("Bad index %q on %s", tostring(index), self._definition:GetFullName()))
		end

		error(string.format("Use RoguePropertyTable.%s.Value to assign", index))
	else
		error(string.format("Bad index %q on %s", tostring(index), self._definition:GetFullName()))
	end
end

rawRoguePropertyTable.__index = function(self: RoguePropertyTable, index: any): any
	assert(type(index) == "string" or type(index) == "number", "Bad index")

	if rawRoguePropertyTable[index] then
		return rawRoguePropertyTable[index]
	elseif rawget(RogueProperty :: any, index) ~= nil then
		return rawget(RogueProperty :: any, index)
	elseif index == "Value" then
		return self:GetValue()
	elseif index == "Changed" then
		return self:GetChangedEvent()
	elseif type(index) == "string" then
		local property = self:GetRogueProperty(index)
		if not property then
			error(string.format("Bad index %q on %s", tostring(index), self._definition:GetFullName()))
		end
		return property
	elseif type(index) == "number" then
		local arrayHelper = rawget(self :: any, "_arrayHelper")
		if arrayHelper then
			local result = arrayHelper:GetArrayRogueProperty(index)

			if result then
				return result
			else
				error(string.format("Bad index %q on %s", tostring(index), self._definition:GetFullName()))
			end
		else
			error(string.format("Bad index %q - We are not an array", tostring(index)))
		end
	else
		error(string.format("Bad index %q on %s", tostring(index), self._definition:GetFullName()))
	end
end

return RoguePropertyTable
