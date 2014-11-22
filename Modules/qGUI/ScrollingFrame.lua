local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local LocalPlayer      = Players.LocalPlayer
local Mouse            = LocalPlayer:GetMouse()

-- ScrollingFrame.lua
-- @author Quenty

--- UTILITY ---

local function GetPositionFromOffset(Offset, Axis)
	-- Utility function

	if Axis == 'Y' then
		return UDim2.new(0, 0, 0, -Offset)
	elseif Axis == 'X' then
		return UDim2.new(0, -Offset, 0, 0)
	else
		error("[GetPositionFromOffset] - Invalid Axis")
	end
end

local function GetSizeFromAxis(Size, Axis)
	-- Utility function

	if Axis == 'Y' then
		return UDim2.new(1, 0, 0, Size)
	elseif Axis == 'X' then
		return UDim2.new(0, Size, 1, 0)
	else
		error("[GetSizeFromAxis] - Invalid Axis")
	end
end


-- Utility that would usually be imported, but I want a portable library:

local MakeMaid do
	local index = {
		GiveTask = function(self, task)
			local n = #self.Tasks+1
			self.Tasks[n] = task
			return n
		end;
		DoCleaning = function(self)
			local tasks = self.Tasks
			for name,task in pairs(tasks) do
				if type(task) == 'function' then
					task()
				else
					task:disconnect()
				end
				tasks[name] = nil
			end
			-- self.Tasks = {}
		end;
	};

	local mt = {
		__index = function(self, k)
			if index[k] then
				return index[k]
			else
				return self.Tasks[k]
			end
		end;
		__newindex = function(self, k, v)
			local tasks = self.Tasks
			if v == nil then
				-- disconnect if the task is an event
				if type(tasks[k]) ~= 'function' and tasks[k] then
					tasks[k]:disconnect()
				end
			elseif tasks[k] then
				-- clear previous task
				self[k] = nil
			end
			tasks[k] = v
		end;
	}

	function MakeMaid()
		return setmetatable({Tasks={},Instances={}},mt)
	end
end

local Signal = {}

function Signal.new()
	local sig = {}
	
	local mSignaler = Instance.new('BindableEvent')
	
	local mArgData = nil
	local mArgDataCount = nil
	
	function sig:fire(...)
		mArgData = {...}
		mArgDataCount = select('#', ...)
		mSignaler:Fire()
	end
	
	function sig:connect(f)
		if not f then error("connect(nil)", 2) end
		return mSignaler.Event:connect(function()
			f(unpack(mArgData, 1, mArgDataCount))
		end)
	end
	
	function sig:wait()
		mSignaler.Event:wait()
		assert(mArgData, "Missing arg data, likely due to :TweenSize/Position corrupting threadrefs.")
		return unpack(mArgData, 1, mArgDataCount)
	end
	
	return sig
end


local function Round(Number, Divider)
	-- Rounds a Number, with 1.5 rounding up to 2, and so forth, by default. 
	-- @param Number the Number to round
	-- @param [Divider] optional Number of which to "round" to. If nothing is given, it will default to 1. 

	Divider = Divider or 1

	return (math.floor((Number/Divider)+0.5)*Divider)
end

local function PointInBounds(Frame, X, Y)
	local TopBound    = Frame.AbsolutePosition.Y
	local BottomBound = Frame.AbsolutePosition.Y + Frame.AbsoluteSize.Y
	local LeftBound   = Frame.AbsolutePosition.X
	local RightBound  = Frame.AbsolutePosition.X + Frame.AbsoluteSize.X

	if Y > TopBound and Y < BottomBound and X > LeftBound and X < RightBound then
		return true
	else
		return false
	end
end

local function MouseOver(Mouse, Frame)
	return PointInBounds(Frame, Mouse.X, Mouse.Y)
end


local function GetIndexByValue(Values, Value)
	-- Return's the index of a Value. 

	for Index, TableValue in next, Values do
		if Value == TableValue then
			return Index;
		end
	end

	return nil
end

local function CreateFlatBacking(Frame, Spacing)
	-- Applies a flat backing on the scroll bar. 
	-- @param Frame The frame to put it on
	-- @param Spacing The spacing on the left/right/top/bottom sides. The whitespace. Should be divisible by 2.

	Spacing = Spacing or 2

	local SmoothBacking = Instance.new("Frame")
	SmoothBacking.BackgroundTransparency = 0
	SmoothBacking.BorderSizePixel        = 0
	SmoothBacking.Name                   = "Backing"
	SmoothBacking.BackgroundColor3       = Color3.new(148/255, 161/255, 174/255)
	SmoothBacking.Size                   = UDim2.new(1, -Spacing*2, 1, -Spacing*2)
	SmoothBacking.Position               = UDim2.new(0, Spacing, 0, Spacing)
	SmoothBacking.Parent                 = Frame
	SmoothBacking.ZIndex                 = Frame.ZIndex

	return SmoothBacking
