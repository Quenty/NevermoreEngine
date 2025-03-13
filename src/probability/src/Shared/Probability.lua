--!strict
--[=[
	Probability utility functions
	@class Probability
]=]

local Probability = {}

--[=[
	Returns a boxMuller random distribution
	@return number
]=]
function Probability.boxMuller(): number
	return math.sqrt(-2 * math.log(math.random())) * math.cos(2 * math.pi * math.random()) / 2
end

--[=[
	Returns a normal distribution
	@param mean number
	@param standardDeviation number
	@return number
]=]
function Probability.normal(mean: number, standardDeviation: number): number
	return mean + Probability.boxMuller() * standardDeviation
end

--[=[
	Returns a bounded normal, clamping the normal value
	@param mean number
	@param standardDeviation number
	@param hardMin number
	@param hardMax number
	@return number
]=]
function Probability.boundedNormal(mean: number, standardDeviation: number, hardMin: number, hardMax: number)
	return math.clamp(Probability.normal(mean, standardDeviation), hardMin, hardMax)
end

--[=[
	Approximation of the error function (erf) using the Abramowitz and Stegun formula

	https://en.wikipedia.org/wiki/Error_function

	@param x number
	@return number
]=]
function Probability.erf(x: number): number
	local t = 1 / (1 + 0.5 * math.abs(x))
	local erf_approx = 1
		- t
			* math.exp(
				-x * x
					- 1.26551223
					+ t
						* (1.00002368 + t * (0.37409196 + t * (0.09678418 + t * (-0.18628806 + t * (0.27886807 + t * (-1.13520398 + t * (1.48851587 + t * (-0.82215223 + t * 0.17087277))))))))
			)
	if x >= 0 then
		return erf_approx
	else
		return -erf_approx
	end
end

--[=[
	Standard normal cumulative distribution function. Returns the value from 0 to 1.

	This is also known as percentile!

	@param zScore number
	@return number
]=]
function Probability.cdf(zScore: number): number
	assert(type(zScore) == "number", "Bad zScore")

	return 0.5 * (1 + Probability.erf(zScore / math.sqrt(2)))
end

--[=[
	Function to calculate the inverse error function (erfinv) using Newton's method

	@param x number
	@return number
]=]
function Probability.erfinv(x: number): number?
	assert(type(x) == "number", "Bad x")

	if x < -1 or x > 1 then
		return nil
	elseif x == -1 then
		return -math.huge
	elseif x == 1 then
		return math.huge
	end

	local tolerance = 1e-15
	local maxIterations = 1000

	local function derivative(y: number): number
		return 2 * math.exp(-y * y) / math.sqrt(math.pi)
	end

	local y = 0
	for _ = 1, maxIterations do
		local error = Probability.erf(y) - x
		if math.abs(error) < tolerance then
			return y
		end
		y = y - error / derivative(y)
	end

	-- If Newton's method fails to converge, return nil
	return nil
end

--[=[
	Standard normal cumulative distribution function. Returns the value from 0 to 1.

	This is also known as percentile!

	@param percentile number
	@return number
]=]
function Probability.percentileToZScore(percentile: number): number?
	assert(type(percentile) == "number" and percentile >= 0 and percentile <= 1, "Bad percentile")

	-- Calculate z-score using inverse cumulative distribution function (norm.ppf)
	local erfinv = Probability.erfinv(2 * percentile - 1)
	if erfinv == nil then
		return nil
	end

	local zScore = math.sqrt(2) * erfinv

	return zScore
end

return Probability
