--[=[
	@client
	@class AnimatedHighlightGroup
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local AnimatedHighlightStack = require("AnimatedHighlightStack")
local Maid = require("Maid")
local EnumUtils = require("EnumUtils")
local AnimatedHighlightModel = require("AnimatedHighlightModel")
local Rx = require("Rx")

local AnimatedHighlightGroup = setmetatable({}, BaseObject)
AnimatedHighlightGroup.ClassName = "AnimatedHighlightGroup"
AnimatedHighlightGroup.__index = AnimatedHighlightGroup

function AnimatedHighlightGroup.new()
	local self = setmetatable(BaseObject.new(), AnimatedHighlightGroup)

	self._defaultValues = self._maid:Add(AnimatedHighlightModel.new())
	self._defaultValues:SetHighlightDepthMode(Enum.HighlightDepthMode.AlwaysOnTop)
	self._defaultValues:SetFillColor(Color3.new(1, 1, 1))
	self._defaultValues:SetOutlineColor(Color3.new(1, 1, 1))
	self._defaultValues:SetTransparencySpeed(40)
	self._defaultValues:SetColorSpeed(40)
	self._defaultValues:SetOutlineTransparency(0)
	self._defaultValues:SetFillTransparency(0.5)
	self._defaultValues:SetSpeed(20)

	self._highlightStacks = {}

	return self
end

--[=[
	Sets the depth mode. Either can be:

	* Enum.HighlightDepthMode.AlwaysOnTop
	* Enum.HighlightDepthMode.Occluded

	@param depthMode Enum.HighlightDepthMode
]=]
function AnimatedHighlightGroup:SetDefaultHighlightDepthMode(depthMode: Enum.HighlightDepthMode)
	assert(EnumUtils.isOfType(Enum.HighlightDepthMode, depthMode))

	self._defaultValues:SetHighlightDepthMode(depthMode)
end

function AnimatedHighlightGroup:SetDefaultFillTransparency(transparency: number)
	assert(type(transparency) == "number", "Bad transparency")

	self._defaultValues:SetFillTransparency(transparency)
end

function AnimatedHighlightGroup:SetDefaultOutlineTransparency(outlineTransparency: number)
	assert(type(outlineTransparency) == "number", "Bad outlineTransparency")

	self._defaultValues:SetOutlineTransparency(outlineTransparency)
end

function AnimatedHighlightGroup:SetDefaultFillColor(color: Color3)
	assert(typeof(color) == "Color3", "Bad color")

	self._defaultValues:SetFillColor(color)
end

function AnimatedHighlightGroup:GetDefaultFillColor()
	return self._defaultValues:GetFillColor()
end

function AnimatedHighlightGroup:SetDefaultOutlineColor(color: Color3)
	assert(typeof(color) == "Color3", "Bad color")

	self._defaultValues:SetOutlineColor(color)
end

function AnimatedHighlightGroup:SetDefaultTransparencySpeed(speed: number)
	assert(type(speed) == "number", "Bad speed")

	self._defaultValues:SetTransparencySpeed(speed)
end

function AnimatedHighlightGroup:SetDefaultSpeed(speed: number)
	assert(type(speed) == "number", "Bad speed")

	self._defaultValues:SetSpeed(speed)
end

function AnimatedHighlightGroup:GetDefaultOutlineColor()
	return self._defaultValues:GetOutlineColor()
end

--[=[
	Returns an AnimatedHighlightModel which can be used to adjust the values

	@param adornee Instance
	@param observeScore number
	@return AnimatedHighlightModel
]=]
function AnimatedHighlightGroup:Highlight(adornee: Instance, observeScore)
	observeScore = observeScore or Rx.of(0)

	if type(observeScore) == "number" then
		observeScore = Rx.of(observeScore)
	end

	assert(typeof(adornee) == "Instance", "Bad adornee")
	assert(observeScore, "Bad observeScore")

	return self:_getOrCreateHighlightStackHandle(adornee, observeScore)
end

function AnimatedHighlightGroup:_setDefaultValues(highlight, doNotAnimate: boolean?)
	highlight:SetHighlightDepthMode(self._defaultValues.HighlightDepthMode.Value)
	highlight:SetTransparencySpeed(self._defaultValues.TransparencySpeed.Value)
	highlight:SetSpeed(self._defaultValues.Speed.Value)
	highlight:SetFillTransparency(self._defaultValues.FillTransparency.Value, doNotAnimate)
	highlight:SetOutlineTransparency(self._defaultValues.OutlineTransparency.Value, doNotAnimate)
	highlight:SetFillColor(self._defaultValues.FillColor.Value)
	highlight:SetOutlineColor(self._defaultValues.OutlineColor.Value)
end

function AnimatedHighlightGroup:_getOrCreateHighlightStackHandle(adornee, observeScore)
	assert(observeScore, "Bad observeScore")

	local foundHighlightStack = self._highlightStacks[adornee]
	if foundHighlightStack then
		return foundHighlightStack:GetHandle(observeScore)
	end

	local maid = Maid.new()

	local highlightStack = AnimatedHighlightStack.new(adornee, self._defaultValues)
	maid:GiveTask(highlightStack)

	maid:GiveTask(highlightStack.Destroying:Connect(function()
		self:_removeHighlightStack(highlightStack)
	end))

	local handle = highlightStack:GetHandle(observeScore)

	maid:GiveTask(highlightStack.Done:Connect(function()
		self:_removeHighlightStack(highlightStack)
	end))

	self._highlightStacks[adornee] = highlightStack
	maid:GiveTask(function()
		if self._highlightStacks[adornee] == highlightStack then
			self._highlightStacks[adornee] = nil
		end
	end)

	self._maid[highlightStack] = maid

	return handle
end

function AnimatedHighlightGroup:HighlightWithTransferredProperties(fromAdornee, toAdornee, observeScore)
	assert(typeof(fromAdornee) == "Instance", "Bad fromAdornee")
	assert(typeof(toAdornee) == "Instance", "Bad toAdornee")

	local source = self._highlightStacks[fromAdornee]
	if not source then
		return self:Highlight(toAdornee, observeScore)
	end

	local handle = self:Highlight(toAdornee, observeScore)
	local target = self._highlightStacks[toAdornee]
	if target then
		target:SetPropertiesFrom(source)
	else
		warn("Failed to find stack")
	end

	return handle
end

function AnimatedHighlightGroup:_removeHighlightStack(highlightStack)
	self._maid[highlightStack] = nil
end

function AnimatedHighlightGroup:_findHighlightAdornee(adornee)
	return self._highlightStacks[adornee]
end

return AnimatedHighlightGroup