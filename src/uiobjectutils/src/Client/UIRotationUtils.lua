--!strict
--[=[
	@class UIRotationUtils
]=]

local UIRotationUtils = {}

--[=[
	Converts a rotation to the unit circle
]=]
function UIRotationUtils.toUnitCircle(rotationDegrees: number): number
	assert(type(rotationDegrees) == "number", "Bad rotationDegrees")

	return -rotationDegrees + 90
end

--[=[
	Converts a rotation to the unit circle direction
]=]
function UIRotationUtils.toUnitCircleDirection(rotationDegrees: number): Vector2
	assert(type(rotationDegrees) == "number", "Bad rotationDegrees")

	local angle = math.rad(UIRotationUtils.toUnitCircle(rotationDegrees))

	local x = math.cos(angle)
	local y = math.sin(angle)

	return Vector2.new(x, y)
end

--[=[
	Converts a rotation to the gui rotation vector
]=]
function UIRotationUtils.toGuiDirection(unitCircleDirection: Vector2): Vector2
	assert(typeof(unitCircleDirection) == "Vector2", "Bad rotationAnchorPoint")

	return unitCircleDirection * Vector2.new(1, -1)
end

return UIRotationUtils
