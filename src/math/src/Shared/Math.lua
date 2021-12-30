--[=[
	Holds utilty math functions not available on Roblox's math library.
	@class Math
]=]

local Math = {}

--[=[
	Maps a number from one range to another.

	:::note
	Note the mapped value can be outside of the initial range,
	which is very useful for linear interpolation.
	:::

	```lua
	print(Math.map(0.1, 0, 1, 1, 0)) --> 0.9
	```

	@param num number
	@param min0 number
	@param max0 number
	@param min1 number
	@param max1 number
	@return number
]=]
function Math.map(num, min0, max0, min1, max1)
	if max0 == min0 then
		error("Range of zero")
	end

	return (((num - min0)*(max1 - min1)) / (max0 - min0)) + min1
end

--[=[
	Interpolates betweeen two numbers, given an percent. The percent is
	a number in the range that will be used to define how interpolated
	it is between num0 and num1.

	```lua
	print(Math.lerp(-1000, 1000, 0.75)) --> 500
	```

	@param num0 number -- Number
	@param num1 number -- Second number
	@param percent number -- The percent
	@return number -- The interpolated
]=]
function Math.lerp(num0, num1, percent)
	return num0 + ((num1 - num0) * percent)
end

--[=[
	Solving for angle across from c

	@param a number
	@param b number
	@param c number
	@return number? -- Returns nil if this cannot be solved for
]=]
function Math.lawOfCosines(a, b, c)
	local l = (a*a + b*b - c*c) / (2 * a * b)
	local angle = math.acos(l)
	if angle ~= angle then
		return nil
	end
	return angle
end

--[=[
	Round the given number to given precision

	```lua
	print(Math.round(72.1, 5)) --> 75
	```

	@param number number
	@param precision number? -- Defaults to 1
	@return number
]=]
function Math.round(number, precision)
	if precision then
		return math.floor((number/precision) + 0.5) * precision
	else
		return math.floor(number + 0.5)
	end
end

--[=[
	Rounds up to the given precision

	@param number number
	@param precision number
	@return number
]=]
function Math.roundUp(number, precision)
	return math.ceil(number/precision) * precision
end

--[=[
	Rounds down to the given precision

	@param number number
	@param precision number
	@return number
]=]
function Math.roundDown(number, precision)
	return math.floor(number/precision) * precision
end

return Math