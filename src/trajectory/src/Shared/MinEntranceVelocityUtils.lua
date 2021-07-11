---
-- @module MinEntranceVelocityUtils
-- @author Quenty, AxisAngle

local MinEntranceVelocityUtils = {}

local SQRT_2 = math.sqrt(2)

--- Determines the starting velocity to minimize the velocity at the target for a parabula
function MinEntranceVelocityUtils.minimizeEntranceVelocity(origin, target, accel)
	local offset = target - origin
	local accelDist = accel.magnitude
	local offsetDist = offset.magnitude

	local lowerTerm = math.sqrt(2 * accelDist * offsetDist)
	if lowerTerm == 0 then
		return Vector3.new(0, 0, 0)
	end

	return (accelDist*offset - accel*offsetDist) / lowerTerm
end

-- NOTE: This may only works for a minimizeEntranceVelocity
function MinEntranceVelocityUtils.computeEntranceVelocity(velocity, origin, target, accel)
	local entranceTime = MinEntranceVelocityUtils.computeEntranceTime(velocity, origin, target, accel)
	return accel*entranceTime + velocity
end

-- NOTE: This may only works for a minimizeEntranceVelocity
function MinEntranceVelocityUtils.computeEntranceTime(velocity, origin, target, accel)
	local offset = target - origin
	local aa = accel:Dot(accel)
	local av = accel:Dot(velocity)
	local vv = velocity:Dot(velocity)
	local vo = velocity:Dot(offset)
	local oo = offset:Dot(offset)

	local lowerTerm = aa*vv - av*av
	if lowerTerm == 0 then
		return 0 -- We're already there
	end

	return SQRT_2*((vv*oo - vo*vo)/lowerTerm)^0.25
end

return MinEntranceVelocityUtils