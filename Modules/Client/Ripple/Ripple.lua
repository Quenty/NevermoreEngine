-- A Ripple animation to be used as part of PaperRipple.
-- Based off of Polymer's design and Google material design, designed for ROBLOX GUIs
-- See: github.com/PolymerElements/paper-ripple/blob/master/paper-ripple.html
-- @classmod Ripple

local Ripple = {}
Ripple.__index = Ripple
Ripple.ClassName = "Ripple"
Ripple.MaxRadius = 150 -- Absolute maximum
Ripple.TransparencyDecayVelocity = 0.8

--- Creates a new ripple, a wave of sort that expands to its target position and then decays
--  past that on a secondary event.
-- @param Gui An ImageLabel or ImageButton
function Ripple.new(Gui)
	assert(Gui and (Gui:IsA("ImageLabel") or Gui:IsA("ImageButton")), "GUI must be an ImageLabel or ImageButton")

	local self = setmetatable({}, Ripple)

	self.Gui = Gui
	self._container = self.Gui.Parent or error("No container")

	self.InitialPosition = self._container.AbsoluteSize / 2
	self.TargetPosition = self.InitialPosition

	self.InitialTransparency = Gui.ImageTransparency
	self.TargetRadius = self._container.AbsoluteSize.Magnitude

	-- NOTE: In order to begin, one should call ":Down()"
	self:Draw()

	return self
end

--- Creates a new "default" ripple
-- @param Parent A ROBLOX GUI to parent the ripple to.
function Ripple.NewDefault(Parent)
	assert(Parent, "Must send parent")

	local Circle = Instance.new("ImageLabel")
	Circle.Image = "rbxassetid://633244888"
	Circle.Name = "Circle"
	Circle.ImageTransparency = 0.75
	Circle.BackgroundTransparency = 1
	Circle.BorderSizePixel = 0
	Circle.Archivable = false
	Circle.ZIndex = math.min(Parent.ZIndex + 1, 10)
	Circle.ImageColor3 = Color3.new(1, 1, 1)
	Circle.Parent = Parent or error("Must send parent")

	local NewRipple = Ripple.new(Circle)

	return NewRipple
end

--- Creates a ripple from at a worldspace position
-- @param Parent A ROBLOX GUI to parent the ripple to.
-- @param Position Vector2 world space (2D) vector.
function Ripple.FromPosition(Parent, Position)
	assert(Parent, "Must send parent")
	assert(Position, "Must send Position")

	local NewRipple = Ripple.NewDefault(Parent)

	local RelativePosition = Position - NewRipple:GetContainer().AbsolutePosition
	NewRipple:SetInitialPosition(RelativePosition)
	NewRipple:SetTargetPosition(RelativePosition)

	return NewRipple
end

--- Sets the initial position of the ripple.
-- @param Position Vector2, relative local space position in offset.
function Ripple:SetInitialPosition(Position)
	self.InitialPosition = Position or error("InitialPosition")
end

--- Sets the target position of the ripple.
-- @param Position Vector2, relative local space in offset to target.s
function Ripple:SetTargetPosition(Position)
	self.TargetPosition = Position or error("InitialPosition")
end

--- Makes the ripple target the center of the container.
function Ripple:TargetCenter()
	self:SetTargetPosition(self._container.AbsoluteSize / 2)
end

--- Returns the container of the ripple.
-- @return The GUI container of the ripple.
function Ripple:GetContainer()
	return self._container
end

--- Sets the ink color (of the ripple). Assuming the image is white w/ 0 alpha to get best results
-- @param Color A Color3 to set the ink to.
function Ripple:SetInkColor(Color)
	self.Gui.ImageColor3 = Color or error("No InkColor. This is the deepest betrayal. How dare you.")
end

--- Sets the target radius. If TargetRadius is greater than MaxRadius, it may not fill out all the way
-- (up to max radius)
-- @param Radius Number, the radius to target. Shouldn't change after animating.
function Ripple:SetTargetRadius(Radius)

	assert(type(Radius) == "number", "Radius must be a number")
	assert(Radius > 5, "Radius failed sanity check")

	self.TargetRadius = Radius
end

---
-- @return The time elapsed since the mouse was up. 0 if it hasn't gone up yet.
function Ripple:GetMouseUpElapsed()
	return self.MouseUpStart and (tick() - self.MouseUpStart) or 0
end

