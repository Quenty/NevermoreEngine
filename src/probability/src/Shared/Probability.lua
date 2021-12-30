--[=[
	Probability utility functions
	@class Probability
]=]

local Probability = {}

--[=[
	Returns a boxMuller random distribution
	@return number
]=]
function Probability.boxMuller()
    return math.sqrt(-2 * math.log(math.random())) * math.cos(2 * math.pi * math.random()) / 2
end

--[=[
	Returns a normal distribution
	@param mean number
	@param standardDeviation number
	@return number
]=]
function Probability.normal(mean, standardDeviation)
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
function Probability.boundedNormal(mean, standardDeviation, hardMin, hardMax)
	return math.clamp(Probability.normal(mean, standardDeviation), hardMin, hardMax)
end

return Probability
