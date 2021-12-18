--- Utility to position the sun
-- @module SunPositionUtils

local SunPositionUtils = {}

local EARTH_TILT = 23.5
local NORTH = Vector3.new(0, 0, -1)

function SunPositionUtils.getGeographicalLatitudeFromDirection(direction)
	local angle = math.atan2(direction.z, math.sqrt(direction.x^2 + direction.y^2))
	return angle/(math.pi*2)*360+EARTH_TILT
end

SunPositionUtils.getGeographicalLatitudeFromMoonDirection = SunPositionUtils.getGeographicalLatitudeFromDirection

function SunPositionUtils.getClockTimeFromDirection(direction)
	local altitude = math.atan2(-direction.y, -direction.x)

	return (altitude/(math.pi*2)*24-6) % 24
end

function SunPositionUtils.getClockTimeFromMoonDirection(direction)
	local altitude = math.atan2(direction.y, direction.x)

	return (altitude/(math.pi*2)*24-6) % 24
end

function SunPositionUtils.getDirection(azimuthRad, altitudeRad, north)
	local cframe = (CFrame.Angles(0, azimuthRad, 0) * CFrame.Angles(altitudeRad, 0, 0))
	return cframe:vectorToWorldSpace(north or NORTH)
end

function SunPositionUtils.getSunPosition(clockTime, geoLatitude)
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

	local trueSunPosition = CFrame.fromAxisAngle(Vector3.zAxis:Cross(sunPosition), sunOffset) * sunPosition
	local trueMoonPosition = CFrame.fromAxisAngle(Vector3.zAxis:Cross(moonPosition), sunOffset) * moonPosition

	return trueSunPosition, trueMoonPosition*Vector3.new(1, -1, 1)
end

return SunPositionUtils