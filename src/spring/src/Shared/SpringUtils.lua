--[=[
	Utility functions that are related to the Spring object
	@class SpringUtils
]=]

local EPSILON = 1e-6

local require = require(script.Parent.loader).load(script)
local LinearValue = require("LinearValue")

local SpringUtils = {}

--[=[
	Utility function that returns whether or not a spring is animating based upon
	velocity and closeness to target, and as the second value, the value that should be
	used.

	@param spring Spring<T>
	@param epsilon number? -- Optional epsilon
	@return boolean, T
]=]
function SpringUtils.animating(spring, epsilon)
	epsilon = epsilon or EPSILON

	local position = spring.Position
	local target = spring.Target

	local animating
	if type(target) == "number" then
		animating = math.abs(spring.Position - spring.Target) > epsilon
			or math.abs(spring.Velocity) > epsilon
	else
		local rbxtype = typeof(target)
		if rbxtype == "Vector3" or rbxtype == "Vector2" or LinearValue.isLinear(target) then
			animating = (spring.Position - spring.Target).magnitude > epsilon
				or spring.Velocity.magnitude > epsilon
		else
			error("Unknown type")
		end
	end

	if animating then
		return true, position
	else
		-- We need to return the target so we use the actual target value (i.e. pretend like the spring is asleep)
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
function SpringUtils.getVelocityAdjustment(velocity, dampen, speed)
	assert(velocity, "Bad velocity")
	assert(dampen, "Bad dampen")
	assert(speed, "Bad speed")

	return velocity*(2*dampen/speed)
end

local function convertUDim2(scaleX, offsetX, scaleY, offsetY)
	-- Roblox UDim2.new(0, 9.999, 0, 9.999) rounds to UDim2.new(0, 9, 0, 9) which means small floating point
	-- errors can cause shaking UI.

	return UDim2.new(scaleX, math.round(offsetX), scaleY, math.round(offsetY))
end

local function convertUDim(scale, offset)
	-- Roblox UDim.new(0, 9.999) rounds to UDim.new(0, 9) which means small floating point
	-- errors can cause shaking UI.

	return UDim.new(scale, math.round(offset))
end

--[=[
	Converts an arbitrary value to a LinearValue if Roblox has not defined this value
	for multiplication and addition.

	@param value T
	@return LinearValue<T> | T
]=]
function SpringUtils.toLinearIfNeeded(value)
	if typeof(value) == "Color3" then
		return LinearValue.new(Color3.new, {value.r, value.g, value.b})
	elseif typeof(value) == "UDim2" then
		return LinearValue.new(convertUDim2, {value.X.Scale, math.round(value.X.Offset), value.Y.Scale, math.round(value.Y.Offset)})
	elseif typeof(value) == "UDim" then
		return LinearValue.new(convertUDim, {value.Scale, math.round(value.Offset)})
	else
		return value
	end
end

--[=[
	Extracts the base value out of a packed linear value if needed.

	@param value LinearValue<T> | any
	@return T | any
]=]
function SpringUtils.fromLinearIfNeeded(value)
	if LinearValue.isLinear(value) then
		return value:ToBaseValue()
	else
		return value
	end
end

return SpringUtils
