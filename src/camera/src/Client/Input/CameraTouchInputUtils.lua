--!strict
--[=[
	Utility methods involving touch input and cameras.
	@class CameraTouchInputUtils
]=]

local CameraTouchInputUtils = {}

-- Note: DotProduct check in CoordinateFrame::lookAt() prevents using values within about
-- 8.11 degrees of the +/- Y axis, that's why these limits are currently 80 degrees
local MIN_Y = math.rad(-80)
local MAX_Y = math.rad(80)

local TOUCH_ADJUST_AREA_UP = math.rad(30)
local TOUCH_ADJUST_AREA_DOWN = math.rad(-15)

local TOUCH_SENSITIVTY_ADJUST_MAX_Y = 2.1
local TOUCH_SENSITIVTY_ADJUST_MIN_Y = 0.5

--[=[
	Adjusts the camera Y touch Sensitivity when moving away from the center and in the TOUCH_SENSITIVTY_ADJUST_AREA
	Straight from Roblox's code

	@param currPitchAngle number
	@param sensitivity Vector2
	@param delta Vector2
	@return Vector2
]=]
function CameraTouchInputUtils.adjustTouchSensitivity(
	currPitchAngle: number,
	sensitivity: Vector2,
	delta: Vector2
): Vector2
	local multiplierY = TOUCH_SENSITIVTY_ADJUST_MAX_Y
	if currPitchAngle > TOUCH_ADJUST_AREA_UP and delta.Y < 0 then
		local fractionAdjust = (currPitchAngle - TOUCH_ADJUST_AREA_UP) / (MAX_Y - TOUCH_ADJUST_AREA_UP)
		fractionAdjust = 1 - (1 - fractionAdjust) ^ 3
		multiplierY = TOUCH_SENSITIVTY_ADJUST_MAX_Y
			- fractionAdjust * (TOUCH_SENSITIVTY_ADJUST_MAX_Y - TOUCH_SENSITIVTY_ADJUST_MIN_Y)
	elseif currPitchAngle < TOUCH_ADJUST_AREA_DOWN and delta.Y > 0 then
		local fractionAdjust = (currPitchAngle - TOUCH_ADJUST_AREA_DOWN) / (MIN_Y - TOUCH_ADJUST_AREA_DOWN)
		fractionAdjust = 1 - (1 - fractionAdjust) ^ 3
		multiplierY = TOUCH_SENSITIVTY_ADJUST_MAX_Y
			- fractionAdjust * (TOUCH_SENSITIVTY_ADJUST_MAX_Y - TOUCH_SENSITIVTY_ADJUST_MIN_Y)
	end

	return Vector2.new(sensitivity.X, sensitivity.Y * multiplierY)
end

return CameraTouchInputUtils