end

local function GetAveragePositionFromTouchPositions(TouchPositions)
	local AveragePosition = Vector2.new(0,0)
			
	if #TouchPositions > 0 then
		for _, Position in pairs(TouchPositions) do
			AveragePosition = AveragePosition + Position
		end
		AveragePosition = AveragePosition / #TouchPositions
	end

	return AveragePosition
end

--- Scroll Bar ---
local ScrollBar = {}
ScrollBar.__index = ScrollBar

function ScrollBar.new(BarContainer, Scroller)
	--- NOTE: BarContainer.Active MUST be true for the scroll wheels to work. This is for a UX reason.
	--- NOTE: BarContainer SHOULD be a button. 

	-- @param Scroller A scrolling frame.

	local new = {}
	setmetatable(new, ScrollBar)

	new.Active = true

	new.Scroller     = Scroller
	new.BarContainer = BarContainer
	new.Maid         = MakeMaid()
	new.Axis         = Scroller.Axis

	new.ScrollSpeedOnContainerClick = 0.0625 -- When someone clicks on the BarContainer, how fast do we scroll.
	
	local BarFrame = Instance.new("ImageButton", BarContainer)
	BarFrame.Name                   = "ScrollBar"
	BarFrame.BackgroundColor3       = Color3.new(148/255, 161/255, 174/255)
	BarFrame.BackgroundTransparency = 1;
	BarFrame.Image                  = ""
	BarFrame.Archivable             = false
	BarFrame.Parent                 = BarContainer
	BarFrame.BorderSizePixel        = 0
	BarFrame.AutoButtonColor        = false
	BarFrame.ZIndex                 = BarContainer.ZIndex

	CreateFlatBacking(BarFrame, 1)

	new.BarFrame              = BarFrame

	new.Max = 0 -- About to update. Max offset really.
	new:UpdateRender()
	new:UpdateMouseWheelEvents()

	new.Maid.ScrollerChanged = Scroller.Frame.Changed:connect(function(Property)
		if Property == "AbsoluteSize" or Property == "Position" then
			new:UpdateRender()
		end
	end)

	new.Maid.BarFrameMouseButton1Down = BarFrame.MouseButton1Down:connect(function()
		new:Tap()
	end)

	new.Maid.BarContainerChanged = BarContainer.Changed:connect(function(Property)
		if Property == "AbsoluteSize" then
			new:UpdateRender()
		elseif Property == "Active" then
			new:UpdateMouseWheelEvents()
		end
	end)

	new.Maid.FrameInputBegan = BarContainer.InputBegan:connect(function(InputObject)
		if InputObject.UserInputType.Name == "MouseButton1" or InputObject.UserInputType.Name == "Touch" then
			new:HandleClickOnBacking(new:GetRelativePosition())
		end
	end)

	return new
end

function ScrollBar:UpdateMouseWheelEvents()
	if self.BarContainer.Active then
		self.Maid.MouseWheelUp = self.BarContainer.MouseWheelForward:connect(function()
			if not self.Pressed and not self.Scroller.Pressed  then
				self.Scroller:ScrollUp()
			end
		end)

		self.Maid.MouseWheelBackward = self.BarContainer.MouseWheelBackward:connect(function()
			if not self.Pressed and not self.Scroller.Pressed then
				self.Scroller:ScrollDown()
			end
		end)
	else
		self.Maid.MouseWheelUp       = nil
		self.Maid.MouseWheelBackward = nil
	end
end

function ScrollBar:HandleClickOnBacking(Offset)
	-- Handles clicking on the back. We'll emulate sublime text behavior.
	-- @param Offset How far offset the mouse was. 

	if not (self.Pressed or self.Scroller.Pressed) then
		local CurrentRelativePosition = self.BarFrame.AbsolutePosition[self.Axis] - self.BarContainer.AbsolutePosition[self.Axis]
		if Offset > CurrentRelativePosition then
			self.Scroller:ScrollTo(self.Scroller.Offset + self.Scroller.PixelsPerPageUpDown, self.ScrollSpeedOnContainerClick)
		else
			self.Scroller:ScrollTo(self.Scroller.Offset - self.Scroller.PixelsPerPageUpDown, self.ScrollSpeedOnContainerClick)
		end
	else
		warn("[ScrollBar][HandleClickOnBacking] - Can't scroll, already pressed")
	end
end

