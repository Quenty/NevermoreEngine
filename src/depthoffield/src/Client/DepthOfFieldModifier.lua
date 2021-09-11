---
-- @classmod DepthOfFieldModifier
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Signal = require("Signal")

local DepthOfFieldModifier = setmetatable({}, BaseObject)
DepthOfFieldModifier.ClassName = "DepthOfFieldModifier"
DepthOfFieldModifier.__index = DepthOfFieldModifier

function DepthOfFieldModifier.new(distance, radius)
	local self = setmetatable(BaseObject.new(), DepthOfFieldModifier)

	self._originalDistance = distance
	self._originalRadius = radius

	self._distance = distance
	self._radius = radius

	self.Removing = Signal.new()
	self._maid:GiveTask(function()
		self.Removing:Fire()
		self.Removing:Destroy()
	end)

	self.DistanceChanged = Signal.new()
	self._maid:GiveTask(self.DistanceChanged)

	self.RadiusChanged = Signal.new()
	self._maid:GiveTask(self.RadiusChanged)

	return self
end

function DepthOfFieldModifier:SetDistance(distance, doNotAnimate)
	assert(type(distance) == "number", "Bad distance")

	if self._distance == distance then
		return
	end

	self._distance = distance
	self.DistanceChanged:Fire(distance, doNotAnimate)
end

function DepthOfFieldModifier:SetRadius(radius, doNotAnimate)
	assert(type(radius) == "number", "Bad radius")

	if self._radius == radius then
		return
	end

	self._radius = radius
	self.RadiusChanged:Fire(radius, doNotAnimate)
end

function DepthOfFieldModifier:GetDistance()
	return self._distance
end

function DepthOfFieldModifier:GetRadius()
	return self._radius
end

function DepthOfFieldModifier:Reset(doNotAnimate)
	self:SetDistance(self._originalDistance, doNotAnimate)
	self:SetRadius(self._originalRadius, doNotAnimate)
end

return DepthOfFieldModifier