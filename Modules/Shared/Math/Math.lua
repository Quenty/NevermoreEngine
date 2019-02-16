--- Holds utilty math functions not available on Roblox's math library
-- @module Math

local Math = {}

--- Maps a number from one range to another
-- Make sure old range is not 0
function Math.MapNumber(value, min, max, newMin, newMax)
	return (((value - min) * (newMax - newMin)) / (max - min)) + newMin
end

--- Interpolates betweeen two numbers, given an percent
-- @tparam {number} low A number, the first one, should be less than high
-- @tparam {number} high A number, the second one, should be greater than high
-- @tparam {number} percent The percent, a number in the range [0, 1], that will be used to define
--              how interpolated it is between ValueOne And high
-- @treturn {number} The lerped number.
function Math.LerpNumber(low, high, percent)
	return low + ((high - low) * percent)
end

--- Solving for angle across from c
function Math.LawOfCosines(a, b, c)
	local l = (a*a + b*b - c*c) / (2 * a * b)
	local angle = math.acos(l)
	if angle ~= angle then
		return nil
	end
	return angle
end

--- Round the given number to given precision
-- @tparam {number} number
-- @tparam[opt=1] {number} precision
function Math.round(number, precision)
	precision = precision or 1
	return (math.floor((number/precision)+0.5)*precision)
end

function Math.roundUp(number, precision)
	return math.ceil(number/precision) * precision
end

function Math.roundDown(number, precision)
	return math.floor(number/precision) * precision
end

return Math