function ScrollBar:GetRelativePosition()
	-- Relative input position to frame. 
	-- Mouse Offset from top of frame. 

	return Mouse[self.Axis] - self.BarContainer.AbsolutePosition[self.Axis]
end

function ScrollBar:UpdateRender()
	-- Resize bar

	local ContentVisible        = self.Scroller.Container.AbsoluteSize[self.Axis]
	local TotalContentArea      = self.Scroller.Frame.AbsoluteSize[self.Axis]

	if TotalContentArea == 0 then -- Nothing like dividing by 0
		TotalContentArea = 1
	end

	local ScrollerOffset = self.Scroller.Offset
	if self.Scroller:IsAutoScrolling() and self.Scroller.Target then
		ScrollerOffset = self.Scroller.Target
	end

	-- Handle over bounds...
	local AmountOver = -math.min(ScrollerOffset, self.Scroller.Max - ScrollerOffset)
	if AmountOver > 0 then
		TotalContentArea = TotalContentArea + AmountOver
	end

	local ContentVisiblePercent = ContentVisible/TotalContentArea
	local ScaledSize            = ContentVisiblePercent * (self.BarContainer.AbsoluteSize[self.Axis])
	
	self.BarFrame.Size          = GetSizeFromAxis(ScaledSize, self.Axis)
	
	-- Position it



	local CurrentPercent = ScrollerOffset/self.Scroller.Max
	CurrentPercent       = math.min(1, math.max(0, CurrentPercent)) -- Constrain between 0 and 1.

	local MaximumScrollPosition = self.BarContainer.AbsoluteSize[self.Axis] - self.BarFrame.AbsoluteSize[self.Axis]
	local Offset                = (CurrentPercent*MaximumScrollPosition)
	
	self.BarFrame.Position      = GetPositionFromOffset(-Offset, self.Axis)

	self.Max = self.BarContainer.AbsoluteSize[self.Axis] - self.BarFrame.AbsoluteSize[self.Axis]
end

function ScrollBar:Destroy()
	self.Maid:DoCleaning()
	self.Maid    = nil

	self.BarFrame:Destroy()
	self.BarFrame = nil

	self.Active = false

	self.Scroller.ScrollBars[self] = nil
	setmetatable(self, nil)
end

function ScrollBar:Drag()
	if (self.Pressed) then
		local NewReference    = self:GetRelativePosition()
		local Delta           = self.Reference - NewReference
		self.Reference        = NewReference
		
		self:ConnectReleaseEvent()

		local BarContainerAbsolutePosition = self.BarContainer.AbsolutePosition[self.Axis]
		local ActualOffset    = BarContainerAbsolutePosition - self.PretendAbsolutePosition--self.BarFrame.AbsolutePosition[self.Axis]
		local SupposeToRender = -(ActualOffset + Delta)
		local Percent         = SupposeToRender/self.Max

		self.PretendAbsolutePosition = BarContainerAbsolutePosition + SupposeToRender
		-- self.BarFrame.Position = GetPositionFromOffset(-SupposeToRender, self.Axis)
		local NewScrollerOffset = (self.Scroller.Max) * Percent

		self.Scroller:SetOffset(NewScrollerOffset)
	else
		warn("[ScrollBar] - Cannot drag, not pressed")
	end
end

function ScrollBar:Tap()
	if not self.Pressed and not self.Scroller.Pressed then
		self.Pressed = true
		self.Scroller.Pressed = true

		self.Reference = self:GetRelativePosition()
		self.PretendAbsolutePosition = self.BarFrame.AbsolutePosition[self.Axis]

		if self.Scroller.CurrentAutoScrollThread then -- No auto scrollying while we are dragging.
			self.Scroller.CurrentAutoScrollThread = nil
		else
			self.Scroller.ScrollStart:fire(self.Scroller.Offset)
		end

		local Success, Error = coroutine.resume(coroutine.create(function()
			while self.Pressed and self.Active do
				self:Drag()
				RunService.Heartbeat:wait()
			end
			self.Scroller.Pressed = false
			self.Scroller:ScrollTo(self.Scroller.Offset) -- scroll to itself, incase we're over the edge, we can bounce back, et cetera. 
		end))
		assert(Success, Error)
	else
		warn("[ScrollBar] - Cannot tap, already tapping!")
	end
end

function ScrollBar:DisconnectReleaseEvent()
	self.Maid.CatchMouseUpInput = nil
end

function ScrollBar:Release()
	self.Pressed = false
	self:DisconnectReleaseEvent()

	self.Scroller.ScrollEnd:fire(self.Scroller.Offset)
end

