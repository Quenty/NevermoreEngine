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

function Motor6DSmoothTransformer.new(getTransform)
	local self = setmetatable(Motor6DTransformer.new(), Motor6DSmoothTransformer)

	self._getTransform = assert(getTransform, "No getTransform")

	self._relativeTransformSpring = Spring.new(0)
	self._relativeTransformSpring.s = 25
	self._relativeTransformSpring.t = 0

	return self
end

function Motor6DSmoothTransformer:SetSpeed(speed)
	self._relativeTransformSpring.s = speed
end

function Motor6DSmoothTransformer:SetTarget(t)
	self._relativeTransformSpring.t = t
end

function Motor6DSmoothTransformer:Transform(getBelow)
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
