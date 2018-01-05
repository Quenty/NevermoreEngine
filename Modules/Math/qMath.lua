--- Holds utilty math functions not yet available on Roblox's math library.
-- @module qMath

local lib = {}

--- Maps a number from one range to another
-- @see http://stackoverflow.com/questions/929103/convert-a-number-range-to-another-range-maintaining-ratio
-- Make sure old range is not 0
function lib.MapNumber(value, min, max, newMin, newMax)
	return (((value - min) * (newMax - newMin)) / (max - min)) + newMin
end

--- Interpolates betweeen two numbers, given an percent
-- @tparam number low A number, the first one, should be less than high
-- @tparam number high A number, the second one, should be greater than high
-- @tparam number percent The percent, a number in the range [0, 1], that will be used to define
--              how interpolated it is between ValueOne And high
-- @treturn number The lerped number.
function lib.LerpNumber(low, high, percent)
	return low + ((high - low) * percent)
end

--- Round the given number to given precision
function lib.Round(number, base)
	base = base or 1
	return (math.floor((number/base)+0.5)*base)
end

function lib.RoundUp(number, base)
	return math.ceil(number/base) * base
end

function lib.RoundDown(number, base)
	return math.floor(number/base) * base
end

return lib