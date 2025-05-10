--!strict
--[=[
	Utilties for IK system
	@class IKUtils
]=]

local IKUtils = {}

function IKUtils.getDampenedAngleClamp(
	maxAngle: number,
	dampenAreaAngle: number,
	dampenAreaFactor: number?
): (number) -> number
	local areaFactor = dampenAreaFactor or dampenAreaAngle

	return function(angle)
		local min = maxAngle - dampenAreaAngle
		if math.abs(angle) <= min then
			return angle
		else
			-- dampenAreaFactor is the area that the bouncing happens
			-- dampenAreaAngle is the amount of bounce that occurs
			local timesOver = (math.abs(angle) - min) / areaFactor
			local scale = (1 - 0.5 ^ timesOver)

			return math.sign(angle) * (min + (scale * dampenAreaAngle))
		end
	end
end

return IKUtils
