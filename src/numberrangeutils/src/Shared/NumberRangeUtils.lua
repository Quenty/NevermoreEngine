--[=[
	Utility functions involving the [NumberRange] structure in Roblox
	@class NumberRangeUtils
]=]

local NumberRangeUtils = {}

--[=[
	Scales a number range by the given amount.
	@param range NumberRange
	@param scale number
	@return NumberRange
]=]
function NumberRangeUtils.scale(range, scale)
	return NumberRange.new(range.Min*scale, range.Max*scale)
end

return NumberRangeUtils