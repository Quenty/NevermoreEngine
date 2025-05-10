--!strict
--[=[
	Utility functions that are related to the Spring object
	@class SpringUtils
]=]

local require = require(script.Parent.loader).load(script)

local LinearValue = require("LinearValue")
local Spring = require("Spring")

local SpringUtils = {}

local EPSILON = 1e-6

--[=[
	Utility function that returns whether or not a spring is animating based upon
	velocity and closeness to target, and as the second value, the value that should be
	used.

	@param spring Spring<T>
	@param epsilon number? -- Optional epsilon
	@return boolean, T
]=]
function SpringUtils.animating<T>(spring: Spring.Spring<T>, epsilon: number?): (boolean, T)
	local thisEpsilon = epsilon or EPSILON

	local position = spring.Position
	local target = spring.Target

	local animating
	if type(target) == "number" then
		animating = math.abs((spring :: any).Position - (spring :: any).Target) > thisEpsilon
			or math.abs((spring :: any).Velocity) > thisEpsilon
	else
		local rbxtype = typeof(target)
		if rbxtype == "Vector3" or rbxtype == "Vector2" or LinearValue.isLinear(target) then
			animating = ((spring :: any).Position - (spring :: any).Target).magnitude > thisEpsilon
				or (spring :: any).Velocity.magnitude > thisEpsilon
		else
			error("Unknown type")
		end
	end

	if animating then
		return true, position
	else
		-- We need to return the target so we use the actual target value (i.e. pretend like the (spring :: any) is asleep)
		return false, target
	end
end

--[=[
	Add to spring position to adjust for velocity of target. May have to set clock to time().

	@param velocity T
	@param dampen number
	@param speed number
	@return T
]=]
function SpringUtils.getVelocityAdjustment<T>(velocity: T, dampen: number, speed: number): T
	assert(velocity, "Bad velocity")
	assert(dampen, "Bad dampen")
	assert(speed, "Bad speed")

	return (velocity :: any) * (2 * dampen / speed)
end

--[=[
	Converts an arbitrary value to a LinearValue if Roblox has not defined this value
	for multiplication and addition.

	@param value T
	@return LinearValue<T> | T
]=]
function SpringUtils.toLinearIfNeeded<T>(value: T): LinearValue.LinearValue<T> | T
	return LinearValue.toLinearIfNeeded(value)
end

--[=[
	Extracts the base value out of a packed linear value if needed.

	@param value LinearValue<T> | any
	@return T | any
]=]
function SpringUtils.fromLinearIfNeeded<T>(value: LinearValue.LinearValue<T> | T): T
	return LinearValue.fromLinearIfNeeded(value)
end

return SpringUtils
