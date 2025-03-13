--!strict
--[=[
	Class of functions that can be used to minimize entrance velocity of a projectile.
	@class MinEntranceVelocityUtils
]=]

local MinEntranceVelocityUtils = {}

local SQRT_2 = math.sqrt(2)

--[=[
	Determines the starting velocity to minimize the velocity at the target for a parabula

	@param origin Vector3
	@param target Vector3
	@param accel Vector3
	@return Vector3
]=]
function MinEntranceVelocityUtils.minimizeEntranceVelocity(origin: Vector3, target: Vector3, accel: Vector3): Vector3
	local offset = target - origin
	local accelDist = accel.Magnitude
	local offsetDist = offset.Magnitude

	local lowerTerm = math.sqrt(2 * accelDist * offsetDist)
	if lowerTerm == 0 then
		return Vector3.zero
	end

	return (accelDist * offset - accel * offsetDist) / lowerTerm
end

--[=[
	Computes the velocity the target will enter the target

	:::note
	This may only works for a minimizeEntranceVelocity
	:::

	@param velocity Vector3
	@param origin Vector3
	@param target Vector3
	@param accel Vector3
	@return Vector3
]=]
function MinEntranceVelocityUtils.computeEntranceVelocity(
	velocity: Vector3,
	origin: Vector3,
	target: Vector3,
	accel: Vector3
): Vector3
	local entranceTime = MinEntranceVelocityUtils.computeEntranceTime(velocity, origin, target, accel)
	return accel * entranceTime + velocity
end

--[=[
	Computes the time stamp the project enters the target

	:::note
	This may only works for a minimizeEntranceVelocity
	:::

	@param velocity Vector3
	@param origin Vector3
	@param target Vector3
	@param accel Vector3
	@return number
]=]
function MinEntranceVelocityUtils.computeEntranceTime(
	velocity: Vector3,
	origin: Vector3,
	target: Vector3,
	accel: Vector3
): number
	local offset = target - origin
	local aa = accel:Dot(accel)
	local av = accel:Dot(velocity)
	local vv = velocity:Dot(velocity)
	local vo = velocity:Dot(offset)
	local oo = offset:Dot(offset)

	local lowerTerm = aa * vv - av * av
	if lowerTerm == 0 then
		return 0 -- We're already there
	end

	return SQRT_2 * ((vv * oo - vo * vo) / lowerTerm) ^ 0.25
end

return MinEntranceVelocityUtils
