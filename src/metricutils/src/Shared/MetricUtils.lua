--!strict
--[=[
	Provides ways to convert studs to metric and back.
	@class MetricUtils
]=]

local MetricUtils = {}

local STUDS_PER_METER = 3.57
local SECONDS_PER_HOUR = 3600
local SPEED_OF_SOUND_IN_METERS_PER_SECOND = 343
local KPH_TO_MPH = 0.621371192

--[=[
	Computes sound delay for the given studs
	@param studs number
	@return number -- seconds
]=]
function MetricUtils.getSoundDelaySeconds(studs: number): number
	local meters = MetricUtils.studsToMeters(studs)
	return meters / SPEED_OF_SOUND_IN_METERS_PER_SECOND
end

--[=[
	Converts studs to kilometers
	@param studs number
	@return number -- kilometers
]=]
function MetricUtils.studsToKilometers(studs: number): number
	return studs / STUDS_PER_METER / 1000
end

--[=[
	Converts studs to meters
	@param studs number
	@return number -- meters
]=]
function MetricUtils.studsToMeters(studs: number): number
	return studs / STUDS_PER_METER
end

--[=[
	Convert from studs per a second (Roblox in-game units) to kph
	@param studsPerSecond number
	@return number -- kph
]=]
function MetricUtils.studsPerSecondToKph(studsPerSecond: number): number
	return studsPerSecond / STUDS_PER_METER / 1000 * SECONDS_PER_HOUR
end

--[=[
	Convert from studs per a second to meters per a second

	@param studsPerSecond number
	@return number -- kph
]=]
function MetricUtils.studsPerSecondToMetersPerSecond(studsPerSecond: number): number
	return studsPerSecond / STUDS_PER_METER
end

--[=[
	Convert from studs per a second (Roblox in-game units) to mph
	@param studsPerSecond number
	@return number -- mph
]=]
function MetricUtils.studsPerSecondToMph(studsPerSecond: number): number
	return studsPerSecond / STUDS_PER_METER / 1000 * SECONDS_PER_HOUR * KPH_TO_MPH
end

--[=[
	Convert mph to studs per a second
	@param kph number
	@return number -- studs per a second
]=]
function MetricUtils.kphToStudsPerSecond(kph: number): number
	return kph * STUDS_PER_METER * 1000 / SECONDS_PER_HOUR
end

--[=[
	Convert mph to studs per a second
	@param mph number
	@return number  -- studs per a second
]=]
function MetricUtils.mphToStudsPerSecond(mph: number): number
	return mph * STUDS_PER_METER * 1000 / SECONDS_PER_HOUR / KPH_TO_MPH
end

return MetricUtils
