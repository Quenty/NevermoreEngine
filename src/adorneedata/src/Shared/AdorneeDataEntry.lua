--[=[
	Declaration for the adornee data value

	@class AdorneeDataEntry
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = require("DuckTypeUtils")
local t = require("t")
local DefaultValueUtils = require("DefaultValueUtils")
local AttributeValue = require("AttributeValue")

local AdorneeDataEntry = {}
AdorneeDataEntry.ClassName = "AdorneeDataEntry"
AdorneeDataEntry.__index = AdorneeDataEntry

--[=[
	Creates a new adornee data entry

	@param interface string | (value: any) -> (boolean, string?)
	@param createValueObject (adornee: Instance) -> ValueObject<T>
	@param defaultValue T?
	@return AdorneeDataEntry<T>
]=]
function AdorneeDataEntry.new(interface, createValueObject, defaultValue)
	assert(type(interface) == "string" or type(interface) == "function", "Bad interface")
	assert(type(createValueObject) == "function", "Bad createValueObject")

	local self = setmetatable({}, AdorneeDataEntry)

	self._createValueObject = createValueObject

	if type(interface) == "string" then
		self._interface = t.typeof(interface)
	elseif type(interface) == "function" then
		self._interface = interface
	else
		error("Bad interface")
	end

	if defaultValue ~= nil then
		self._defaultValue = defaultValue
	elseif self._dataType == "Instance" then
		self._defaultValue = nil
	elseif type(interface) ~= "function" then
		self._defaultValue = DefaultValueUtils.getDefaultValueForType(interface)
	end

	return self
end

function AdorneeDataEntry.optionalAttribute(interface, name)
	assert(type(interface) == "string" or type(interface) == "function", "Bad interface")

	return AdorneeDataEntry.new(t.optional(interface), function(instance)
		return AttributeValue.new(instance, name, nil)
	end, nil)
end

--[=[
	Returns true if the implementation is an AdorneeDataEntry

	@param data any
	@return boolean
]=]
function AdorneeDataEntry.isAdorneeDataEntry(data: any): boolean
	return DuckTypeUtils.isImplementation(AdorneeDataEntry, data)
end

--[=[
	Creates a value object for the given adornee

	@param adornee Instance
	@return ValueObject<T>
]=]
function AdorneeDataEntry:Create(adornee: Instance)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return self._createValueObject(adornee)
end

--[=[
	Observes the current value for the adornee

	@param adornee Instance
	@return Observable<T>
]=]
function AdorneeDataEntry:Observe(adornee: Instance)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local valueObject = self:Create(adornee)
	return valueObject:Observe()
end

--[=[
	Gets the value for the adornee

	@param adornee Instance
	@return T
]=]
function AdorneeDataEntry:Get(adornee)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local valueObject = self:Create(adornee)

	return valueObject.Value
end

--[=[
	Sets the value for the adornee

	@param adornee Instance
	@param value T
]=]
function AdorneeDataEntry:Set(adornee, value)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(self._interface(value))

	local valueObject = self:Create(adornee)
	valueObject.Value = value
end

--[=[
	Gets the default value

	@return T?
]=]
function AdorneeDataEntry:GetDefaultValue()
	return self._defaultValue
end

--[=[
	Gets the estrict interface for the entry

	@return (value: any) -> (boolean, string)
]=]
function AdorneeDataEntry:GetStrictInterface()
	return self._interface
end

--[=[
	Returns true if the item is valid.

	@param value any
	@return (boolean, string)
]=]
function AdorneeDataEntry:IsValid(value)
	return self._interface(value)
end

return AdorneeDataEntry