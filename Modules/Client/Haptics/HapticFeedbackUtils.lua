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
	assert(type(amplitude) == "number")

	return HapticFeedbackUtils.setVibrationMotor(userInputType, Enum.VibrationMotor.Small, amplitude)
end

function HapticFeedbackUtils.setVibrationMotor(userInputType, vibrationMotor, amplitude, ...)
	assert(type(amplitude) == "number")

	if not HapticService:IsVibrationSupported(userInputType) then
		return false
	end

	if not HapticService:IsMotorSupported(userInputType, vibrationMotor) then
		return false
	end

	HapticService:SetMotor(userInputType, vibrationMotor, amplitude, ...)

	return true
end

return HapticFeedbackUtils