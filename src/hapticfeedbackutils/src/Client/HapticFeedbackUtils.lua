--!strict
--[=[
	Utility functions involving haptic feedback on gamepads.
	@class HapticFeedbackUtils
]=]

local HapticService = game:GetService("HapticService")

local HapticFeedbackUtils = {}

--[=[
	Provides a small vibration.

	@param userInputType UserInputType
	@param length number
	@param amplitude number
]=]
function HapticFeedbackUtils.smallVibrate(userInputType: Enum.UserInputType, length: number, amplitude: number)
	length = length or 0.1
	amplitude = amplitude or 1

	if HapticFeedbackUtils.setSmallVibration(userInputType, amplitude) then
		task.delay(length, function()
			HapticFeedbackUtils.setSmallVibration(userInputType, 0)
		end)
	end
end

--[=[
	Sets the small vibrators on the gamepad
	@param userInputType UserInputType
	@param amplitude number
	@return boolean
]=]
function HapticFeedbackUtils.setSmallVibration(userInputType: Enum.UserInputType, amplitude: number): boolean
	assert(type(amplitude) == "number", "Bad amplitude")

	return HapticFeedbackUtils.setVibrationMotor(userInputType, Enum.VibrationMotor.Small, amplitude)
end

--[=[
	Sets the large vibrators on the gamepad
	@param userInputType UserInputType
	@param amplitude number
	@return boolean
]=]
function HapticFeedbackUtils.setLargeVibration(userInputType: Enum.UserInputType, amplitude: number): boolean
	assert(type(amplitude) == "number", "Bad amplitude")

	return HapticFeedbackUtils.setVibrationMotor(userInputType, Enum.VibrationMotor.Large, amplitude)
end

--[=[
	Sets the small vibrators on the gamepad
	@param userInputType UserInputType
	@param vibrationMotor VibrationMotor
	@param amplitude number
	@param ... number -- vibrationValues
	@return boolean
]=]
function HapticFeedbackUtils.setVibrationMotor(
	userInputType: Enum.UserInputType,
	vibrationMotor: Enum.VibrationMotor,
	amplitude: number,
	...: number
): boolean
	assert(type(amplitude) == "number", "Bad amplitude")

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