function ScrollBar:ConnectReleaseEvent()
	self.Maid.CatchMouseUpInput = UserInputService.InputEnded:connect(function(InputObject)
		if InputObject.UserInputType.Name == "MouseButton1" or InputObject.UserInputType.Name == "Touch" then
			self:Release()
		end
	end)
end



--- SCROLLING FRAME ---
local ScrollingFrame = {}
ScrollingFrame.__index = ScrollingFrame

ScrollingFrame.PixelsPerWheelTurn = 40



-- Local memory usage scroll frame using metatables. 
-- See: https://github.com/ariya/kinetic

function ScrollingFrame.new(Frame, Axis)
	--- Note: Frame must inherit from GuiButton to work with click and drag.
	-- Note: Frame must have the "Active" property as true for scrolling to work.

	local new = {}
	setmetatable(new, ScrollingFrame)

	-- READ ONLY.
	new.Active    = true -- Has not been destroyed
	new.Axis      = Axis or 'Y' 
	new.Frame     = Frame 
	new.Container = Frame.Parent
	new.Pressed   = false

	assert(new.Container.ClipsDescendants, "Container does not clip descendants")

	new.Max, new.Min, new.PixelsPerPageUpDown = 0, 0, 0-- About to recalc
	new:RecalculateBounds()
	new.Offset = Frame.AbsolutePosition[new.Axis] - new.Container.AbsolutePosition[new.Axis] 

	new.ScrollBars = {}

	--- Events!
	new.ScrollStart = Signal.new() -- These should fire whenever a scroll starts or finishes. A scroll is anytime the frame is constantly updating, so we can't guarantee that
	new.ScrollEnd   = Signal.new() -- this will fire at transitions between user and autonimious scrolling, 

	--- CONNECT EVENTS ----
	local Maid = MakeMaid()
	new.Maid = Maid

	new:UpdateMouseWheelEvents()

	Maid.FrameChanged = Frame.Changed:connect(function(Property)
		if Property == "AbsoluteSize" then
			new:RecalculateBounds()
		elseif Property == "Active" then
			new:UpdateMouseWheelEvents()
		end
	end)

	Maid.ContainerChanged = new.Container.Changed:connect(function(Property)
		if Property == "AbsoluteSize" then
			new:RecalculateBounds()
		end
	end)

	new.Maid.FrameInputBegan = Frame.InputBegan:connect(function(InputObject)
		if InputObject.UserInputType.Name == "MouseButton1" or InputObject.UserInputType.Name == "Touch" then
			new:Tap()
		end
	end)

	-- if UserInputService.TouchEnabled then
	-- 	new.LastFingerCount = 0
	-- 	new:DisconnectReleaseEvent() -- Connects up the trigger event.
	-- end

	return new
end

--[[
function ScrollingFrame:HandleTouchPan(TouchPositions, TotalTransition, Velocity, State)
	local AveragePosition = GetAveragePositionFromTouchPositions(TouchPositions)
	
	if Enum.UserInputState.Begin and not self.Pressed then
		self.LastAverageFingerPosition = AveragePosition
		self:Tap()
	elseif self.Pressed then
		if InputState == Enum.UserInputState.Change and #TouchPositions > 0 then
			self.LastAverageFingerPosition = AveragePosition
		elseif InputState ~= Enum.UserInputState.None then 
			self.LastAverageFingerPosition = nil
			self:Release()
		end
	end
end--]]

function ScrollingFrame:ExpectedAtBottom()
	--- Basically :IsAtBottom, except for future iterations of this, we could be animating TOWARDS the bottom. 

	return self.Offset >= (self.Max - 1)
end

function ScrollingFrame:AddScrollBar(BarContainer)
	local NewScrollBar = ScrollBar.new(BarContainer, self)
	self.ScrollBars[NewScrollBar] = true
	
	return NewScrollBar
end

function ScrollingFrame:Destroy()
	-- GC

	-- Clear out animation loops
	self.Active                  = false
	self.CurrentAutoScrollThread = nil

	for ScrollBar, _ in pairs(self.ScrollBars) do
		ScrollBar:Destroy()
	end

	-- Clean up event stuff
	self.Maid:DoCleaning()
	self.Maid = nil

	self.ScrollStart = nil
	self.ScrollEnd   = nil


	setmetatable(self, nil)
end

function ScrollingFrame:ScrollUp(Distance)
	if not self.Pressed then
		self:SetOffset(self.Offset - (Distance or self.PixelsPerWheelTurn))
	end
end

function ScrollingFrame:ScrollDown(Distance)
	if not self.Pressed then
		self:SetOffset(self.Offset + (Distance or self.PixelsPerWheelTurn))
	end
end

