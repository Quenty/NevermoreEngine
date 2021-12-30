--[=[
	Tweens DepthOfField. Prefer to use [DepthOfFieldService].
	@class DepthOfFieldTweener
]=]

local require = require(script.Parent.loader).load(script)

local AccelTween = require("AccelTween")
local BaseObject = require("BaseObject")
local StepUtils = require("StepUtils")

local DEFAULT_SPEED = 10000

local DepthOfFieldTweener = setmetatable({}, BaseObject)
DepthOfFieldTweener.ClassName = "DepthOfFieldTweener"
DepthOfFieldTweener.__index = DepthOfFieldTweener

--[=[
	Create a new DepthOfFieldTweener.
	@param depthOfField number
	@param speed number?
	@return DepthOfFieldTweener
]=]
function DepthOfFieldTweener.new(depthOfField, speed)
	local self = setmetatable(BaseObject.new(), DepthOfFieldTweener)

	self._depthOfField = assert(depthOfField, "No depthOfField")

	-- If we aren't enabled we make sure to set distance to be far
	self._originalDistance = self._depthOfField.Enabled and self._depthOfField.FocusDistance or 500
	self._originalRadius = self._depthOfField.Enabled and self._depthOfField.InFocusRadius or 500

	self._distance = AccelTween.new(speed or DEFAULT_SPEED)
	self._distance.t = self._originalDistance
	self._distance.p = self._originalDistance

	self._radius = AccelTween.new(speed or DEFAULT_SPEED)
	self._radius.t = self._originalRadius
	self._radius.p = self._originalRadius

	self._maid:GiveTask(function()
		self._depthOfField.FocusDistance = self._originalDistance
		self._depthOfField.InFocusRadius = self._originalRadius
	end)

	self._startAnimation, self._maid._stop = StepUtils.bindToRenderStep(self._update)
	self:_startAnimation()

	return self
end

--[=[
	Sets the radius and starts any animation
	@param radius number
	@param doNotAnimate boolean
]=]
function DepthOfFieldTweener:SetRadius(radius, doNotAnimate)
	local target = math.clamp(radius, 0, 500)
	self._radius.t = target
	if doNotAnimate then
		self._radius.p = target
		self._radius.v = 0
	end

	self:_startAnimation()
end

--[=[
	Gets the current radius being rendered
	@return number
]=]
function DepthOfFieldTweener:GetRadius()
	return self._radius.p
end

--[=[
	Gets the current distance being set
	@return number
]=]
function DepthOfFieldTweener:GetDistance()
	return self._distance.p
end

--[=[
	Sets the distance to render
	@param distance number
	@param doNotAnimate boolean
]=]
function DepthOfFieldTweener:SetDistance(distance, doNotAnimate)
	local target = math.clamp(distance, 0, 500)
	self._distance.t = target
	if doNotAnimate then
		self._distance.p = target
		self._distance.v = 0
	end

	self:_startAnimation()
end

--[=[
	Resets the depth of field to the original distance
	@param doNotAnimate boolean
]=]
function DepthOfFieldTweener:Reset(doNotAnimate)
	self:ResetRadius(doNotAnimate)
	self:ResetDistance(doNotAnimate)
end

--[=[
	Resets the radius
	@param doNotAnimate boolean
]=]
function DepthOfFieldTweener:ResetRadius(doNotAnimate)
	self:SetRadius(self._originalDistance, doNotAnimate)
	self:_startAnimation()
end

--[=[
	Resets the distance
	@param doNotAnimate boolean
]=]
function DepthOfFieldTweener:ResetDistance(doNotAnimate)
	self:SetDistance(self._originalDistance, doNotAnimate)
	self:_startAnimation()
end

function DepthOfFieldTweener:GetOriginalRadius()
	return self._originalRadius
end

function DepthOfFieldTweener:GetOriginalDistance()
	return self._originalDistance
end

function DepthOfFieldTweener:_update()
	self._depthOfField.FocusDistance = self._distance.p
	self._depthOfField.InFocusRadius = self._radius.p

	return self._radius.rtime > 0
		or self._distance.rtime > 0
end

return DepthOfFieldTweener