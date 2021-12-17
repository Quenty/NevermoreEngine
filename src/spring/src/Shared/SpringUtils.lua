---
-- @module SpringUtils
-- @author Quenty

local EPSILON = 1e-6

local require = require(script.Parent.loader).load(script)
local LinearValue = require("LinearValue")

local SpringUtils = {}

function SpringUtils.animating(spring, epsilon)
	epsilon = epsilon or EPSILON

	local position = spring.Position
	local target = spring.Target

	local animating
	if type(target) == "number" then
		animating = math.abs(spring.Position - spring.Target) > epsilon
			or math.abs(spring.Velocity) > epsilon
	elseif typeof(target) == "Vector3" or LinearValue.isLinear(target) then
		animating = (spring.Position - spring.Target).magnitude > epsilon
			or spring.Velocity.magnitude > epsilon
	else
		error("Unknown type")
	end

	if animating then
		return true, position
	else
		-- We need to return the target so we use the actual target value (i.e. pretend like the spring is asleep)
		return false, target
	end
end

-- Add to spring position to adjust for velocity of target. May have to set clock to time().
function SpringUtils.getVelocityAdjustment(velocity, dampen, speed)
	assert(velocity, "Bad velocity")
	assert(dampen, "Bad dampen")
	assert(speed, "Bad speed")

	return velocity*(2*dampen/speed)
end

function SpringUtils.toLinearIfNeeded(value)
	if typeof(value) == "Color3" then
		return LinearValue.new(Color3.new, {value.r, value.g, value.b})
	else
		return value
	end
end

function SpringUtils.fromLinearIfNeeded(value)
	if LinearValue.isLinear(value) then
		return value:ToBaseValue()
	else
		return value
	end
end

return SpringUtils