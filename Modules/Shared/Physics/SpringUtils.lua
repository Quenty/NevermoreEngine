---
-- @module SpringUtils
-- @author Quenty

local EPSILON = 1e-6

local SpringUtils = {}

function SpringUtils.animating(spring, epsilon)
	epsilon = epsilon or EPSILON

	local position = spring.Position
	local target = spring.Target
	local animating = math.abs(spring.Position - spring.Target) > epsilon
		or math.abs(spring.Velocity) > epsilon

	if animating then
		return true, position
	else
		-- We need to return the target so we use the actual target value (i.e. pretend like the spring is asleep)
		return false, target
	end
end

return SpringUtils