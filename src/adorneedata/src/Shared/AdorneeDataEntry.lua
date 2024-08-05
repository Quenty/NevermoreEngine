--[=[
	Declaration for the adornee data value

	@class AdorneeDataEntry
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = require("DuckTypeUtils")
local t = require("t")
local DefaultValueUtils = require("DefaultValueUtils")

local AdorneeDataEntry = {}
AdorneeDataEntry.ClassName = "AdorneeDataEntry"
AdorneeDataEntry.__index = AdorneeDataEntry

--[=[
	Creates a new adornee data entry

	@param dataType string
	@param createValueObject (adornee: Instance) -> ValueObject<T>
	@return AdorneeDataEntry<T>
]=]
function AdorneeDataEntry.new(dataType, createValueObject)
	assert(type(dataType) == "string", "Bad dataType")
	assert(type(createValueObject) == "function", "Bad createValueObject")

	local self = setmetatable({}, AdorneeDataEntry)

	self._dataType = dataType
	self._createValueObject = createValueObject
	self._strictInterface = t.typeof(self._dataType)

	if self._dataType == "Instance" then
		self._defaultValue = nil
	else
		self._defaultValue = DefaultValueUtils.getDefaultValueForType(self._dataType)
	end

	return self
end

--[=[
	Returns true if the implementation is an AdorneeDataEntry

	@param data any
	@return boolean
]=]
function AdorneeDataEntry.isAdorneeDataEntry(data)
	return DuckTypeUtils.isImplementation(AdorneeDataEntry, data)
end

--[=[
	Creates a value object for the given adornee

	@param adornee Instance
	@return ValueObject<T>
]=]
function AdorneeDataEntry:Create(adornee)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return self._createValueObject(adornee)
end

--[=[
	Observes the current value for the adornee

	@param adornee Instance
	@return Observable<T>
]=]
function AdorneeDataEntry:Observe(adornee)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local valueObject = self:Create(adornee)
	return valueObject:Observe()
end

--[=[
	Gets the value for the adornee

	@param adornee Instance
	@return T
]=]
function AdorneeDataEntry:GetValue(adornee)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local valueObject = self:Create(adornee)

	return valueObject.Value
end

--[=[
	Sets the value for the adornee

	@param adornee Instance
	@param value T
]=]
function AdorneeDataEntry:SetValue(adornee, value)
	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(self._strictInterface(value))

	local valueObject = self:CreateValueObject(adornee)
	valueObject.Value = value
end

--[=[
	Gets the default value

	@return T
]=]
function AdorneeDataEntry:GetDefaultValue()
	return self._defaultValue
end

--[=[
	Gets the estrict interface for the entry

	@return (value: any) -> (boolean, string)
]=]
function AdorneeDataEntry:GetStrictInterface()
	return self._strictInterface
end

--[=[
	Returns true if the item is valid.

	@param value any
	@return (boolean, string)
]=]
function AdorneeDataEntry:IsValid(value)
	return self._strictInterface(value)
end

return AdorneeDataEntry