---
-- @module MetricUtils
-- @author Quenty

local MetricUtils = {}

local STUDS_PER_METER = 3.57

local SPEED_OF_SOUND_IN_METERS_PER_SECOND = 343

function MetricUtils.getSoundDelaySeconds(studs)
	local meters = MetricUtils.studsToMeters(studs)
	return meters/SPEED_OF_SOUND_IN_METERS_PER_SECOND
end

function MetricUtils.studsToKilometers(studs)
	return studs/STUDS_PER_METER/1000
end

function MetricUtils.studsToMeters(studs)
	return studs/STUDS_PER_METER
end

return MetricUtils