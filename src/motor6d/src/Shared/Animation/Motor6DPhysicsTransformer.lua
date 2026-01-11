--!strict
--[=[
	@class Motor6DPhysicsTransformer
]=]

local require = require(script.Parent.loader).load(script)

local Motor6DTransformer = require("Motor6DTransformer")
local Spring = require("Spring")
local SpringUtils = require("SpringUtils")

local Motor6DPhysicsTransformer = setmetatable({}, Motor6DTransformer)
Motor6DPhysicsTransformer.ClassName = "Motor6DPhysicsTransformer"
Motor6DPhysicsTransformer.__index = Motor6DPhysicsTransformer

export type Motor6DPhysicsTransformer =
	typeof(setmetatable(
		{} :: {
			_physicsTransform: CFrame,
			_relativeTransformSpring: Spring.Spring<number>,
		},
		{} :: typeof({ __index = Motor6DPhysicsTransformer })
	))
	& Motor6DTransformer.Motor6DTransformer

--[=[
	Transforms from a physics state back to the Motor6D state over time.
]=]
function Motor6DPhysicsTransformer.new(physicsTransform: CFrame): Motor6DPhysicsTransformer
	local self: Motor6DPhysicsTransformer = setmetatable(Motor6DTransformer.new() :: any, Motor6DPhysicsTransformer)

	assert(typeof(physicsTransform) == "CFrame", "Bad physicsTransform")

	self._physicsTransform = physicsTransform

	self._relativeTransformSpring = Spring.new(0)
	self._relativeTransformSpring.s = 25
	self._relativeTransformSpring.t = 1

	return self
end

function Motor6DPhysicsTransformer.SetSpeed(self: Motor6DPhysicsTransformer, speed: number)
	self._relativeTransformSpring.s = speed
end

function Motor6DPhysicsTransformer.Transform(
	self: Motor6DPhysicsTransformer,
	getBelow: Motor6DTransformer.GetBelowFunction
): CFrame?
	local isAnimating, percent = SpringUtils.animating(self._relativeTransformSpring)

	local below = getBelow()

	local result = self._physicsTransform:Lerp(below, percent)
	if isAnimating then
		return result
	else
		self:FireFinished()
		return nil
	end
end

return Motor6DPhysicsTransformer
