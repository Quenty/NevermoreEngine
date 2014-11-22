-- Probability.lua
-- @author Quenty, w/ contribs for this...

local lib = {}

local function BoxMuller()
	--- Normal curve. [-1, 1]
	
    return math.sqrt(-2 * math.log(math.random())) * math.cos(2 * math.pi * math.random()) / 2
end
lib.BoxMuller = BoxMuller

local function UnboundedNormalDistribution(Average, StdDeviation)
	return Average + BoxMuller() * StdDeviation
end
lib.UnboundedNormalDistribution = UnboundedNormalDistribution

local function NormalDistribution(Average, StdDeviation, HardMin, HardMax)
	return math.min(HardMax, math.max(HardMin, Average + BoxMuller() * StdDeviation))
end
lib.NormalDistribution = NormalDistribution

return lib