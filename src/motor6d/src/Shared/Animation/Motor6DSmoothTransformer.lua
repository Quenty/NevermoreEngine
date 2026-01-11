--!strict
--[=[
	@class Motor6DSmoothTransformer
]=]

local require = require(script.Parent.loader).load(script)

local Motor6DTransformer = require("Motor6DTransformer")
local Spring = require("Spring")
local SpringUtils = require("SpringUtils")

local Motor6DSmoothTransformer = setmetatable({}, Motor6DTransformer)
Motor6DSmoothTransformer.ClassName = "Motor6DSmoothTransformer"
Motor6DSmoothTransformer.__index = Motor6DSmoothTransformer

export type GetTransformFunction = (below: CFrame) -> CFrame?
export type Motor6DSmoothTransformer =
	typeof(setmetatable(
		{} :: {
			_getTransform: GetTransformFunction,
			_relativeTransformSpring: Spring.Spring<number>,
			_lastTransform: CFrame?,
		},
		{} :: typeof({ __index = Motor6DSmoothTransformer })
	))
	& Motor6DTransformer.Motor6DTransformer

function Motor6DSmoothTransformer.new(getTransform: GetTransformFunction): Motor6DSmoothTransformer
	local self: Motor6DSmoothTransformer = setmetatable(Motor6DTransformer.new() :: any, Motor6DSmoothTransformer)

	self._getTransform = assert(getTransform, "No getTransform")

	self._relativeTransformSpring = Spring.new(0)
	self._relativeTransformSpring.s = 25
	self._relativeTransformSpring.t = 0

	return self
end

function Motor6DSmoothTransformer.SetSpeed(self: Motor6DSmoothTransformer, speed: number)
	self._relativeTransformSpring.s = speed
end

function Motor6DSmoothTransformer.SetTarget(self: Motor6DSmoothTransformer, t: number)
	self._relativeTransformSpring.t = t
end

function Motor6DSmoothTransformer.Transform(
	self: Motor6DSmoothTransformer,
	getBelow: Motor6DTransformer.GetBelowFunction
): CFrame?
	local isAnimating, percent = SpringUtils.animating(self._relativeTransformSpring)

	local below = getBelow()
	local transform = self._getTransform(below)

	if transform then
		self._lastTransform = transform
	else
		transform = self._lastTransform
	end

	if not transform then
		return nil
	end

	local result = below:Lerp(transform, percent)
	if isAnimating or percent > 0 then
		return result
	else
		return nil
	end
end

return Motor6DSmoothTransformer
