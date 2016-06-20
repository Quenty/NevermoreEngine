-- @author Quenty, w/ contribs for this...

local _2pi = 2*math.pi
local log = math.log
local cos = math.cos
local min = math.min
local max = math.max
local random = math.random

local function BoxMuller() -- Normal curve. [-1, 1]
    return (-2 * log(random()))^.5 * cos(_2pi * random()) * .5
end

local function NormalDistribution(Average, StdDeviation, HardMin, HardMax)
	return min(HardMax, max(HardMin, Average + BoxMuller() * StdDeviation))
end

local function UnboundedNormalDistribution(Average, StdDeviation)
	return Average + BoxMuller() * StdDeviation
end

return {
	BoxMuller = BoxMuller;
	NormalDistribution = NormalDistribution;
	UnboundedNormalDistribution = UnboundedNormalDistribution;
}
