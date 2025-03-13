--!strict
--[=[
	Utility functions involving the [NumberRange] structure in Roblox
	@class NumberRangeUtils
]=]

local NumberRangeUtils = {}

--[=[
	Scales a NumberRange by the given amount.
	@param numberRange NumberRange
	@param scale number
	@return NumberRange
]=]
function NumberRangeUtils.scale(numberRange: NumberRange, scale: number): NumberRange
	assert(typeof(numberRange) == "NumberRange", "Bad numberRange")
	assert(type(scale) == "number", "Bad scale")

	return NumberRange.new(numberRange.Min * scale, numberRange.Max * scale)
end

--[=[
	Gets a NumberRange's value

	@param numberRange NumberRange
	@param t number
	@return number
]=]
function NumberRangeUtils.getValue(numberRange: NumberRange, t: number): number
	assert(typeof(numberRange) == "NumberRange", "Bad numberRange")
	assert(type(t) == "number", "Bad t")

	return numberRange.Min + (numberRange.Max - numberRange.Min) * t
end

return NumberRangeUtils
