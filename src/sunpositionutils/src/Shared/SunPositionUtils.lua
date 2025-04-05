--!strict
--[=[
	Utility to position the sun and to retrieve sun information specific to Roblox.

	Note this is not an accurate guess of where the sun would be on earth, but rather
	the computation to compute where Roblox is rendering the sun given the lighting
	properties set.

	@class SunPositionUtils
]=]
local SunPositionUtils = {}

local EARTH_TILT = 23.5
local NORTH = Vector3.new(0, 0, -1)
local ZAXIS = Vector3.new(0, 0, 1)

--[=[
	Gets the geographical latitude from a vector pointing at the sun.

	@param direction Vector3
	@return number
]=]
function SunPositionUtils.getGeographicalLatitudeFromDirection(direction: Vector3): number
	local x = direction.X
	local y = direction.Y
	local angle = math.atan2(direction.Z, math.sqrt(x * x + y * y))
	return angle / (math.pi * 2) * 360 + EARTH_TILT
end

SunPositionUtils.getGeographicalLatitudeFromMoonDirection = SunPositionUtils.getGeographicalLatitudeFromDirection

--[=[
	Gets the clock time for the given direction.

	@param direction Vector3
	@return number
]=]
function SunPositionUtils.getClockTimeFromDirection(direction: Vector3): number
	local altitude = math.atan2(-direction.Y, -direction.X)

	return (altitude / (math.pi * 2) * 24 - 6) % 24
end

--[=[
	Gets the clock time from the given moon direction.

	@param direction Vector3
	@return number
]=]
function SunPositionUtils.getClockTimeFromMoonDirection(direction: Vector3): number
	local altitude = math.atan2(direction.Y, direction.X)

	return (altitude / (math.pi * 2) * 24 - 6) % 24
end

--[=[
	Gets the direction the sun should be facing given the azimuth and altitude

	@param azimuthRad number
	@param altitudeRad number
	@param north Vector3?
	@return number
]=]
function SunPositionUtils.getDirection(azimuthRad: number, altitudeRad: number, north: Vector3): Vector3
	local cframe: CFrame = (CFrame.Angles(0, azimuthRad, 0) * CFrame.Angles(altitudeRad, 0, 0))
	return cframe:VectorToWorldSpace(north or NORTH)
end

--[=[
	Estimates the sun position given the clockTime and geographical latitude.

	@param clockTime number
	@param geoLatitude number
	@return Vector3 -- Sun position
	@return Vector3 -- Moon position
]=]
function SunPositionUtils.getSunPosition(clockTime: number, geoLatitude: number): (Vector3, Vector3)
	local seconds = clockTime*60*60
	local DAY = 24 * 60 * 60
	local YEAR = 365.2564 * DAY
	local HALFYEAR = 182.6282
	local EARTHTILT = math.rad(23.5)

	local modTime = seconds - math.floor(seconds / DAY) * DAY
	local sourceAngle = 2 * math.pi * modTime / DAY
	local sunPosition = Vector3.new(math.sin(sourceAngle), -math.cos(sourceAngle), 0)
	local moonPosition = Vector3.new(math.sin(sourceAngle + math.pi), math.cos(sourceAngle + math.pi), 0)
	local dayOfYearOffset = (seconds - (seconds * math.floor(seconds / YEAR))) / DAY

	local latRad = math.rad(geoLatitude)
	local sunOffset = -EARTHTILT * math.cos(math.pi * (dayOfYearOffset - HALFYEAR) / HALFYEAR) - latRad

	local trueSunPosition = CFrame.fromAxisAngle(ZAXIS:Cross(sunPosition), sunOffset) * sunPosition
	local trueMoonPosition = CFrame.fromAxisAngle(ZAXIS:Cross(moonPosition), sunOffset) * moonPosition

	return trueSunPosition, trueMoonPosition*Vector3.new(1, -1, 1)
end

return SunPositionUtils