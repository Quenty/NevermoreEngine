--!strict
--[=[
	@client
	@class AnimatedHighlight
]=]

local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local Blend = require("Blend")
local SpringObject = require("SpringObject")
local Math = require("Math")
local ValueObject = require("ValueObject")
local EnumUtils = require("EnumUtils")
local Maid = require("Maid")
local Signal = require("Signal")
local DuckTypeUtils = require("DuckTypeUtils")
local _Observable = require("Observable")

local AnimatedHighlight = setmetatable({}, BasicPane)
AnimatedHighlight.ClassName = "AnimatedHighlight"
AnimatedHighlight.__index = AnimatedHighlight

export type AnimatedHighlight = typeof(setmetatable(
	{} :: {
		-- Public
		Gui: Highlight,
		Destroying: Signal.Signal<()>,

		-- Private
		_adornee: ValueObject.ValueObject<Instance?>,
		_highlightDepthMode: ValueObject.ValueObject<Enum.HighlightDepthMode>,
		_fillColorSpring: SpringObject.SpringObject<Color3>,
		_outlineColorSpring: SpringObject.SpringObject<Color3>,
		_fillTransparencySpring: SpringObject.SpringObject<number>,
		_outlineTransparencySpring: SpringObject.SpringObject<number>,
		_percentVisible: SpringObject.SpringObject<number>,
	},
	{} :: typeof({ __index = AnimatedHighlight })
)) & BasicPane.BasicPane

function AnimatedHighlight.new(): AnimatedHighlight
	local self: AnimatedHighlight = setmetatable(BasicPane.new() :: any, AnimatedHighlight)

	self._adornee = self._maid:Add(ValueObject.new(nil))
	self._highlightDepthMode = self._maid:Add(ValueObject.new(Enum.HighlightDepthMode.AlwaysOnTop))
	self._fillColorSpring = self._maid:Add(SpringObject.new(Color3.new(1, 1, 1), 40))
	self._outlineColorSpring = self._maid:Add(SpringObject.new(Color3.new(1, 1, 1), 40))
	self._fillTransparencySpring = self._maid:Add(SpringObject.new(0.5, 40))
	self._outlineTransparencySpring = self._maid:Add(SpringObject.new(0, 40))
	self._percentVisible = self._maid:Add(SpringObject.new(0, 20))

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible, doNotAnimate)
		self._percentVisible.t = isVisible and 1 or 0
		if doNotAnimate then
			self._percentVisible.p = self._percentVisible.t
			self._percentVisible.v = 0
		end
	end))

	self.Destroying = Signal.new()
	self._maid:GiveTask(function()
		self.Destroying:Fire()
		self.Destroying:Destroy()
	end)

	self._maid:GiveTask(self:_render():Subscribe(function(highlight)
		self.Gui = highlight :: any
	end))

	return self
end

--[=[
	Returns true if it's an animated highlight

	@param value any
	@return boolean
]=]
function AnimatedHighlight.isAnimatedHighlight(value: any): boolean
	return DuckTypeUtils.isImplementation(AnimatedHighlight, value)
end

--[=[
	Sets the depth mode. Either can be:

	* Enum.HighlightDepthMode.AlwaysOnTop
	* Enum.HighlightDepthMode.Occluded

	@param depthMode Enum.HighlightDepthMode
]=]
function AnimatedHighlight.SetHighlightDepthMode(self: AnimatedHighlight, depthMode: Enum.HighlightDepthMode)
	assert(EnumUtils.isOfType(Enum.HighlightDepthMode, depthMode))

	self._highlightDepthMode.Value = depthMode
end

function AnimatedHighlight.SetPropertiesFrom(self: AnimatedHighlight, sourceHighlight: AnimatedHighlight)
	assert(AnimatedHighlight.isAnimatedHighlight(sourceHighlight), "Bad AnimatedHighlight")

	self._highlightDepthMode.Value = sourceHighlight._highlightDepthMode.Value

	-- well, this can't be very fast...
	local function transferSpringValue(target, source)
		target.Speed = source.Speed
		target.Damper = source.Damper
		target.Target = source.Target
		target.Position = source.Position
		target.Velocity = source.Velocity
	end

	-- Transfer state before we set spring values
	self:SetVisible(sourceHighlight:IsVisible(), true)

	transferSpringValue(self._fillColorSpring, sourceHighlight._fillColorSpring)
	transferSpringValue(self._outlineColorSpring, sourceHighlight._outlineColorSpring)
	transferSpringValue(self._fillTransparencySpring, sourceHighlight._fillTransparencySpring)
	transferSpringValue(self._outlineTransparencySpring, sourceHighlight._outlineTransparencySpring)
	transferSpringValue(self._percentVisible, sourceHighlight._percentVisible)
end

