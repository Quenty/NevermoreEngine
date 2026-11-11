--!strict
--[=[
	Provides ways to convert studs to metric and back, at 3.57 studs to the metre as these functions have always
	counted them. Each is a plain multiplication, by a factor [MetricUnit] works out once, so they are cheap enough
	to call every frame; for typed values, or Roblox's own 28 cm stud, use [MetricUnit] directly.
	@class MetricUtils
]=]

local require = require(script.Parent.loader).load(script)

local MetricUnit = require("MetricUnit")
local MetricUnitSystems = require("MetricUnitSystems")

local MetricUtils = {}

type Factors = {
	secondsOfSoundPerStud: number,
	kilometersPerStud: number,
	metersPerStud: number,
	kphPerStudPerSecond: number,
	mphPerStudPerSecond: number,
}

local factors: Factors? = nil

local function getFactors(): Factors
	local found = factors
	if found then
		return found
	end
	local studs = MetricUnitSystems.roblox({ name = "metricUtils", metersPerStud = 1 / 3.57 })
	local stud = studs:New(1, "stud")
	local studPerSecond = studs:New(1, "studPerSecond")
	local speedOfSoundInDryAirAt20C = MetricUnit.new(343, "meterPerSecond")
	local computed: Factors = table.freeze({
		secondsOfSoundPerStud = (stud / speedOfSoundInDryAirAt20C):InSeconds(),
		kilometersPerStud = stud:In("kilometer"),
		metersPerStud = stud:In("meter"),
		kphPerStudPerSecond = studPerSecond:In("kilometerPerHour"),
		mphPerStudPerSecond = studPerSecond:In("milePerHour"),
	})
	factors = computed
	return computed
end

--[=[
	Computes sound delay for the given studs
	@param studs number
	@return number -- seconds
]=]
function MetricUtils.getSoundDelaySeconds(studs: number): number
	return studs * getFactors().secondsOfSoundPerStud
end

--[=[
	Converts studs to kilometers
	@param studs number
	@return number -- kilometers
]=]
function MetricUtils.studsToKilometers(studs: number): number
	return studs * getFactors().kilometersPerStud
end

--[=[
	Converts studs to meters
	@param studs number
	@return number -- meters
]=]
function MetricUtils.studsToMeters(studs: number): number
	return studs * getFactors().metersPerStud
end

--[=[
	Convert from studs per a second (Roblox in-game units) to kph
	@param studsPerSecond number
	@return number -- kph
]=]
function MetricUtils.studsPerSecondToKph(studsPerSecond: number): number
	return studsPerSecond * getFactors().kphPerStudPerSecond
end

--[=[
	Convert from studs per a second to meters per a second

	@param studsPerSecond number
	@return number -- meters per a second
]=]
function MetricUtils.studsPerSecondToMetersPerSecond(studsPerSecond: number): number
	return studsPerSecond * getFactors().metersPerStud
end

--[=[
	Convert from studs per a second (Roblox in-game units) to mph
	@param studsPerSecond number
	@return number -- mph
]=]
function MetricUtils.studsPerSecondToMph(studsPerSecond: number): number
	return studsPerSecond * getFactors().mphPerStudPerSecond
end

--[=[
	Convert kph to studs per a second
	@param kph number
	@return number -- studs per a second
]=]
function MetricUtils.kphToStudsPerSecond(kph: number): number
	return kph / getFactors().kphPerStudPerSecond
end

--[=[
	Convert mph to studs per a second
	@param mph number
	@return number  -- studs per a second
]=]
function MetricUtils.mphToStudsPerSecond(mph: number): number
	return mph / getFactors().mphPerStudPerSecond
end

return MetricUtils
