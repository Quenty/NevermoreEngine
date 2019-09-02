--- Clean up utils a bit
-- @module HapticFeedbackUtils

local HapticService = game:GetService("HapticService")

local HapticFeedbackUtils = {}

function HapticFeedbackUtils.smallVibrate(userInputType, length, amplitude)
	length = length or 0.1
	amplitude = amplitude or 1

	if HapticFeedbackUtils.setSmallVibration(userInputType, amplitude) then
		delay(length, function()
			HapticFeedbackUtils.setSmallVibration(userInputType, 0)
		end)
	end
end

function HapticFeedbackUtils.setSmallVibration(userInputType, amplitude)
	assert(typeof(amplitude) == "number")

	if not HapticService:IsVibrationSupported(userInputType) then
		return false
	end

	if not HapticService:IsMotorSupported(userInputType, Enum.VibrationMotor.Small) then
		return false
	end

	HapticService:SetMotor(userInputType, Enum.VibrationMotor.Small, amplitude)

	return true
end

return HapticFeedbackUtils