function AnimatedHighlight.SetTransparencySpeed(self: AnimatedHighlight, speed: number): ()
	assert(type(speed) == "number", "Bad speed")

	self._fillTransparencySpring.Speed = speed
	self._outlineTransparencySpring.Speed = speed
end

function AnimatedHighlight.SetColorSpeed(self: AnimatedHighlight, speed: number): ()
	assert(type(speed) == "number", "Bad speed")

	self._fillColorSpring.Speed = speed
	self._outlineColorSpring.Speed = speed
end

function AnimatedHighlight.SetSpeed(self: AnimatedHighlight, speed: number): ()
	assert(type(speed) == "number", "Bad speed")

	self._percentVisible.Speed = speed
end

function AnimatedHighlight.Finish(self: AnimatedHighlight, doNotAnimate: boolean?, callback: () -> ())
	if self._percentVisible.p == 0 and self._percentVisible.v == 0 then
		callback()
		return
	end

	local maid = Maid.new()
	local done = false

	self:Hide(doNotAnimate)

	maid:GiveTask(function()
		self._maid[maid] = nil
	end)
	self._maid[maid] = maid

	maid:GiveTask(self._percentVisible:ObserveRenderStepped():Subscribe(function(position)
		if position == 0 and not done then
			done = true
			callback()
		end
	end))

	if not done then
		maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
			if isVisible then
				-- cancel
				self._maid[maid] = nil
			end
		end))
	end
end

--[=[
	Sets the fill color

	@param color Color3
	@param doNotAnimate boolean?
]=]
function AnimatedHighlight.SetFillColor(self: AnimatedHighlight, color: Color3, doNotAnimate: boolean?): ()
	assert(typeof(color) == "Color3", "Bad color")

	self._fillColorSpring:SetTarget(color, doNotAnimate)
end

--[=[
	Sets the outline color

	@param color Color3
	@param doNotAnimate boolean?
]=]
function AnimatedHighlight.SetOutlineColor(self: AnimatedHighlight, color: Color3, doNotAnimate: boolean?): ()
	assert(typeof(color) == "Color3", "Bad color")

	self._outlineColorSpring:SetTarget(color, doNotAnimate)
end

--[=[
	Sets the adornee
]=]
function AnimatedHighlight.SetAdornee(self: AnimatedHighlight, adornee: Instance?)
	assert(typeof(adornee) == "Instance" or adornee == nil, "Bad adornee")

	self._adornee.Value = adornee
end

--[=[
	Gets the adornee
	@return Instance?
]=]
function AnimatedHighlight.GetAdornee(self: AnimatedHighlight): Instance?
	return self._adornee.Value
end

--[=[
	Sets the outlineTransparency

	@param outlineTransparency number
	@param doNotAnimate boolean?
]=]
function AnimatedHighlight.SetOutlineTransparency(
	self: AnimatedHighlight,
	outlineTransparency: number,
	doNotAnimate: boolean?
): ()
	assert(type(outlineTransparency) == "number", "Bad outlineTransparency")

	self._outlineTransparencySpring.Target = outlineTransparency
	if doNotAnimate then
		self._outlineTransparencySpring.Position = outlineTransparency
		self._outlineTransparencySpring.Velocity = 0
	end
end

--[=[
	Sets the fillTransparency

	@param fillTransparency number
	@param doNotAnimate boolean?
]=]
function AnimatedHighlight.SetFillTransparency(
	self: AnimatedHighlight,
	fillTransparency: number,
	doNotAnimate: boolean?
): ()
	assert(type(fillTransparency) == "number", "Bad fillTransparency")

	self._fillTransparencySpring.Target = fillTransparency
	if doNotAnimate then
		self._fillTransparencySpring.Position = fillTransparency
		self._fillTransparencySpring.Velocity = 0
	end
end

function AnimatedHighlight._render(self: AnimatedHighlight): _Observable.Observable<Highlight>
	return Blend.New("Highlight")({
		Name = "AnimatedHighlight",
		Archivable = false,
		DepthMode = self._highlightDepthMode,
		FillColor = self._fillColorSpring:ObserveRenderStepped(),
		OutlineColor = self._outlineColorSpring:ObserveRenderStepped(),
		FillTransparency = Blend.Computed(
			self._fillTransparencySpring:ObserveRenderStepped(),
			self._percentVisible:ObserveRenderStepped(),
			function(transparency, visible)
				return Math.map(visible, 0, 1, 1, transparency)
			end
		),
		OutlineTransparency = Blend.Computed(
			self._outlineTransparencySpring:ObserveRenderStepped(),
			self._percentVisible:ObserveRenderStepped(),
			function(transparency, visible)
				return Math.map(visible, 0, 1, 1, transparency)
			end
		),
		Adornee = self._adornee,
		Parent = self._adornee,
	}) :: any
end

return AnimatedHighlight