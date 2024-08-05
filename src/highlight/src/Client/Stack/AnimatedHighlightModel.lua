--[=[
	@class AnimatedHighlightModel
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ValueObject = require("ValueObject")
local EnumUtils = require("EnumUtils")
local Signal = require("Signal")
local DuckTypeUtils = require("DuckTypeUtils")

local AnimatedHighlightModel = setmetatable({}, BaseObject)
AnimatedHighlightModel.ClassName = "AnimatedHighlightModel"
AnimatedHighlightModel.__index = AnimatedHighlightModel

--[=[
	Constructs a new data model for an animated highlight. Probably retrieve via an
	[AnimatedHighlightStack] or more likely an [AnimatedHighlightGroup] or even the
	[HighlightServiceClient.Highlight].

	@return AnimatedHighlightModel
]=]
function AnimatedHighlightModel.new()
	local self = setmetatable(BaseObject.new(), AnimatedHighlightModel)

	self.HighlightDepthMode = self._maid:Add(ValueObject.new(nil))
	self.FillColor = self._maid:Add(ValueObject.new(nil))
	self.OutlineColor = self._maid:Add(ValueObject.new(nil))
	self.FillTransparency = self._maid:Add(ValueObject.new(nil))
	self.OutlineTransparency = self._maid:Add(ValueObject.new(nil))
	self.Speed = self._maid:Add(ValueObject.new(nil))
	self.ColorSpeed = self._maid:Add(ValueObject.new(nil))
	self.TransparencySpeed = self._maid:Add(ValueObject.new(nil))
	self.FillSpeed = self._maid:Add(ValueObject.new(nil))

	self.Destroying = Signal.new()
	self._maid:GiveTask(function()
		self.Destroying:Fire()
		self.Destroying:Destroy()
	end)

	return self
end

--[=[
	Returns true if it's an animated highlight model

	@param value any
	@return boolean
]=]
function AnimatedHighlightModel.isAnimatedHighlightModel(value)
	return DuckTypeUtils.isImplementation(AnimatedHighlightModel, value)
end

--[=[
	@param depthMode HighlightDepthMode
]=]
function AnimatedHighlightModel:SetHighlightDepthMode(depthMode)
	assert(EnumUtils.isOfType(Enum.HighlightDepthMode, depthMode) or depthMode == nil, "Bad depthMode")

	self.HighlightDepthMode.Value = depthMode
end

--[=[
	Sets the transparency speed

	@param speed number | nil
]=]
function AnimatedHighlightModel:SetTransparencySpeed(speed)
	assert(type(speed) == "number" or speed == nil, "Bad speed")

	self.TransparencySpeed:SetValue(speed)
end

--[=[
	Sets the color speed

	@param speed number | nil
]=]
function AnimatedHighlightModel:SetColorSpeed(speed)
	assert(type(speed) == "number" or speed == nil, "Bad speed")

	self.ColorSpeed:SetValue(speed)
end


--[=[
	Sets the visiblity speed speed

	@param speed number | nil
]=]
function AnimatedHighlightModel:SetSpeed(speed)
	assert(type(speed) == "number" or speed == nil, "Bad speed")

	self.Speed:SetValue(speed)
end

--[=[
	Sets fill color

	@param color Color3 | nil
	@param doNotAnimate boolean | nil
]=]
function AnimatedHighlightModel:SetFillColor(color, doNotAnimate)
	assert(typeof(color) == "Color3" or color == nil, "Bad color")

	self.FillColor:SetValue(color, doNotAnimate)
end

--[=[
	Gets the fill color

	@return Color3 | nil
]=]
function AnimatedHighlightModel:GetFillColor()
	return self.FillColor.Value
end

--[=[
	Sets the outline color

	@param color Color3 | nil
	@param doNotAnimate boolean | nil
]=]
function AnimatedHighlightModel:SetOutlineColor(color, doNotAnimate)
	assert(typeof(color) == "Color3" or color == nil, "Bad color")

	self.OutlineColor:SetValue(color, doNotAnimate)
end

--[=[
	Gets the outline color

	@return Color3 | nil
]=]
function AnimatedHighlightModel:GetOutlineColor()
	return self.OutlineColor.Value
end

--[=[
	Sets the outline transparency

	@param outlineTransparency number
	@param doNotAnimate boolean | nil
]=]
function AnimatedHighlightModel:SetOutlineTransparency(outlineTransparency, doNotAnimate)
	assert(type(outlineTransparency) == "number" or outlineTransparency == nil, "Bad outlineTransparency")

	self.OutlineTransparency:SetValue(outlineTransparency, doNotAnimate)
end

--[=[
	Sets the fill transparency

	@param fillTransparency number
	@param doNotAnimate boolean | nil
]=]
function AnimatedHighlightModel:SetFillTransparency(fillTransparency, doNotAnimate)
	assert(type(fillTransparency) == "number" or fillTransparency == nil, "Bad fillTransparency")

	self.FillTransparency:SetValue(fillTransparency, doNotAnimate)
end


return AnimatedHighlightModel