---
-- @return The time (in seconds) elapsed since the mouse went down. 0 if it hasn't gone down.
function Ripple:GetMouseDownElapsed()
	local Elapsed

	if not self.MouseDownStart then
		return 0
	end

	Elapsed = tick() - self.MouseDownStart

	if self.MouseUpStart then
		Elapsed = Elapsed - self:GetMouseUpElapsed()
	end

	return Elapsed
end

function Ripple:GetMouseInteractionElapsed()
	return self:GetMouseDownElapsed() + self:GetMouseUpElapsed()
end

--- Components usually have an outer transparency set (darkening) too.
-- This is a linear background transparency capped at the wave front
function Ripple:GetOuterTransparency()
	local OuterTransparency = 1 - (self:GetMouseUpElapsed() * 0.3)
	local WaveTransparency = self:GetTransparency()

	return math.min(
		1,
		OuterTransparency,
		WaveTransparency -- WaveTransparency is consistently 0.75 for start, OuterTransparency is not. We want to use that.
	)
end

---
-- @return The transparency of the ripple.
function Ripple:GetTransparency()

	if not self.MouseUpStart then
		return self.InitialTransparency
	else
		-- Inversed from the Polymer version because the opacity vs. transparency deal.
		return math.min(
			1,
			self.InitialTransparency + self:GetMouseUpElapsed() * self.TransparencyDecayVelocity
		)
	end
end

--- Does some fancy formula to calculate radius based on time elapsed.s. <3
-- @return Radius based on mouse interaction time
-- see: github.com/PolymerElements/paper-ripple/blob/master/paper-ripple.html#L263
function Ripple:GetRadius()
	local WaveRadius = math.min(
		self.TargetRadius,
		self.MaxRadius
	) * 1.1 + 3 -- Normally adds + 5, in this case, ROBLOX is 1/2 the pixel size, add 3 as the closest whole number.

	-- Formula from PaperRipple on Polymer's project
	local Duration = 1.1 - 0.2 * (WaveRadius / Ripple.MaxRadius)
	local PercentElapsed = self:GetMouseInteractionElapsed() / Duration
	local Size = WaveRadius * (1 - 80^(-PercentElapsed))

	return math.abs(Size)
end

--- Returns whether the transparency has completely decayed. This does
-- not count if the ripple has not started, thus, we also check
-- the radius.
-- @return Boolean, true if the transparency is completely decayed.
function Ripple:IsTransparencyDecayed()
	return self:GetTransparency() >= 1 and
		self:GetRadius() >= math.min(self.MaxRadius, self.TargetRadius)
end

--- Calculates how far along we've translated the animation
--  @return Number [0, 1] of how far along we've translated.
function Ripple:GetTranslationFraction()
	return math.min(
		1,
		self:GetRadius() / self:GetLargestContainerSize() * 2 / math.sqrt(2)
	)
end

--- Not sure on the logic here, trusting it works. Basically, to be done,
-- we need to have the mouse up, and the transparency decayed.
function Ripple:IsAnimationComplete()
	return self.MouseUpStart and self:IsTransparencyDecayed() --or self:IsRestingAtMaxRadius()
end

function Ripple:Down()
	self.MouseDownStart = tick()
end

--- Determines the larger of two container sizes
-- @return Number, the larger size.
function Ripple:GetLargestContainerSize()
	local container = self._container
	return math.max(container.AbsoluteSize.X, container.AbsoluteSize.Y)
end

--- Updates the ripple draw state.
function Ripple:Draw()

	local Gui = self.Gui

	Gui.ImageTransparency = self:GetTransparency()

	local Radius = math.floor(self:GetRadius()) -- Floor keeps the GUI from jiggling as ROBLOX rounds the position.
	-- local ContainerLargerSize = self:GetLargestContainerSize()
	-- local Scale  = Radius / (ContainerLargerSize / 2)

	Gui.Size = UDim2.new(0, Radius*2, 0, Radius*2)

	local Offset = self.TargetPosition - self.InitialPosition
	local Position = self.InitialPosition + Offset * self:GetTranslationFraction()
	local RadiusOffset = Vector2.new(Radius, Radius)
	local RenderPosition = Position - RadiusOffset

	Gui.Position = UDim2.new(0, RenderPosition.X, 0, RenderPosition.Y)
end

-- Releases the ripple. May be callled multiple times, but will only perform
-- once.
function Ripple:Up()
	if not self.MouseUpStart then
		self.MouseUpStart = tick()
	end
end

--- GCs the GUI
function Ripple:Destroy()
	setmetatable(self, nil)

	self.Gui:Destroy()
	self.Gui = nil
end

return Ripple
