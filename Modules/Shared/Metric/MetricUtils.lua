---
-- @module MetricUtils
-- @author Quenty

local MetricUtils = {}

-- Source: https://devforum.roblox.com/t/studs-to-metre-conversion/555264/2
local NORMAL_STUDS_PER_METER = 1 / 0.28

local SPEED_OF_SOUND_IN_METERS_PER_SECOND = 343

-- ROBLOX equivalent of 9.81 m/s^2 as derived from the 'Realistic' setting in 'World Settings'
local NORMAL_GRAVITY = 35

function MetricUtils.getSoundDelaySeconds(studs)
	local meters = MetricUtils.studsToMeters(studs)

	return meters / SPEED_OF_SOUND_IN_METERS_PER_SECOND
end

function MetricUtils.studsToKilometers(studs)
	return MetricUtils.studsToMeters(studs) / 1000
end

function MetricUtils.studsToMeters(studs)
	return MetricUtils.convertMeter(studs, -1)
end

function MetricUtils.convertKiloGram(value, unitExponent)
	-- Roblox water has a density of 1 and is normally ~ 1000 kg*m^-3, so divide by 1000
	local realKiloGram = MetricUtils.getStudsPerMeter() ^ 3 / 1000

	return value * realKiloGram ^ unitExponent
end

function MetricUtils.convertMeter(value, unitExponent)
	return value * MetricUtils.getStudsPerMeter() ^ unitExponent
end

function MetricUtils.convertMeterAndKiloGram(value, meterUnitExponent, kiloGramUnitExponent)
	return MetricUtils.convertKiloGram(MetricUtils.convertMeter(value, meterUnitExponent), kiloGramUnitExponent)
end

function MetricUtils.getStudsPerMeter()
	-- Make the module work for every workspace.Gravity
	-- Always take the latest workspace.Gravity
	return NORMAL_STUDS_PER_METER * workspace.Gravity / NORMAL_GRAVITY
end

return MetricUtils
