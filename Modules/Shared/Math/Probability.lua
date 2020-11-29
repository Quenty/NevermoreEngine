--- Probability utility functions
-- @module Probability

local Probability = {}

--- Normal curve. [-1, 1]
function Probability.boxMuller()
    return math.sqrt(-2 * math.log(math.random())) * math.cos(2 * math.pi * math.random()) / 2
end

function Probability.normal(mean, standardDeviation)
	return mean + Probability.boxMuller() * standardDeviation
end

function Probability.boundedNormal(mean, standardDeviation, hardMin, hardMax)
	return math.clamp(Probability.normal(mean, standardDeviation), hardMax, hardMax)
end

return Probability