function ScrollingFrame:UpdateMouseWheelEvents()
	if self.Frame.Active then
		self.Maid.MouseWheelUp = self.Frame.MouseWheelForward:connect(function()
			self:ScrollUp()
		end)

		self.Maid.MouseWheelBackward = self.Frame.MouseWheelBackward:connect(function()
			self:ScrollDown()
		end)
	else
		self.Maid.MouseWheelUp       = nil
		self.Maid.MouseWheelBackward = nil
	end
end

function ScrollingFrame:RecalculateBounds()
	-- Yeah, this could really mess up some animations on inhereted stuff.

	self.Min                 = 0
	self.Max                 = math.max(1, self.Frame.AbsoluteSize[self.Axis] - self.Container.AbsoluteSize[self.Axis]) -- No dividing by zero, hear me!
	self.PixelsPerPageUpDown = self.Container.AbsoluteSize[self.Axis]
end

function ScrollingFrame:RecalculateOffset()
	--- This may not be a good thing to touch. 

	self.Offset = self.Container.AbsolutePosition[self.Axis] - self.Frame.AbsolutePosition[self.Axis]
end

function ScrollingFrame:GetRelativePosition()
	-- Relative input position to frame. 
	-- Mouse Offset from top of frame. 

	if self.LastAverageFingerPosition then -- This is iOS case.
		local RelativePosition = self.LastAverageFingerPosition[self.Axis] - self.Container.AbsolutePosition[self.Axis]

		return RelativePosition
	end

	return Mouse[self.Axis] - self.Container.AbsolutePosition[self.Axis]
end

function ScrollingFrame:ConstrainOffset(Offset)
	--- Constrains ANY offset and returns the constrained value.
	--- Utility function that returns a newly constrained offset based on max / min

	return (Offset < self.Min) and self.Min or (Offset > self.Max) and self.Max or Offset
end

function ScrollingFrame:SetOffset(Offset)
	self.Offset = self:ConstrainOffset(Offset)
	self.Frame.Position = GetPositionFromOffset(self.Offset, self.Axis)
end

function ScrollingFrame:ScrollTo(Offset)
	if self.Pressed then
		self:SetOffset(Offset)
	else
		warn("[ScrollingFrame][ScrollTo] - Will not ScrollTo new location, we are pressed")
	end
end

function ScrollingFrame:Drag()
	-- Interal code used during drag

	if (self.Pressed) then
		local Offset = self:GetRelativePosition()
		local Delta = self.Reference - Offset
		self.Reference = Offset

		self:SetOffset(self.Offset + Delta)
		return Delta
	else
		warn("[ScrollingFrame] - Cannot drag, not pressed")
		return 0
	end
end

function ScrollingFrame:IsScrolling()
	return self.Pressed
end

function ScrollingFrame:ConnectReleaseEvent()
	self.Maid.CatchMouseUpInput = UserInputService.InputEnded:connect(function(InputObject)
		if InputObject.UserInputType.Name == "MouseButton1" or InputObject.UserInputType.Name == "Touch" then
			self:Release()
		end
	end)

	-- new.Maid.DragBegan = nil

	-- if UserInputService.TouchEnabled then
	-- 	self.Maid.UISTouchEnabled = BarContainer.TouchPan:connect(function(TouchPositions, TotalTransition, Velocity, State)
	-- 		new:HandleTouchPan(TouchPositions, TotalTransition, Velocity, State)
	-- 	end)
	-- end
end

function ScrollingFrame:DisconnectReleaseEvent()
	self.Maid.CatchMouseUpInput = nil

	-- self.Maid.UISTouchEnabled = nil
	-- if UserInputService.TouchEnabled then
	-- 	new.Maid.DragBegan = BarContainer.TouchPan:connect(function(TouchPositions, TotalTransition, Velocity, State)
	-- 		if not self.Pressed then
	-- 			new:HandleTouchPan(TouchPositions, TotalTransition, Velocity, State)
	-- 		end
	-- 	end)
	-- end
end

