--[=[
	Provides ways to convert studs to metric and back.
	@class MetricUtils
]=]

local MetricUtils = {}

local STUDS_PER_METER = 3.57

local SPEED_OF_SOUND_IN_METERS_PER_SECOND = 343

--[=[
	Computes sound delay for the given studs
	@param studs number
	@return number -- seconds
]=]
function MetricUtils.getSoundDelaySeconds(studs)
	local meters = MetricUtils.studsToMeters(studs)
	return meters/SPEED_OF_SOUND_IN_METERS_PER_SECOND
end

--[=[
	Converts studs to kilometers
	@param studs number
	@return number -- kilometers
]=]
function MetricUtils.studsToKilometers(studs)
	return studs/STUDS_PER_METER/1000
end

--[=[
	Converts studs to kilometers
	@param studs number
	@return number -- meters
]=]
function MetricUtils.studsToMeters(studs)
	return studs/STUDS_PER_METER
end

return MetricUtils