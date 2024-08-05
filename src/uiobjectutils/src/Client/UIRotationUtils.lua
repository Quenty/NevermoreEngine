--[=[
	@class UIRotationUtils
]=]

local require = require(script.Parent.loader).load(script)

local UIRotationUtils = {}

function UIRotationUtils.toUnitCircle(rotationDegrees)
	assert(type(rotationDegrees) == "number", "Bad rotationDegrees")

	return -rotationDegrees + 90
end

function UIRotationUtils.toUnitCircleDirection(rotationDegrees)
	assert(type(rotationDegrees) == "number", "Bad rotationDegrees")

	local angle = math.rad(UIRotationUtils.toUnitCircle(rotationDegrees))

	local x = math.cos(angle)
	local y = math.sin(angle)

	return Vector2.new(x, y)
end

function UIRotationUtils.toGuiDirection(unitCircleDirection)
	assert(typeof(unitCircleDirection) == "Vector2", "Bad rotationAnchorPoint")

	return unitCircleDirection*Vector2.new(1, -1)
end


return UIRotationUtils