function ScrollingFrame:Tap(OnTapEndCallback)
	--- When the player taps. 
	-- @param [OnTapEndCallback] function(ConsideredClick, ElapsedTime, ScrollDistance)
		-- This callback is quite useful as the .MouseButton1Up event will not fire if the scroll frame is manually triggered. 
		-- It will be called in a coroutine
		-- @param ConsideredClick A boolean, true if it's a click/tap, false if it's a drive. Just an opinion, but prevents broiler plate code. 
		-- @param TimePassed This is how much time passed since the tap started. This is useful to determine a click or an actual attempt to scroll. 
			-- Usually 0.15 is a good number. 
		-- @param ScrollDistance the distance it scrolled only, no direction. 

		-- Note: Even though it is called in a coroutine, it should still error, as this script also yields using ROBLOX's thing first.


	if not self.Pressed then
		self.Pressed = true

		self.Reference = self:GetRelativePosition()
		self:ConnectReleaseEvent()

		self.ScrollStart:fire(self.Offset)

		local Success, Error = coroutine.resume(coroutine.create(function()
			local StartTime = tick()
			local ScrollDistance = 0

			while self.Pressed and self.Active do
				ScrollDistance = ScrollDistance + math.abs(self:Drag())
				RunService.Heartbeat:wait()
			end

			if OnTapEndCallback then
				local ElapsedTime = tick() - StartTime
				local ConsideredClick = (ElapsedTime <= 0.15) or (ScrollDistance <  1)
				OnTapEndCallback(ConsideredClick, ElapsedTime, ScrollDistance)
			end
		end))
		assert(Success, Error)
	else
		warn("[ScrollingFrame] - Cannot tap, already tapping!")
	end
end

function ScrollingFrame:Release()
	--- When the player stops inputting/tapping.

	self:DisconnectReleaseEvent()

	if self.Pressed then
		self.Pressed = false
		self.ScrollEnd:fire(self.Offset)
	end
end

function ScrollingFrame:GetPercentOffset()
	-- Return's the percent offset the thingy is.

	return self.Offset / self.Max
end

function ScrollingFrame:ScrollToBottom()
	self:ScrollTo(self.Max)
end

function ScrollingFrame:ScrollToTop()
	self:ScrollTo(0)
end


-- InertiaScrollingFrame --

local InertiaScrollingFrame = {}
setmetatable(InertiaScrollingFrame, ScrollingFrame)
InertiaScrollingFrame.__index = InertiaScrollingFrame

InertiaScrollingFrame.TimeConstant                  = 0.325 -- iOS standard is 325 ms
InertiaScrollingFrame.WheelTurnAnimationSpeed       = 0.0625 -- Meh, should be instant. 
InertiaScrollingFrame.DefaultScrollToAnimationSpeed = 0.125


function InertiaScrollingFrame.new(Frame, Axis)
	local new = ScrollingFrame.new(Frame, Axis)
	setmetatable(new, InertiaScrollingFrame)

	-- READ ONLY 
	new.Velocity     = 0
	new.Amplitude    = 0

	return new
end

function InertiaScrollingFrame:ExpectedAtBottom()
	--- Basically :IsAtBottom, takes animations into account

	return self.Offset >= (self.Max - 1) or (self.CurrentAutoScrollThread and self.Target and (self.Target >= self.Max - 1) and true or false)
end

function InertiaScrollingFrame:Track()
	-- Called during drag. Tracks velocity.
 
	local Now = tick()
	local Elapsed = Now - self.TimeStamp
	
	self.TimeStamp = tick()

	local Delta = self.Offset - self.LastOffset
	self.LastOffset = self.Offset

	local v = Delta / (0.001 + Elapsed)
	self.Velocity = 0.8 * v + 0.2 * self.Velocity
end

function InertiaScrollingFrame:StartAutoScroll(OverridenTimeConstraint)
	--- Internal function. OverridenTimeConstraint can override the TimeConstant. 

	if OverridenTimeConstraint and OverridenTimeConstraint <= 0 then
		--- INSTANT MODE UNLOCKED WOW PERFORMANCE INCREASED DOGE HAPPY
		self.CurrentAutoScrollThread = nil
		self:SetOffset(self.Target)
	else
		local Current
		Current = coroutine.create(function()
			local TimeStamp    = self.TimeStamp
			local TimeConstant = OverridenTimeConstraint or self.TimeConstant
			
			while Current == self.CurrentAutoScrollThread and self.Active do
				local Elapsed = tick() - TimeStamp
				local Delta = -self.Amplitude * math.exp(-Elapsed / TimeConstant)


				if math.abs(Delta) > 0.5 then
					self:SetOffset(self.Target + Delta)
				else
					self:SetOffset(self.Target)
					break -- self.CurrentAutoScrollThread = nil
				end
				RunService.RenderStepped:wait()
			end

			if self.CurrentAutoScrollThread == Current then
				self.CurrentAutoScrollThread = nil
				if not self.Pressed then
					self.ScrollEnd:fire(self.Offset)
				end
			end
		end)

		if not self.Pressed and not self.CurrentAutoScrollThread then -- We set the CurrentAutoScrollThread before firing so it exists when we fire. 
			self.CurrentAutoScrollThread = Current
			self.ScrollStart:fire(self.Offset)
		else
			self.CurrentAutoScrollThread = Current
		end
		
		local Success, Error = coroutine.resume(Current)
		assert(Success, Error)
	end
