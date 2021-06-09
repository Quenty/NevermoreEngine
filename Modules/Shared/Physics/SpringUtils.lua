---
-- @module SpringUtils
-- @author Quenty

local EPSILON = 1e-6

local SpringUtils = {}

function SpringUtils.animating(spring, epsilon)
	epsilon = epsilon or EPSILON

	local position = spring.Position
	local target = spring.Target

	local animating
	if type(target) == "number" then
		animating = math.abs(spring.Position - spring.Target) > epsilon
			or math.abs(spring.Velocity) > epsilon
	elseif typeof(target) == "Vector3" then
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
function SpringUtils.getVelocityAdjustment(position, velocity, dampen, speed)
	return velocity*(2*dampen/speed)
end

return SpringUtils