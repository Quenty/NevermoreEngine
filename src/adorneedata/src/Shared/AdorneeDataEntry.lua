--[=[
	@class AdorneeDataEntry
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = require("DuckTypeUtils")
local t = require("t")

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

	return self
end

function AdorneeDataEntry.isAdorneeDataEntry(data)
	return DuckTypeUtils.isImplementation(AdorneeDataEntry, data)
end

function AdorneeDataEntry:CreateValueObject(adornee)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return self._createValueObject(adornee)
end

function AdorneeDataEntry:GetStrictInterface()
	return self._strictInterface
end

return AdorneeDataEntry