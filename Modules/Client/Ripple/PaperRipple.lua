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
PaperRipple._recenter = false

--- Construct a new PaperRipple
-- @constructor
-- @param container A container with ClipsDescendants=true
function PaperRipple.new(container)

	assert(container, "Needs container")
	assert(container.ClipsDescendants, "container must clip descendants")

	local self = setmetatable({}, PaperRipple)

	self._inputMaid = Maid.new()
	self._container = container

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
	self._container.BackgroundColor3 = self._inkColor

	return self
end

--- Should the ripples recenter itself as stuff happens?
-- @param doRecenter Boolean, if true, will recenter.
function PaperRipple:SetRecenter(doRecenter)
	assert(type(doRecenter) == "boolean", "doRecenter must be a boolean. (kids these days).")

	self._recenter = doRecenter
end

--- Calculates the furthest corner from the position's distance
-- @param position Vector2 world position on the GUI.
-- @return Number, the further distance from the corner.
function PaperRipple:FurthestCornerDistanceFrom(position)
	local container = self._container

	local ContainerPosition = container.AbsolutePosition
	local ContainerSize = container.AbsoluteSize

	-- Magnitude distance of each position
	local TopLeft = (ContainerPosition - position).Magnitude
	local TopRight = (ContainerPosition + Vector2.new(ContainerSize.X, 0) - position).Magnitude
	local BottomLeft = (ContainerPosition + Vector2.new(0, ContainerSize.Y) - position).Magnitude
	local BottomRight = (ContainerPosition + ContainerSize - position).Magnitude

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
function PaperRipple:_addRipple(newRipple)
	self._ripples[#self._ripples+1] = newRipple or error("No ripple sent")

	newRipple:Down()
	self:_beginAnimating()
end

--- Removes the ripple from the processing list. Used internally.
--  This removal also GCs the Ripple's GUI.s
--  @param Ripple An active ripple in the list to remove.
function PaperRipple:RemoveRipple(ripple)
	assert(ripple, "Must send ripple")

	local index = Table.GetIndex(self._ripples, ripple) or error("ripple does not exist")
	ripple:Destroy()

	table.remove(self._ripples, index)
end

--- Updates the animations on each of the ripples, GCing as needed
--  Called internally by the animation binding.
function PaperRipple:Draw()
	local index = 1
	while index <= #self._ripples do
		local indexedRipple = self._ripples[index]

		if indexedRipple:IsAnimationComplete() then
			-- Remove completed ripples.

			self:RemoveRipple(indexedRipple)
		else
			indexedRipple:Draw()
			self._container.BackgroundTransparency = indexedRipple:GetOuterTransparency()
			index = index + 1 -- Only increment the ripple when we didn't remove a ripple.
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

	self._container.BackgroundTransparency = 1
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
-- @param [position] Vector2 position value world space. If not given, is set to center
-- @return The new ripple
function PaperRipple:_constructNewRipple(position)
	position = position or (self._container.AbsolutePosition + self._container.AbsoluteSize/2)

	local newRipple = Ripple.FromPosition(self._container, position)
	newRipple:SetInkColor(self._inkColor)
	newRipple:SetTargetRadius(self:FurthestCornerDistanceFrom(position))

	if self._recenter then
		newRipple:TargetCenter()
	end

	return newRipple
end

--- Handles a new ripple. Public function. Also bound to input.
-- @param [position] Vector2 position value world space.
-- @return The new ripple
function PaperRipple:Down(position)
	self:ReleaseRipples() -- Release current ripples...
	local newRipple = self:_constructNewRipple(position)
	self:_addRipple(newRipple)

	return newRipple
end

--- Handles input being released, which is basically just releasing all the ripples.
function PaperRipple:Up()
	self:ReleaseRipples()
	self._inputMaid.InputEnded = nil
end

function PaperRipple:BindInput()
	--- Binds the input to the InputMaid to detect/handle Touch,
	--  and mouse button inputs over the GUI in question. Will override
	--  old bindings with the same names.

	local validInputEnums = {}
	for _, enumName in pairs({"Touch", "MouseButton1", "MouseButton2", "MouseButton3"}) do
		validInputEnums[Enum.UserInputType[enumName]] = true
	end

	-- The reason we bind twice here instead of using the InputChanged is because this
	-- event fires everytime a mouse moves over the InputMaid.

	-- Why do we track the downTypes? Well, if we have a MouseButton2 down, and then a MouseButton1 down on
	-- another GUI, which then goes up, then we don't want to release the hold. However, if that MouseButton1 goes
	-- down on the same GUI (thus triggering a reflow of ink), we need that input type (or the other one, MouseButton2)
	-- to flow up and count. Furthermore, if we have a MouseDown on the GUI, and then the mouse slides off, we need to
	-- still have mouse up events track the flow, so we need to bind to the UserInputService to get this sort of data.

	local downTypes = {}

	-- @param inputObject The input object to handle an up event. Will only
	--        consider a valid "up" if the type is already down.
	local function OnUp(inputObject)

		if downTypes[inputObject.UserInputType] then
			self:Up()
			downTypes = {} -- Clear state.
		end
	end

	self._inputMaid.InputBegan = self._container.InputBegan:Connect(function(inputObject)
		if validInputEnums[inputObject.UserInputType] then
			local position = Vector2.new(inputObject.Position.X, inputObject.Position.Y)
			self:Down(position)

			downTypes[inputObject.UserInputType] = true

			-- Bind to event.
			self._inputMaid.InputEnded = UserInputService.InputEnded:Connect(OnUp)
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

	self._container:Destroy()
	self._container = nil

	self._inputMaid:DoCleaning()
	self._inputMaid = nil

	setmetatable(self, nil)
end

return PaperRipple
