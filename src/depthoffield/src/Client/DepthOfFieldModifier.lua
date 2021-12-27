--[=[
	@class DepthOfFieldModifier
]=]

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

--[=[
	Resets the radius
	@param doNotAnimate boolean
]=]
function DepthOfFieldModifier:Reset(doNotAnimate)
	self:SetDistance(self._originalDistance, doNotAnimate)
	self:SetRadius(self._originalRadius, doNotAnimate)
end

return DepthOfFieldModifier