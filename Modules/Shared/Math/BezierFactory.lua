--- Make interpolation curves
-- A good place to generate and test these out: http://cubic-bezier.com/
-- Based upon https://gist.github.com/gre/1926947#file-keyspline-js
-- @module BezierFactory

local lib = {}

function lib.BezierFactory(P1x, P1y, P2x, P2y)
	-- Same as CSS transition thing.

	assert(P1x, "[BezierFactory] - Need P1x to construct a Bezier Factory")
	assert(P1y, "[BezierFactory] - Need P1y to construct a Bezier Factory")
	assert(P2x, "[BezierFactory] - Need P2x to construct a Bezier Factory")
	assert(P2y, "[BezierFactory] - Need P2y to construct a Bezier Factory")

	local function A(aA1, aA2)
		return 1.0 - 3.0 * aA2 + 3.0 * aA1
	end

	local function B(aA1, aA2)
		return 3.0 * aA2 - 6.0 * aA1
	end

	local function C(aA1)
		return 3.0 * aA1
	end

	-- Returns x(t) given t, x1, and x2, or y(t) given t, y1, and y2.
	local function CalculateBezier(aT, aA1, aA2)
		return ((A(aA1, aA2)*aT + B(aA1, aA2))*aT + C(aA1))*aT
	end

	-- Returns dx/dt given t, x1, and x2, or dy/dt given t, y1, and y2.
	local function GetSlope(aT, aA1, aA2)
		return 3.0 * A(aA1, aA2)*aT*aT + 2.0 * B(aA1, aA2) * aT + C(aA1)
	end

	-- Newton raphson iteration
	local function GetTForX(aX)
		local aGuessT = aX

		for _ = 1, 4 do
			local CurrentSlope = GetSlope(aGuessT, P1x, P2x)

			if CurrentSlope == 0 then
				return aGuessT
			end
			local CurrentX = CalculateBezier(aGuessT, P1x, P2x) - aX
			aGuessT = aGuessT - CurrentX / CurrentSlope
		end

		return aGuessT
	end

	return function(aX)
		-- aX is from [0, 1], it's the original time

		return CalculateBezier(GetTForX(aX), P1y, P2y)
	end
end

--[[ @usage
local Ease = BezierFactory(0.25, 0.1, 0.25, 1)
for Index = 0, 1.05, 0.05 do
	print(Index, ":", Ease(Index))
end
--]]

return lib