--- Holds utilty math functions not available on Roblox's math library
-- @module Math

local Math = {}

--- Maps a number from one range to another
function Math.map(num, min0, max0, min1, max1)
	if max0 == min0 then
		error("Range of zero")
	end

	return (((num - min0)*(max1 - min1)) / (max0 - min0)) + min1
end

--- Interpolates betweeen two numbers, given an percent
-- @tparam {number} num0 Number
-- @tparam {number} num1 Second number
-- @tparam {number} percent The percent, a number in the range that will be used to define
--              how interpolated it is between num0 and num1
-- @treturn {number} The interpolated
function Math.lerp(num0, num1, percent)
	return num0 + ((num1 - num0) * percent)
end

--- Solving for angle across from c
function Math.lawOfCosines(a, b, c)
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
	if precision then
		return math.floor((number/precision) + 0.5) * precision
	else
		return math.floor(number + 0.5)
	end
end

function Math.roundUp(number, precision)
	return math.ceil(number/precision) * precision
end

function Math.roundDown(number, precision)
	return math.floor(number/precision) * precision
end

return Math