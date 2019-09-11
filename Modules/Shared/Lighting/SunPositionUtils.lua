--- Utility to position the sun
-- @module SunPositionUtils

local SunPositionUtils = {}

function SunPositionUtils.getGeographicalLatitude(direction)
	local angle = math.atan2(direction.z, math.sqrt(direction.x^2 + direction.y^2))
	return angle/(math.pi*2)*360+23.5
end

function SunPositionUtils.getClockTime(direction)
	local clockTime = math.atan2(-direction.y, -direction.x)

	return (clockTime/(math.pi*2)*24-6) % 24
end

return SunPositionUtils