-- Smooth Interpolation Curve Generator
-- Bezier.new(x1, y1, x2, y2)
-- @param numbers (x1, y1, x2, y2) The control points of your curve
-- @returns function(t [b, c, d])
--	@param number t the time elapsed [0, d]
--	@param number b beginning value being interpolated (default = 0)
--	@param number c change in value being interpolated (equivalent to: ending - beginning) (default = 1)
--	@param number d duration interpolation is occurring over (default = 1)
-- @see Validark
-- @original https://github.com/gre/bezier-easing
-- @testsite http://cubic-bezier.com/
-- @testsite http://greweb.me/bezier-easing-editor/example/

-- These values are established by empiricism with tests (tradeoff: performance VS precision)
local NEWTON_ITERATIONS = 4
local NEWTON_MIN_SLOPE = 0.001
local SUBDIVISION_PRECISION = 0.0000001
local SUBDIVISION_MAX_ITERATIONS = 10
local K_SPLINE_TABLE_SIZE = 11

local K_SAMPLE_STEP_SIZE = 1 / (K_SPLINE_TABLE_SIZE - 1)

local function Linear(t, b, c, d)
	return (c or 1)*t / (d or 1) + (b or 0)
end

local Bezier = {}

function Bezier.new(x1, y1, x2, y2)
	if not (x1 and y1 and x2 and y2) then error("[Bezier] Need 4 numbers to construct a Bezier curve", 2) end
	if not (0 <= x1 and x1 <= 1 and 0 <= x2 and x2 <= 1) then error("[Bezier] The x values must be within range [0, 1]", 2) end

	if x1 == y1 and x2 == y2 then
		return Linear
	end

	-- Precompute redundant values
	local e, f = 3*x1, 3*x2
	local g, h, i = 1 - f + e, f - 2*e, 3*(1 - f + e)
	local j, k = 2*h, 3*y1
	local l, m = 1 - 3*y2 + k, 3*y2 - 2*k
	
	-- Precompute samples table
	local SampleValues = {}
	for a = 0, K_SPLINE_TABLE_SIZE - 1 do
		local z = a*K_SAMPLE_STEP_SIZE
		SampleValues[a] = ((g*z + h)*z + e)*z -- CalcBezier
	end

	return function(t, b, c, d)
		t = (c or 1)*t / (d or 1) + (b or 0)

		if t == 0 or t == 1 then -- Make sure the endpoints are correct
			return t
		end

		local CurrentSample = K_SPLINE_TABLE_SIZE - 2

		for a = 1, CurrentSample do
			if SampleValues[a] > t then
				CurrentSample = a - 1
				break
			end
		end

		-- Interpolate to provide an initial guess for t
		local IntervalStart = CurrentSample*K_SAMPLE_STEP_SIZE
		local GuessForT = IntervalStart + K_SAMPLE_STEP_SIZE*(t - SampleValues[CurrentSample]) / (SampleValues[CurrentSample + 1] - SampleValues[CurrentSample])
		local InitialSlope = (i*GuessForT + j)*GuessForT + e

		if InitialSlope >= NEWTON_MIN_SLOPE then
			for NewtonRaphsonIterate = 1, NEWTON_ITERATIONS do
				local CurrentSlope = (i*GuessForT + j)*GuessForT + e
				if CurrentSlope == 0 then break end
				GuessForT = GuessForT - (((g*GuessForT + h)*GuessForT + e)*GuessForT - t) / CurrentSlope
			end
		elseif InitialSlope ~= 0 then
			local IntervalStep = IntervalStart + K_SAMPLE_STEP_SIZE

			for BinarySubdivide = 1, SUBDIVISION_MAX_ITERATIONS do
				GuessForT = IntervalStart + 0.5*(IntervalStep - IntervalStart)
				local BezierCalculation = ((g*GuessForT + h)*GuessForT + e)*GuessForT - t

				if BezierCalculation > 0 then
					IntervalStep = GuessForT
				else
					IntervalStart = GuessForT
					BezierCalculation = -BezierCalculation
				end

				if BezierCalculation <= SUBDIVISION_PRECISION then break end
			end
		end
		return ((l*GuessForT + m)*GuessForT + k)*GuessForT
	end
end

return setmetatable(Bezier, {__call = function(Bezier, ...)
	return Bezier.new(...)
end})
