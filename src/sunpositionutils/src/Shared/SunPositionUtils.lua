--- Utility to position the sun
-- @module SunPositionUtils

local SunPositionUtils = {}

local EARTH_TILT = 23.5
local NORTH = Vector3.new(0, 0, -1)

function SunPositionUtils.getGeographicalLatitudeFromDirection(direction)
	local angle = math.atan2(direction.z, math.sqrt(direction.x^2 + direction.y^2))
	return angle/(math.pi*2)*360+EARTH_TILT
end

function SunPositionUtils.getClockTimeFromDirection(direction)
	local altitude = math.atan2(-direction.y, -direction.x)

	return (altitude/(math.pi*2)*24-6) % 24
end

function SunPositionUtils.getDirection(azimuthRad, altitudeRad, north)
	local cframe = (CFrame.Angles(0, azimuthRad, 0) * CFrame.Angles(altitudeRad, 0, 0))
	return cframe:vectorToWorldSpace(north or NORTH)
end

return SunPositionUtils