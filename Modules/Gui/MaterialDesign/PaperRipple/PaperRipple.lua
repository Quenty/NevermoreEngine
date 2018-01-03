--- PaperRipple from material design, based off of Polymer's algorithms.
-- See: github.com/PolymerElements/paper-ripple/blob/master/paper-ripple.html
-- @classmod PaperRipple

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Ripple = require("Ripple")
local Maid = require("Maid")
local Table = require("Table")

local PaperRipple = {}
PaperRipple.__index = PaperRipple
PaperRipple.ClassName = "PaperRipple"
PaperRipple.InkColor = Color3.new(1, 1, 1)
PaperRipple.Recenter = false

--- Construct a new PaperRipple
-- @constructor
-- @param Container A container with ClipsDescendants=true
function PaperRipple.new(Container)

	assert(Container, "Needs Container")
	assert(Container.ClipsDescendants, "Container must clip descendants")

	local self = setmetatable({}, PaperRipple)

	self.InputMaid = Maid.new()
	self.Container = Container

	self._ripples = {}
	self._animating = false

	self:BindInput()

	return self
end

--- Creates a new container parented to the parent, with a sufficient construction.
-- @constructor
-- @param Parent A ROBLOX GUI parent, will make sure that the
--               PaperRipple actually renders under it. Note there is a small
--               restriction when it comes to rotation.
-- @return The new paper ripple.
function PaperRipple.FromParent(parent)
	assert(typeof(parent) == "Instance", "parent must be a Roblox object, type")

	local container = Instance.new("Frame")
	container.ClipsDescendants = true
	container.Archivable = false
	container.BorderSizePixel = 0
	container.BackgroundTransparency = 1
	container.BackgroundColor3 = PaperRipple.InkColor
	container.Name = "PaperRipple"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.ZIndex = math.min(parent.ZIndex + 1, 10)
	container.Parent = parent
	
	local ripple = PaperRipple.new(container)
	
	if parent:IsA("TextLabel") or parent:IsA("TextButton") then
		local _, s, v = Color3.toHSV(parent.BackgroundColor3)
		if v > 0.9 and s < 0.1 then
			ripple:SetInkColor(parent.TextColor3:lerp(Color3.new(1,1,1), 0.5))
		end
	end

	return ripple
end

--- Sets the ink color for the ripple and recolors all the things!
-- @param InkColor Color3, the ink color to set the ripple
function PaperRipple:SetInkColor(InkColor)
	
	self._inkColor = InkColor

	for _, ripple in pairs(self._ripples) do
		ripple:SetInkColor(self._inkColor)
	end
	self.Container.BackgroundColor3 = self._inkColor
	
	return self
end

--- Should the ripples recenter itself as stuff happens?
-- @param DoRecenter Boolean, if true, will recenter.
function PaperRipple:SetRecenter(DoRecenter)
	assert(type(DoRecenter) == "boolean", "DoRecenter must be a boolean. (kids these days).")

	self.Recenter = DoRecenter
end

--- Calculates the furthest corner from the position's distance
-- @param Position Vector2 world position on the GUI.
-- @return Number, the further distance from the corner.
function PaperRipple:FurthestCornerDistanceFrom(Position)
	local Container = self.Container
	
	local ContainerPosition = Container.AbsolutePosition
	local ContainerSize = Container.AbsoluteSize

	-- Magnitude distance of each position
	local TopLeft = (ContainerPosition - Position).magnitude
	local TopRight = (ContainerPosition + Vector2.new(ContainerSize.X, 0) - Position).magnitude
	local BottomLeft = (ContainerPosition + Vector2.new(0, ContainerSize.Y) - Position).magnitude
	local BottomRight = (ContainerPosition + ContainerSize - Position).magnitude

	-- Selection
	return math.max(TopLeft, TopRight, BottomLeft, BottomRight)
end

--- Releases each ripple for mouse down, so they expand all the way and fade.
function PaperRipple:ReleaseRipples()
	for _, ripple in pairs(self._ripples) do
		ripple:Up()
	end
end

