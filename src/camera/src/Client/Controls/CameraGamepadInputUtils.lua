--!strict
--[=[
	Utility classes to work with gamepad thumbsticks
	@class CameraGamepadInputUtils
]=]

local CameraGamepadInputUtils = {}

-- K is a tunable parameter that changes the shape of the S-curve
-- the larger K is the more straight/linear the curve gets
local k = 0.35
local lowerK = 0.8
local function SCurveTranform(t: number): number
	t = math.clamp(t, -1, 1)
	if t >= 0 then
		return (k * t) / (k - t + 1)
	end
	return -((lowerK * -t) / (lowerK + t + 1))
end

local DEADZONE = 0.1
local function toSCurveSpace(t: number): number
	return (1 + DEADZONE) * (2 * math.abs(t) - 1) - DEADZONE
end

local function fromSCurveSpace(t: number): number
	return t / 2 + 0.5
end

local function onAxis(axisValue: number): number
	local sign = 1
	if axisValue < 0 then
		sign = -1
	end
	local point = fromSCurveSpace(SCurveTranform(toSCurveSpace(math.abs(axisValue))))
	point = point * sign
	return math.clamp(point, -1, 1)
end

--[=[
Returns true if the input is outside the deadzone.

	@param inputObject InputObject
	@return boolean
]=]
function CameraGamepadInputUtils.outOfDeadZone(inputObject: InputObject): boolean
	local stickOffset = inputObject.Position
	return stickOffset.Magnitude >= DEADZONE
end

--[=[
	Converts a thumbstick position to a curve space.

	@within CameraGamepadInputUtils
	@param thumbstickPosition Vector2
	@return Vector2
]=]
function CameraGamepadInputUtils.gamepadLinearToCurve(thumbstickPosition: Vector2): Vector2
	return Vector2.new(onAxis(thumbstickPosition.X), onAxis(thumbstickPosition.Y))
end

return CameraGamepadInputUtils
