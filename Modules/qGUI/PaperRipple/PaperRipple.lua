local UserInputService   = game:GetService("UserInputService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")

local NevermoreEngine    = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary  = NevermoreEngine.LoadLibrary

local Ripple   = LoadCustomLibrary("Ripple")
local qSystems = LoadCustomLibrary("qSystems")
local MakeMaid = LoadCustomLibrary("Maid").MakeMaid

local GetIndexByValue = qSystems.GetIndexByValue

--- Paper ripple from material design, based off of Polymer's algorithms.
-- https://github.com/PolymerElements/paper-ripple/blob/master/paper-ripple.html
-- @author Quenty

local PaperRipple = {}
PaperRipple.__index = PaperRipple
PaperRipple.ClassName = "PaperRipple"
PaperRipple.InkColor = Color3.new(1, 1, 1)
PaperRipple.Recenter = false

function PaperRipple.new(Container)
	-- @param Container A container that clips descendants to parent
	assert(Container.ClipsDescendants, "Container must clip descendants")

	local self = setmetatable({}, PaperRipple)

	-- COMPOSITE
	self.InputMaid = MakeMaid()
	self.Container = Container

	-- PRIVATE
	self.Ripples = {}
	self.Animating = false

	self:BindInput()

	return self
end

function PaperRipple.FromParent(Parent)
	--- Creates a new container parented to the parent, with a sufficient
	--  construction.
	-- @param Parent A ROBLOX GUI parent, will make sure that the
	--               PaperRipple actually renders under it. Note there is a small 
	--               restriction when it comes to rotation.
	-- @return The new paper ripple.

	assert(Parent, "Must send Parent GUI")

	local Container                  = Instance.new("Frame")
	Container.ClipsDescendants       = true;
	Container.Archivable             = false;
	Container.BorderSizePixel        = 0;
	Container.BackgroundTransparency = 1;
	Container.BackgroundColor3       = PaperRipple.InkColor
	Container.Name                   = "PaperRipple";
	Container.Size                   = UDim2.new(1, 0, 1, 0);
	Container.ZIndex                 = math.min(Parent.ZIndex + 1, 10)
	Container.Parent                 = Parent

	return PaperRipple.new(Container)
end

function PaperRipple:SetInkColor(InkColor)
	--- Sets the ink color for the ripple and recolors all the things!
	-- @param InkColor Color3, the ink color to set the ripple
	
	self.InkColor = InkColor

	for _, Item in pairs(self.Ripples) do
		Item:SetInkColor(self.InkColor)
	end
	self.Container.BackgroundColor3 = self.InkColor
end

function PaperRipple:SetRecenter(DoRecenter)
	--- Should the ripples recenter itself as stuff happens? 
	-- @param DoRecenter Boolean, if true, will recenter.

	assert(type(DoRecenter) == "boolean", "DoRecenter must be a boolean. (kids these days).")

	self.Recenter = DoRecenter
end

function PaperRipple:FurthestCornerDistanceFrom(Position)
	-- @param Position Vector2 world position on the GUI.
	-- @return Number, the further distance from the corner.
	
	local Container = self.Container
	
	local ContainerPosition = Container.AbsolutePosition
	local ContainerSize = Container.AbsoluteSize 

	-- Magnitude distance of each position
	local TopLeft = (ContainerPosition - Position).magnitude
	local TopRight = (ContainerPosition + Vector2.new(0, ContainerSize.X) - Position).magnitude
	local BottomLeft = (ContainerPosition + Vector2.new(ContainerSize.Y, 0) - Position).magnitude
	local BottomRight = (ContainerPosition + ContainerSize - Position).magnitude

	-- Selection
	return math.max(TopLeft, TopRight, BottomLeft, BottomRight)
end

function PaperRipple:ReleaseRipples()
	--- Releases each ripple for mouse down, so they expand all the way and fade.

	for _, Ripple in pairs(self.Ripples) do
		Ripple:Up()
	end
end

