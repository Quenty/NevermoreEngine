--!strict
--[=[
	Simplifies comparison logic

	@class SortedNodeValue
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = require("DuckTypeUtils")

local SortedNodeValue = {}
SortedNodeValue.ClassName = "SortedNodeValue"
SortedNodeValue.__index = SortedNodeValue

export type CompareFunction<T> = (T, T) -> number

export type SortedNodeValue<T> = typeof(setmetatable(
	{} :: {
		_value: T,
		_compare: CompareFunction<T>,
	},
	{} :: typeof({ __index = SortedNodeValue })
))

function SortedNodeValue.new<T>(value: T, compare: CompareFunction<T>): SortedNodeValue<T>
	local self = setmetatable({}, SortedNodeValue)

	self._value = value
	self._compare = compare

	return self
end

function SortedNodeValue.GetValue<T>(self: SortedNodeValue<T>): T
	return self._value
end

function SortedNodeValue.isSortedNodeValue(value: any): boolean
	return DuckTypeUtils.isImplementation(SortedNodeValue, value)
end

function SortedNodeValue.__eq<T>(self: SortedNodeValue<T>, other: SortedNodeValue<T>): boolean
	assert(SortedNodeValue.isSortedNodeValue(other), "Bad other")
	assert(other._compare == self._compare, "Bad compare")

	return self._compare(self._value, other._value) == 0
end

function SortedNodeValue.__lt<T>(self: SortedNodeValue<T>, other: SortedNodeValue<T>): boolean
	assert(SortedNodeValue.isSortedNodeValue(other), "Bad other")
	assert(other._compare == self._compare, "Bad compare")

	return self._compare(self._value, other._value) < 0
end

function SortedNodeValue.__gt<T>(self: SortedNodeValue<T>, other: SortedNodeValue<T>): boolean
	assert(SortedNodeValue.isSortedNodeValue(other), "Bad other")
	assert(other._compare == self._compare, "Bad compare")

	return self._compare(self._value, other._value) > 0
end

return SortedNodeValue