--- Adds a new ripple to the processing list. Used internally.
--  Also calls :Down() and beings the animation
function PaperRipple:_addRipple(NewRipple)
	self._ripples[#self._ripples+1] = NewRipple or error("No ripple sent")

	NewRipple:Down()
	self:_beginAnimating()
end

--- Removes the ripple from the processing list. Used internally.
--  This removal also GCs the Ripple's GUI.s
--  @param Ripple An active ripple in the list to remove.
function PaperRipple:RemoveRipple(ripple)

	assert(ripple, "Must send ripple")

	local Index = Table.GetIndex(self._ripples, ripple) or error("ripple does not exist")
	ripple:Destroy()

	table.remove(self._ripples, Index)
end

--- Updates the animations on each of the ripples, GCing as needed
--  Called internally by the animation binding.
function PaperRipple:Draw()

	local Index = 1
	while Index <= #self._ripples do
		local IndexedRipple = self._ripples[Index]

		if IndexedRipple:IsAnimationComplete() then
			-- Remove completed ripples.

			self:RemoveRipple(IndexedRipple)
		else
			IndexedRipple:Draw()
			self.Container.BackgroundTransparency = IndexedRipple:GetOuterTransparency()
			Index = Index + 1 -- Only increment the ripple when we didn't remove a ripple.
		end
	end
end

--- Binding to render step requires a unique UID.
-- @return string The name being used to bind the ripple to RenderStep
function PaperRipple:GetBindName()
	return "PaperRipple" .. tostring(self)
end

--- Stops the animation of the paper ripple.
-- @pre There are no ripples in the array self._ripples.
function PaperRipple:_stopAnimating()

	assert(#self._ripples == 0, "There are still ripples to process.")

	if self._animating then
		RunService:UnbindFromRenderStep(self:GetBindName())
		self._animating = false
	end

	self.Container.BackgroundTransparency = 1
end

--- If not animating, begins the animation process of animating.
function PaperRipple:_beginAnimating()
	if not self._animating then
		self._animating = true

		RunService:BindToRenderStep(self:GetBindName(), 2000, function()
			self:Draw()

			if #self._ripples <= 0 or not self._animating then
				self:_stopAnimating()
			end
		end)
	end
end

--- Creates a new ripple for use in the Down function. Possible for this
--  to be overridden.
-- @param [Position] Vector2 position value world space. If not given, is set to center
-- @return The new ripple
function PaperRipple:_constructNewRipple(Position)
	Position = Position or (self.Container.AbsolutePosition + self.Container.AbsoluteSize/2)

	local Radius = self:FurthestCornerDistanceFrom(Position)

	local NewRipple = Ripple.FromPosition(self.Container, Position)
	NewRipple:SetInkColor(self._inkColor)
	NewRipple:SetTargetRadius(Radius)

	if self.Recenter then
		NewRipple:TargetCenter()
	end

	return NewRipple
end

--- Handles a new ripple. Public function. Also bound to input.
-- @param [Position] Vector2 position value world space.
-- @return The new ripple
function PaperRipple:Down(Position)
	self:ReleaseRipples() -- Release current ripples...
	local NewRipple = self:_constructNewRipple(Position)
	self:_addRipple(NewRipple)

	return NewRipple
end

--- Handles input being released, which is basically just releasing all the ripples.
function PaperRipple:Up()
	self:ReleaseRipples()
	self.InputMaid.InputEnded = nil
end

function PaperRipple:BindInput()
	--- Binds the input to the InputMaid to detect/handle Touch,
	--  and mouse button inputs over the GUI in question. Will override
	--  old bindings with the same names.

	local ValidInputEnums = {}
	for _, EnumName in pairs({"Touch", "MouseButton1", "MouseButton2", "MouseButton3"}) do
		ValidInputEnums[Enum.UserInputType[EnumName]] = true
	end

	-- The reason we bind twice here instead of using the InputChanged is because this
	-- event fires everytime a mouse moves over the InputMaid.

	-- Why do we track the DownTypes? Well, if we have a MouseButton2 down, and then a MouseButton1 down on
	-- another GUI, which then goes up, then we don't want to release the hold. However, if that MouseButton1 goes
	-- down on the same GUI (thus triggering a reflow of ink), we need that input type (or the other one, MouseButton2)
	-- to flow up and count. Furthermore, if we have a MouseDown on the GUI, and then the mouse slides off, we need to
	-- still have mouse up events track the flow, so we need to bind to the UserInputService to get this sort of data.

	local DownTypes = {}

	local function OnUp(InputObject)
		-- @param InputObject The input object to handle an up event. Will only
		--        consider a valid "up" if the type is already down.

		if DownTypes[InputObject.UserInputType] then
			self:Up()
			DownTypes = {} -- Clear state.
		end
	end

	self.InputMaid.InputBegan = self.Container.InputBegan:Connect(function(InputObject)
		if ValidInputEnums[InputObject.UserInputType] then
			local Position = Vector2.new(InputObject.Position.X, InputObject.Position.Y)
			self:Down(Position)

			DownTypes[InputObject.UserInputType] = true
			
			-- Bind to event.
			self.InputMaid.InputEnded = UserInputService.InputEnded:Connect(OnUp)
		end
	end)
end

--- Destroys the ripple, and it's container GUI for easy
--  GC on dynamically created stuff. Also disconnects all
--  events in the offchance that somehow we
--  didn't do that well either.
function PaperRipple:Destroy()
	while #self._ripples > 0 do
		self:RemoveRipple(self._ripples[1] or error("No ripple?"))
	end

	self:_stopAnimating()

	self.Container:Destroy()
	self.Container = nil

	self.InputMaid:DoCleaning()
	self.InputMaid = nil

	setmetatable(self, nil)
end

return PaperRipple
