--[=[
	@class AdorneeDataEntry
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = require("DuckTypeUtils")
local t = require("t")
local DefaultValueUtils = require("DefaultValueUtils")

local AdorneeDataEntry = {}
AdorneeDataEntry.ClassName = "AdorneeDataEntry"
AdorneeDataEntry.__index = AdorneeDataEntry

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

function AdorneeDataEntry.isAdorneeDataEntry(data)
	return DuckTypeUtils.isImplementation(AdorneeDataEntry, data)
end

function AdorneeDataEntry:CreateValueObject(adornee)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return self._createValueObject(adornee)
end

function AdorneeDataEntry:GetDefaultValue()
	return self._defaultValue
end

function AdorneeDataEntry:GetStrictInterface()
	return self._strictInterface
end

return AdorneeDataEntry