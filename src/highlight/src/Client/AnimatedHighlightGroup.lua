--[=[
	@class AnimatedHighlightGroup
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local AnimatedHighlight = require("AnimatedHighlight")
local Maid = require("Maid")
local ValueObject = require("ValueObject")
local EnumUtils = require("EnumUtils")
local Set = require("Set")

local AnimatedHighlightGroup = setmetatable({}, BaseObject)
AnimatedHighlightGroup.ClassName = "AnimatedHighlightGroup"
AnimatedHighlightGroup.__index = AnimatedHighlightGroup

function AnimatedHighlightGroup.new()
	local self = setmetatable(BaseObject.new(), AnimatedHighlightGroup)

	self._highlightDepthMode = ValueObject.new(Enum.HighlightDepthMode.AlwaysOnTop)
	self._maid:GiveTask(self._highlightDepthMode)

	self._defaultFillColor = ValueObject.new(Color3.new(1, 1, 1), "Color3")
	self._maid:GiveTask(self._defaultFillColor)

	self._defaultTransparencySpeed = ValueObject.new(40, "number")
	self._maid:GiveTask(self._defaultTransparencySpeed)

	self._defaultFillTransparency = ValueObject.new(0.5, "number")
	self._maid:GiveTask(self._defaultFillTransparency)

	self._defaultOutlineTransparency = ValueObject.new(0, "number")
	self._maid:GiveTask(self._defaultOutlineTransparency)

	self._defaultSpeed = ValueObject.new(20, "number")
	self._maid:GiveTask(self._defaultSpeed)

	self._defaultOutlineColor = ValueObject.new(Color3.new(1, 1, 1), "Color3")
	self._maid:GiveTask(self._defaultOutlineColor)

	self._highlights = {}

	return self
end

--[=[
	Sets the depth mode. Either can be:

	* Enum.HighlightDepthMode.AlwaysOnTop
	* Enum.HighlightDepthMode.Occluded

	@param depthMode Enum.HighlightDepthMode
]=]
function AnimatedHighlightGroup:SetDefaultHighlightDepthMode(depthMode)
	assert(EnumUtils.isOfType(Enum.HighlightDepthMode, depthMode))

	self._highlightDepthMode.Value = depthMode
end

function AnimatedHighlightGroup:SetDefaultFillTransparency(transparency)
	assert(type(transparency) == "number", "Bad transparency")

	self._defaultFillTransparency.Value = transparency
end

function AnimatedHighlightGroup:SetDefaultOutlineTransparency(outlineTransparency)
	assert(type(outlineTransparency) == "number", "Bad outlineTransparency")

	self._defaultOutlineTransparency.Value = outlineTransparency
end

function AnimatedHighlightGroup:SetDefaultFillColor(color)
	assert(typeof(color) == "Color3", "Bad color")

	self._defaultFillColor.Value = color
end

function AnimatedHighlightGroup:GetDefaultFillColor()
	return self._defaultFillColor.Value
end

function AnimatedHighlightGroup:SetDefaultOutlineColor(color)
	assert(typeof(color) == "Color3", "Bad color")

	self._defaultOutlineColor.Value = color
end

function AnimatedHighlightGroup:SetDefaultTransparencySpeed(speed)
	assert(type(speed) == "number", "Bad speed")

	self._defaultTransparencySpeed.Value = speed
end

function AnimatedHighlightGroup:SetDefaultSpeed(speed)
	assert(type(speed) == "number", "Bad speed")

	self._defaultSpeed.Value = speed
end

function AnimatedHighlightGroup:GetDefaultOutlineColor()
	return self._defaultOutlineColor.Value
end

function AnimatedHighlightGroup:Highlight(adornee, doNotAnimate)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local highlight = self:_getOrCreateHighlight(adornee)
	highlight:Show(doNotAnimate)
	return highlight
end

function AnimatedHighlightGroup:EraseAllBut(adorneeList, doNotAnimate)
	assert(type(adorneeList) == "table", "Bad adorneeList")

	local set = Set.fromList(adorneeList)

	for adornee, highlight in pairs(self._highlights) do
		if not set[adornee] then
			highlight:Hide(doNotAnimate)
		end
	end
end

function AnimatedHighlightGroup:EraseAll()
	for _, highlight in pairs(self._highlights) do
		highlight:Hide()
	end
end

function AnimatedHighlightGroup:FindHighlight(adornee)
	return self._highlights[adornee]
end

function AnimatedHighlightGroup:Erase(adornee)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	local highlight = self:FindHighlight(adornee)
	if highlight then
		highlight:Hide()
	end
end

function AnimatedHighlightGroup:ResetHighlightProperties(adornee, doNotAnimate)
	local highlight = self:FindHighlight(adornee)
	if highlight then
		self:_setDefaultValues(highlight, doNotAnimate)
	end
end

function AnimatedHighlightGroup:_setDefaultValues(highlight, doNotAnimate)
	highlight:SetHighlightDepthMode(self._highlightDepthMode.Value)
	highlight:SetTransparencySpeed(self._defaultTransparencySpeed.Value)
	highlight:SetSpeed(self._defaultSpeed.Value)

	highlight:SetFillTransparency(self._defaultFillTransparency.Value, doNotAnimate)
	highlight:SetOutlineTransparency(self._defaultOutlineTransparency.Value, doNotAnimate)
	highlight:SetFillColor(self._defaultFillColor.Value)
	highlight:SetOutlineColor(self._defaultOutlineColor.Value)
end

function AnimatedHighlightGroup:_getOrCreateHighlight(adornee)
	local foundHighlight = self._highlights[adornee]
	if foundHighlight then
		return foundHighlight
	end

	local maid = Maid.new()

	local highlight = AnimatedHighlight.new()
	self:_setDefaultValues(highlight, true)
	highlight:SetAdornee(adornee)
	maid:GiveTask(highlight)

	maid:GiveTask(highlight.Destroying:Connect(function()
		self:_removeHighlight(highlight)
	end))

	maid:GiveTask(highlight.VisibleChanged:Connect(function(isVisible, doNotAnimate)
		if not isVisible then
			highlight:Finish(doNotAnimate, function()
				self:_removeHighlight(highlight)
			end)
		end
	end))

	self._highlights[adornee] = highlight
	maid:GiveTask(function()
		if self._highlights[adornee] == highlight then
			self._highlights[adornee] = nil
		end
	end)

	self._maid[highlight] = maid

	return highlight
end

function AnimatedHighlightGroup:HighlightWithTransferredProperties(fromAdornee, toAdornee)
	assert(typeof(fromAdornee) == "Instance", "Bad fromAdornee")
	assert(typeof(toAdornee) == "Instance", "Bad toAdornee")

	local source = self._highlights[fromAdornee]
	if not source then
		return self:Highlight(toAdornee)
	end

	local target = self:Highlight(toAdornee)
	target:SetPropertiesFrom(source)
	return target
end

function AnimatedHighlightGroup:_removeHighlight(highlight)
	self._maid[highlight] = nil
end

function AnimatedHighlightGroup:_findHighlightAdornee(adornee)
	return self._highlights[adornee]
end

return AnimatedHighlightGroup