end

function InertiaScrollingFrame:Tap(OnTapEndCallback)
	--- When the player taps. 
	-- @param [OnTapEndCallback] function(ConsideredClick, ElapsedTime, ScrollDistance)
		-- This callback is quite useful as the .MouseButton1Up event will not fire if the scroll frame is manually triggered. 
		-- It will be called in a coroutine
		-- @param ConsideredClick A boolean, true if it's a click/tap, false if it's a drive. Just an opinion, but prevents broiler plate code. 
		-- @param TimePassed This is how much time passed since the tap started. This is useful to determine a click or an actual attempt to scroll. 
			-- Usually 0.15 is a good number. 
		-- @param ScrollDistance the distance it scrolled only, no direction. 

		-- Note: Even though it is called in a coroutine, it should still error, as this script also yields using ROBLOX's thing first.

	if not self.Pressed then
		self.Pressed = true

		self.Reference        = self:GetRelativePosition()
		self:ConnectReleaseEvent()

		self.TimeStamp  = tick()
		self.Velocity   = 0
		self.LastOffset = self.Offset
		self.Amplitude  = 0

		if self.CurrentAutoScrollThread then
			self.CurrentAutoScrollThread = nil -- Stop auto scroll stuff. 
		else -- Only fire the event if we aren't already scrolling...
			self.ScrollStart:fire(self.Offset)
		end

		local Success, Error = coroutine.resume(coroutine.create(function()
			local StartTime = tick()
			local ScrollDistance = 0

			while self.Pressed and self.Active do
				ScrollDistance = ScrollDistance + math.abs(self:Drag())
				self:Track()
				local Step = RunService.Heartbeat:wait()
			end

			if OnTapEndCallback then
				local ElapsedTime = tick() - StartTime
				local ConsideredClick = (ElapsedTime <= 0.15) or (ScrollDistance <  1)
				OnTapEndCallback(ConsideredClick, ElapsedTime, ScrollDistance)
			end
		end))
		assert(Success, Error)
	else
		warn("[InertiaScrollingFrame] - Cannot tap, already tapping!")
	end
end

function InertiaScrollingFrame:IsAutoScrolling()
	if self.CurrentAutoScrollThread then
		return true
	else
		return false
	end
end

function InertiaScrollingFrame:ScrollTo(NewOffset, OverridenTimeConstraint)
	--- If OverridenTimeConstraint <= 0 then we won't even animate!
	-- Will not scroll if user is dragging. 

	if not self.Pressed then
		self.CurrentAutoScrollThread = nil

		local Velocity = (NewOffset - self.Offset) / 0.8
		self.Velocity  = Velocity
		self:Release(OverridenTimeConstraint or self.DefaultScrollToAnimationSpeed, true) -- We need to send a OverridenTimeConstraint so it forces animation.
	else
		warn("[InertiaScrollingFrame][ScrollTo] - Will not scroll to new location, we are pressed.")
	end
end

function InertiaScrollingFrame:ScrollToTop(OverridenTimeConstraint)
	--- Scrolls to the top of the window. 

	self:ScrollTo(0, OverridenTimeConstraint)
end

function InertiaScrollingFrame:ScrollToBottom(OverridenTimeConstraint)
	--- Scrolls to the bottom of the window.

	self:ScrollTo(self.Max, OverridenTimeConstraint)
end

function InertiaScrollingFrame:ScrollToChild(Child, Offset, OverridenTimeConstraint)
	---- Scrolls to the top of a child's frame, (so that it is visible, given, of course, it is in the frame).
	-- @param [Offset] Offset past the top of the child
	-- @param [OverridenTimeConstraint] How long it takes to scroll to that point. 

	Offset = Offset or 0
	local RelativePosition = Child.AbsolutePosition[self.Axis] - self.Frame.AbsolutePosition[self.Axis] + Offset

	self:ScrollTo(RelativePosition, OverridenTimeConstraint)
end


function InertiaScrollingFrame:ScrollUp(OverridenTimeConstraint)
	-- Scrolls the current frame up
	-- Won't work is pressed. 

	if not self.Pressed then
		self:ScrollTo(self.Offset - self.PixelsPerWheelTurn, OverridenTimeConstraint or self.WheelTurnAnimationSpeed)
	end
end

function InertiaScrollingFrame:ScrollDown(OverridenTimeConstraint)
	-- Scrolls the current frame down
	-- Won't work is pressed. 

	if not self.Pressed then
		self:ScrollTo(self.Offset + self.PixelsPerWheelTurn, OverridenTimeConstraint or self.WheelTurnAnimationSpeed)
	end