function PaperRipple:AddRipple(NewRipple)
	--- Adds a new ripple to the processing list. Used internally.
	--  Also calls :Down() to begin animation.

	self.Ripples[#self.Ripples+1] = NewRipple or error("No ripple sent")

	NewRipple:Down()
	self:BeginAnimating()
end

function PaperRipple:RemoveRipple(Ripple)
	--- Removes the ripple from the processing list. Used internally.
	--  This removal also GCs the Ripple's GUI.s
	--  @param Ripple An active ripple in the list to remove. 

	assert(Ripple, "Must send ripple")

	local Index = GetIndexByValue(self.Ripples, Ripple) or error("Ripple does not exist")
	Ripple:Destroy()

	table.remove(self.Ripples, Index)
end



-- ANIMATION BINDING
function PaperRipple:Draw()
	--- Updates the animations on each of the ripples, GCing as needed
	--  Called internally by the animation binding.

	local Index = 1
	while Index <= #self.Ripples do
		local IndexedRipple = self.Ripples[Index]

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

function PaperRipple:GetBindName()
	--- Binding to render step requires a unique UID.
	-- @return String The name being used to bind the ripple to RenderStep

	return "PaperRipple" .. tostring(self)
end

function PaperRipple:StopAnimating()
	--- Private, stops the animation of the paper ripple.
	-- @pre There are no ripples in the array self.Ripples.

	assert(#self.Ripples == 0, "There are still ripples to process.")

	if self.Animating then
		RunService:UnbindFromRenderStep(self:GetBindName())
		self.Animating = false
	end

	self.Container.BackgroundTransparency = 1
end

function PaperRipple:BeginAnimating()
	--- If not animating, begins the animation process of animating.

	if not self.Animating then
		self.Animating = true

		RunService:BindToRenderStep(self:GetBindName(), 2000, function()
			self:Draw()

			if #self.Ripples <= 0 or not self.Animating then
				self:StopAnimating()
			end
		end)
	end
end




-- INPUT BINDING
function PaperRipple:ConstructNewRipple(Position)
	--- Creates a new ripple for use in the Down function. Possible for this
	--  to be overridden.
	-- @param [Position] Vector2 position value world space.
	-- @return The new ripple

	-- No position? SEt to center.
	Position = Position or (self.Container.AbsolutePosition + self.Container.AbsoluteSize/2)

	local Radius = self:FurthestCornerDistanceFrom(Position)

	local NewRipple = Ripple.FromPosition(self.Container, Position) 
	NewRipple:SetInkColor(self.InkColor)
	NewRipple:SetTargetRadius(Radius)

	if self.Recenter then
		NewRipple:TargetCenter()
	end

	return NewRipple
end

function PaperRipple:Down(Position)
	--- Handles a new ripple. Public function. Also bound to input.
	-- @param [Position] Vector2 position value world space.
	-- @return The new ripple

	self:ReleaseRipples() -- Release current ripples...
	local NewRipple = self:ConstructNewRipple(Position)
	self:AddRipple(NewRipple)

	return NewRipple
end

function PaperRipple:Up()
	--- Handles input being released, which is basically just releasing all the ripples. 

	self:ReleaseRipples()
	self.InputMaid.InputEnded = nil
end

function PaperRipple:BindInput()
	--- Binds the input to the InputMaid to detect/handle Touch,
	--  and mouse button inputs over the GUI in question. Will override
	--  old bindings with the same names.

	local ValidInputEnums = {}
	for Index, EnumName in pairs({"Touch", "MouseButton1", "MouseButton2", "MouseButton3"}) do
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

	self.InputMaid.InputBegan = self.Container.InputBegan:connect(function(InputObject)
		if ValidInputEnums[InputObject.UserInputType] then
			local Position = Vector2.new(InputObject.Position.X, InputObject.Position.Y)
			self:Down(Position)

			DownTypes[InputObject.UserInputType] = true
			
			-- Bind to event.
			self.InputMaid.InputEnded = UserInputService.InputEnded:connect(OnUp)
		end
	end)

	--[[
	self.InputMaid.InputEnded = self.Container.InputEnded:connect(function(InputObject)
		if ValidInputEnums[InputObject.UserInputType] then
			self:Up()
		end
	end)--]]
end

function PaperRipple:Destroy()
	--- Destroys the ripple, and it's container GUI for easy
	--  GC on dynamically created stuff. Also disconnects all
	--  events in the offchance that somehow we
	--  didn't do that well either.

	-- Remove all ripples.
	while #self.Ripples > 0 do
		self:RemoveRipple(self.Ripples[1] or error("No ripple?"))
	end

	self:StopAnimating()

	self.Container:Destroy()
	self.Container = nil

	self.InputMaid:DoCleaning()
	self.InputMaid = nil

	setmetatable(self, nil)
end

return PaperRipple