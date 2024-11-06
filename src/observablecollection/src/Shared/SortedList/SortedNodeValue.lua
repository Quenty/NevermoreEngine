--[=[
	Simplifies comparison logic

	@class SortedNodeValue
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = require("DuckTypeUtils")

local SortedNodeValue = {}
SortedNodeValue.ClassName = "SortedNodeValue"
SortedNodeValue.__index = SortedNodeValue

function SortedNodeValue.new(value, compare)
	local self = setmetatable({}, SortedNodeValue)

	self._value = value
	self._compare = compare

	return self
end

function SortedNodeValue:GetValue()
	return self._value
end

function SortedNodeValue.isSortedNodeValue(value)
	return DuckTypeUtils.isImplementation(SortedNodeValue, value)
end

function SortedNodeValue:__eq(other)
	assert(SortedNodeValue.isSortedNodeValue(other), "Bad other")
	assert(other._compare == self._compare, "Bad compare")

	return self._compare(self._value, other._value) == 0
end

function SortedNodeValue:__lt(other)
	assert(SortedNodeValue.isSortedNodeValue(other), "Bad other")
	assert(other._compare == self._compare, "Bad compare")

	return self._compare(self._value, other._value) < 0
end

function SortedNodeValue:__gt(other)
	assert(SortedNodeValue.isSortedNodeValue(other), "Bad other")
	assert(other._compare == self._compare, "Bad compare")

	return self._compare(self._value, other._value) > 0
end

return SortedNodeValue