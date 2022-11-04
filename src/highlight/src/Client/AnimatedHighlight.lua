--[=[
	@class AnimatedHighlight
]=]

local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local BasicPaneUtils = require("BasicPaneUtils")
local Blend = require("Blend")
local SpringObject = require("SpringObject")
local Math = require("Math")
local ValueObject = require("ValueObject")
local EnumUtils = require("EnumUtils")
local Maid = require("Maid")
local Signal = require("Signal")

local AnimatedHighlight = setmetatable({}, BasicPane)
AnimatedHighlight.ClassName = "AnimatedHighlight"
AnimatedHighlight.__index = AnimatedHighlight

function AnimatedHighlight.new()
	local self = setmetatable(BasicPane.new(), AnimatedHighlight)

	self._adornee = Instance.new("ObjectValue")
	self._adornee.Value = nil
	self._maid:GiveTask(self._adornee)

	self._highlightDepthMode = ValueObject.new(Enum.HighlightDepthMode.AlwaysOnTop)
	self._maid:GiveTask(self._highlightDepthMode)

	self._fillColor = Instance.new("Color3Value")
	self._fillColor.Value = Color3.new(1, 1, 1)
	self._maid:GiveTask(self._fillColor)

	self._outlineColor = Instance.new("Color3Value")
	self._outlineColor.Value = Color3.new(1, 1, 1)
	self._maid:GiveTask(self._outlineColor)

	self._fillTransparencySpring = SpringObject.new(0.5, 40)
	self._maid:GiveTask(self._fillTransparencySpring)

	self._outlineTransparencySpring = SpringObject.new(0, 40)
	self._maid:GiveTask(self._outlineTransparencySpring)

	self._percentVisible = SpringObject.new(BasicPaneUtils.observePercentVisible(self), 20)
	self._maid:GiveTask(self._percentVisible)

	self.Destroying = Signal.new()
	self._maid:GiveTask(function()
		self.Destroying:Fire()
		self.Destroying:Destroy()
	end)

	self._maid:GiveTask(self:_render():Subscribe(function(highlight)
		self.Gui = highlight
	end))

	return self
end

function AnimatedHighlight.isAnimatedHighlight(value)
	return type(value) == "table" and
		getmetatable(value) == AnimatedHighlight
end

--[=[
	Sets the depth mode. Either can be:

	* Enum.HighlightDepthMode.AlwaysOnTop
	* Enum.HighlightDepthMode.Occluded

	@param depthMode Enum.HighlightDepthMode
]=]
function AnimatedHighlight:SetHighlightDepthMode(depthMode)
	assert(EnumUtils.isOfType(Enum.HighlightDepthMode, depthMode))

	self._highlightDepthMode.Value = depthMode
end

function AnimatedHighlight:SetPropertiesFrom(sourceHighlight)
	assert(AnimatedHighlight.isAnimatedHighlight(sourceHighlight), "Bad AnimatedHighlight")

	self._highlightDepthMode.Value = sourceHighlight._highlightDepthMode.Value
	self._fillColor.Value = sourceHighlight._fillColor.Value
	self._outlineColor.Value = sourceHighlight._outlineColor.Value

	-- well, this can't be very fast...
	local function transferSpringValue(target, source)
		target.Speed = source.Speed
		target.Damper = source.Damper
		target.Target = source.Target
		target.Position = source.Position
		target.Velocity = source.Velocity
	end

	transferSpringValue(self._fillTransparencySpring, sourceHighlight._fillTransparencySpring)
	transferSpringValue(self._outlineTransparencySpring, sourceHighlight._outlineTransparencySpring)
	transferSpringValue(self._percentVisible, sourceHighlight._percentVisible)
end

function AnimatedHighlight:SetTransparencySpeed(speed)
	assert(type(speed) == "number", "Bad speed")

	self._fillTransparencySpring.Speed = speed
	self._outlineTransparencySpring.Speed = speed
end

function AnimatedHighlight:SetSpeed(speed)
	assert(type(speed) == "number", "Bad speed")

	self._percentVisible.Speed = speed
end

function AnimatedHighlight:Finish(doNotAnimate, callback)
	if self._percentVisible.p == 0 and self._percentVisible.v == 0 then
		callback()

		return
	end

	local maid = Maid.new()
	local done = false
	maid:GiveTask(self._percentVisible:ObserveRenderStepped():Subscribe(function(position)
		if position == 0 then
			done = true
			callback()
		end
	end))

	self:Hide(doNotAnimate)

	maid:GiveTask(function()
		self._maid[maid] = nil
	end)
	self._maid[maid] = maid

	if not done then
		maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
			if isVisible then
				-- cancel
				self._maid[maid]:DoCleaning()
			end
		end))
	end
end

function AnimatedHighlight:SetFillColor(color)
	assert(typeof(color) == "Color3", "Bad color")

	self._fillColor.Value = color
end

function AnimatedHighlight:SetOutlineColor(color)
	assert(typeof(color) == "Color3", "Bad color")

	self._outlineColor.Value = color
end

function AnimatedHighlight:SetAdornee(adornee)
	assert(typeof(adornee) == "Instance" or adornee == nil, "Bad adornee")

	self._adornee.Value = adornee
end

function AnimatedHighlight:GetAdornee()
	return self._adornee.Value
end

function AnimatedHighlight:SetOutlineTransparency(outlineTransparency, doNotAnimate)
	assert(type(outlineTransparency) == "number", "Bad outlineTransparency")

	self._outlineTransparencySpring.Target = outlineTransparency
	if doNotAnimate then
		self._outlineTransparencySpring.Position = outlineTransparency
		self._outlineTransparencySpring.Velocity = 0
	end
end

function AnimatedHighlight:SetFillTransparency(fillTransparency, doNotAnimate)
	assert(type(fillTransparency) == "number", "Bad fillTransparency")

	self._fillTransparencySpring.Target = fillTransparency
	if doNotAnimate then
		self._fillTransparencySpring.Position = fillTransparency
		self._fillTransparencySpring.Velocity = 0
	end
end

function AnimatedHighlight:_render()
	return Blend.New "Highlight" {
		Name = "AnimatedHighlight";
		Archivable = false;
		DepthMode = self._highlightDepthMode;
		FillColor = self._fillColor;
		OutlineColor = self._outlineColor;
		FillTransparency = Blend.Computed(
			self._fillTransparencySpring:ObserveRenderStepped(),
			self._percentVisible:ObserveRenderStepped(),
			function(transparency, visible)
				return Math.map(visible, 0, 1, 1, transparency);
			end);
		OutlineTransparency = Blend.Computed(
			self._outlineTransparencySpring:ObserveRenderStepped(),
			self._percentVisible:ObserveRenderStepped(),
			function(transparency, visible)
				return Math.map(visible, 0, 1, 1, transparency);
			end);
		Adornee = self._adornee;
		Parent = self._adornee;
	}
end

return AnimatedHighlight