end


function InertiaScrollingFrame:Release(OverridenTimeConstraint, PressedNotRequired)
	-- @param OverridenTimeConstraint Number If not nil, it will force an animation and set the OverridenTimeConstraint to be whatever number is specified
	-- @param PressedNotRequired Lets is do the "release" autoscroll thing when ScrollTo is called. 

	if self.Pressed or PressedNotRequired then
		self:DisconnectReleaseEvent()
		self.Pressed = false

		if math.abs(self.Velocity) > 10 or OverridenTimeConstraint then	
			self.Amplitude = 0.8 * self.Velocity
			self.Target    = Round(self.Offset + self.Amplitude)
			self.TimeStamp = tick()
			self:StartAutoScroll(OverridenTimeConstraint)
		else
			self.ScrollEnd:fire(self.Offset)
			self.CurrentAutoScrollThread = nil -- This should cancel the auto scrolling stuff.
		end
	else
		warn("[InertiaScrollingFrame] - Cannot drag, not pressed")
	end
end




-- EdgeBounceFrame --
-- Like the inertia system, but edges bounce.
-- See: http://jsbin.com/zudim

local BounceScrollingFrame = {}
setmetatable(BounceScrollingFrame, InertiaScrollingFrame)
BounceScrollingFrame.__index = BounceScrollingFrame

BounceScrollingFrame.BounceBackTimeConstraint = 0.125


function BounceScrollingFrame.new(Frame, Axis)
	local new = InertiaScrollingFrame.new(Frame, Axis)
	setmetatable(new, BounceScrollingFrame)

	return new
end

function BounceScrollingFrame:SetOffset(Offset)
	-- Remove constraining from the BounceScrollingFrame

	self.Offset = Offset

	local RenderedOffset = Offset
	local BackBounceRange = self.Container.AbsoluteSize[self.Axis]

	if Offset > self.Max then
		--- In this case, we're over boundaries, we must scale.

		local Displacement = Offset - self.Max
		local TimesOverBounds = Displacement /BackBounceRange
		local ScaleBy = (1 - 0.5 ^ TimesOverBounds)
		RenderedOffset = self.Max + (ScaleBy * BackBounceRange)

	elseif Offset < self.Min then

		local Displacement    = math.abs(Offset) -- Must be a positive number, because 0.5^TimesOverBounds
		local TimesOverBounds = Displacement / BackBounceRange
		local ScaleBy         = (1 - 0.5 ^ TimesOverBounds)
		RenderedOffset        = -(ScaleBy * BackBounceRange) -- And now we de-negatize this thing.

	end
	
	self.Frame.Position = GetPositionFromOffset(RenderedOffset, self.Axis)
end

function BounceScrollingFrame:RecalculateOffset()
	--- This may not be a good thing to touch. 

	error("Not implimented yet") -- TODO: Impliment

	local RenderedOffset = self.Container.AbsolutePosition[self.Axis] - self.Frame.AbsolutePosition[self.Axis]
	local RealOffset = RenderedOffset


	local BackBounceRange = self.Container.AbsoluteSize[self.Axis]

	if self.Offset > self.Max then
		RealOffset = RealOffset - self.Max
		RealOffset = RealOffset / BackBounceRange

		--- Urgh. 

		RealOffset = RealOffset + self.Max
	end

	self.Offset = RealOffset
end


function BounceScrollingFrame:Release(OverridenTimeConstraint, PressedNotRequired)
	--- Note that BounceBackTimeConstraint will override [OverridenTimeConstraint] if self.Offset is over bounds.

	if self.Pressed or PressedNotRequired then
		self:DisconnectReleaseEvent()
		self.Pressed = false

		--- Modify so we derive Amplitude from target, and so that if we are over bounds, we ALWAYS scroll.

		local PreConstrainedAmplitude = 0.8 * self.Velocity
		self.Target = Round(self.Offset + PreConstrainedAmplitude)
		self.TimeStamp = tick()

		local ConstrainedTarget = self:ConstrainOffset(self.Target)
		self.Amplitude = ConstrainedTarget - self.Offset

		if math.abs(self.Velocity) > 10 or ConstrainedTarget ~= self.Target then
			local CustomTimeConstraint = OverridenTimeConstraint

			-- Lets make rubber banding faster.
			if self.Offset > self.Max or self.Offset < self.Min then
				CustomTimeConstraint = self.BounceBackTimeConstraint
			end

			self.Target = ConstrainedTarget
			self:StartAutoScroll(CustomTimeConstraint)
		else
			self.CurrentAutoScrollThread = nil -- This should cancel the auto scrolling stuff.
		end
	end
end



return BounceScrollingFrame