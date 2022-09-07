--[=[
	@class DepthOfFieldModifier
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Signal = require("Signal")

local DepthOfFieldModifier = setmetatable({}, BaseObject)
DepthOfFieldModifier.ClassName = "DepthOfFieldModifier"
DepthOfFieldModifier.__index = DepthOfFieldModifier

function DepthOfFieldModifier.new(distance, radius, nearIntensity, farIntensity)
	local self = setmetatable(BaseObject.new(), DepthOfFieldModifier)

	assert(type(distance) == "number", "Bad distance")
	assert(type(radius) == "number", "Bad radius")
	assert(type(nearIntensity) == "number", "Bad nearIntensity")
	assert(type(farIntensity) == "number", "Bad farIntensity")

	self._originalDistance = distance
	self._originalRadius = radius
	self._originalNearIntensity = nearIntensity
	self._originalFarIntensity = farIntensity

	self._distance = distance
	self._radius = radius
	self._nearIntensity = nearIntensity
	self._farIntensity = farIntensity

--[=[
	Fires when the modifier is removing.
	@prop Removing Signal
	@within DepthOfFieldModifier
]=]
	self.Removing = Signal.new()
	self._maid:GiveTask(function()
		self.Removing:Fire()
		self.Removing:Destroy()
	end)

--[=[
	Fires when the distance changes.
	@prop DistanceChanged Signal
	@within DepthOfFieldModifier
]=]
	self.DistanceChanged = Signal.new()
	self._maid:GiveTask(self.DistanceChanged)

--[=[
	Fires when the radius changes.
	@prop RadiusChanged Signal
	@within DepthOfFieldModifier
]=]
	self.RadiusChanged = Signal.new()
	self._maid:GiveTask(self.RadiusChanged)

	self.NearIntensityChanged = Signal.new()
	self._maid:GiveTask(self.NearIntensityChanged)

	self.FarIntensityChanged = Signal.new()
	self._maid:GiveTask(self.FarIntensityChanged)

	return self
end

--[=[
	Sets the target depth of field distance
	@param distance number
	@param doNotAnimate boolean
]=]
function DepthOfFieldModifier:SetDistance(distance, doNotAnimate)
	assert(type(distance) == "number", "Bad distance")

	if self._distance == distance then
		return
	end

	self._distance = distance
	self.DistanceChanged:Fire(distance, doNotAnimate)
end

function DepthOfFieldModifier:GetOriginalDistance()
	return self._originalDistance
end

function DepthOfFieldModifier:GetOriginalRadius()
	return self._originalRadius
end
--[=[
	Sets the target depth of field distance
	@param radius number
	@param doNotAnimate boolean
]=]
function DepthOfFieldModifier:SetRadius(radius, doNotAnimate)
	assert(type(radius) == "number", "Bad radius")

	if self._radius == radius then
		return
	end

	self._radius = radius
	self.RadiusChanged:Fire(radius, doNotAnimate)
end

function DepthOfFieldModifier:SetNearIntensity(nearIntensity, doNotAnimate)
	assert(type(nearIntensity) == "number", "Bad nearIntensity")

	if self._nearIntensity == nearIntensity then
		return
	end

	self._nearIntensity = nearIntensity
	self.NearIntensityChanged:Fire(nearIntensity, doNotAnimate)
end

function DepthOfFieldModifier:SetFarIntensity(farIntensity, doNotAnimate)
	assert(type(farIntensity) == "number", "Bad farIntensity")

	if self._farIntensity == farIntensity then
		return
	end

	self._farIntensity = farIntensity
	self.FarIntensityChanged:Fire(farIntensity, doNotAnimate)
end

--[=[
	Retrieves the distance
	@return number
]=]
function DepthOfFieldModifier:GetDistance()
	return self._distance
end

--[=[
	Retrieves the radius
	@return number
]=]
function DepthOfFieldModifier:GetRadius()
	return self._radius
end

function DepthOfFieldModifier:GetNearIntensity()
	return self._nearIntensity
end

function DepthOfFieldModifier:GetFarIntensity()
	return self._farIntensity
end

--[=[
	Resets the radius
	@param doNotAnimate boolean
]=]
function DepthOfFieldModifier:Reset(doNotAnimate)
	self:SetDistance(self._originalDistance, doNotAnimate)
	self:SetRadius(self._originalRadius, doNotAnimate)
	self:SetNearIntensity(self._originalNearIntensity, doNotAnimate)
	self:SetFarIntensity(self._originalFarIntensity, doNotAnimate)
end

return DepthOfFieldModifier