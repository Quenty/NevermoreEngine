--!strict
--[=[
	Make interpolation curves like CSS

	* A good place to generate and test these out: http://cubic-bezier.com/
	* Based upon https://gist.github.com/gre/1926947#file-keyspline-js

	```lua
	local ease = BezierUtils.createBezierFactory(0.25, 0.1, 0.25, 1)
	for i = 0, 1.05, 0.05 do
		print(i, ":", ease(i))
	end
	```

	@class BezierUtils
]=]

local BezierUtils = {}

--[=[
	Creates a new bezier factory which can smoothly translate between 0 to 1.

	@param p1x number
	@param p1y number
	@param p2x number
	@param p2y number
	@return (aX: number) -> number
]=]
function BezierUtils.createBezierFactory(p1x: number, p1y: number, p2x: number, p2y: number): (number) -> number
	assert(p1x, "[BezierUtils.createBezierFactory] - Need p1x to construct a Bezier Factory")
	assert(p1y, "[BezierUtils.createBezierFactory] - Need p1y to construct a Bezier Factory")
	assert(p2x, "[BezierUtils.createBezierFactory] - Need p2x to construct a Bezier Factory")
	assert(p2y, "[BezierUtils.createBezierFactory] - Need p2y to construct a Bezier Factory")

	local function a(aA1: number, aA2: number): number
		return 1.0 - 3.0 * aA2 + 3.0 * aA1
	end

	local function b(aA1: number, aA2: number): number
		return 3.0 * aA2 - 6.0 * aA1
	end

	local function c(aA1: number): number
		return 3.0 * aA1
	end

	-- Returns x(t) given t, x1, and x2, or y(t) given t, y1, and y2.
	local function calculateBezier(aT: number, aA1: number, aA2: number)
		return ((a(aA1, aA2) * aT + b(aA1, aA2)) * aT + c(aA1)) * aT
	end

	-- Returns dx/dt given t, x1, and x2, or dy/dt given t, y1, and y2.
	local function getSlope(aT: number, aA1: number, aA2: number)
		return 3.0 * a(aA1, aA2) * aT * aT + 2.0 * b(aA1, aA2) * aT + c(aA1)
	end

	-- Newton raphson iteration
	local function getTForX(aX: number): number
		local aGuessT = aX

		for _ = 1, 4 do
			local currentSlope = getSlope(aGuessT, p1x, p2x)

			if currentSlope == 0 then
				return aGuessT
			end
			local currentX = calculateBezier(aGuessT, p1x, p2x) - aX
			aGuessT = aGuessT - currentX / currentSlope
		end

		return aGuessT
	end

	return function(aX: number)
		-- aX is from [0, 1], it's the original time

		return calculateBezier(getTForX(aX), p1y, p2y)
	end
end

return BezierUtils