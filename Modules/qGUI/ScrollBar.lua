local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local RunService        = game:GetService("RunService")
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary('qSystems')
local qGUI              = LoadCustomLibrary('qGUI')

qSystems:import(getfenv(0));

-- ScrollBar library
-- Change Log --
--[[
January 23rd, 2014
- Updated to new class system

Janurary 8th, 2014
- Fixed velocity when scrolling, as events didn't call unless a change occured. 
- Connected it to RunService.Stepped


--]]

local lib = {}

local function CreateFlatBacking(Frame, Spacing)
	-- Applies a flat backing on the scroll bar. 
	-- @param Frame The frame to put it on
	-- @param Spacing The spacing on the left/right/top/bottom sides. The whitespace. Should be divisible by 2.

	Spacing = Spacing or 2

	local SmoothBacking = Make("Frame", {
		BackgroundTransparency = 0;
		BorderSizePixel        = 0;
		Parent                 = Frame;
		Name                   = "Backing";
		BackgroundColor3       = Color3.new(148/255, 161/255, 174/255);
		Size                   = UDim2.new(1, -Spacing*2, 1, -Spacing*2);
		Position               = UDim2.new(0, Spacing, 0, Spacing);
	})

	return SmoothBacking
end

local MakeKineticModel = Class(function(KineticModel, ContainerFrame, ContentFrame, ScreenGui)
	-- Theoretical model

	KineticModel.Duration = 0.6
	KineticModel.BounceBackDuration = 0.3;
	KineticModel.Position = 0
	KineticModel.UpdateInterval = 1/30

	KineticModel.Velocity = 0
	KineticModel.Minimum = 0;
	KineticModel.Maximum = 1000

	KineticModel.MaxBounce = 50;

	KineticModel.DisplayPosition = KineticModel.Position -- The position it displays at.
	KineticModel.OnPositionChange = function() end -- Callbacks. 
	KineticModel.OnScrollStart = function() end
	KineticModel.OnScrollStop = function() end

	KineticModel.LastPosition = 0
	KineticModel.TimeStamp = tick()

	KineticModel.UpdatingId = 0

	function KineticModel:Clamp(Position, IncludeBounce)
		-- Clamp's the model's position into the range.
		if not IncludeBounce then
			if Position > self.Maximum then
				return self.Maximum
			elseif Position < self.Minimum then
				return self.Minimum
			else
				return Position
			end
		else
			if Position > self.Maximum + self.MaxBounce then
				return self.Maximum + self.MaxBounce
			elseif Position < self.Minimum  - self.MaxBounce  then
				return self.Minimum - self.MaxBounce
			else
				return Position
			end
		end
	end

	function KineticModel:SetRange(Start, End)
		-- Set's the range that the model can scroll at...

		self.Minimum = Start
		self.Maximum = End
	end

	function KineticModel:GetRange(Start, End)
		-- Return's the range...

		return self.Minimum, self.Maximum
	end

	function KineticModel:SetPosition(NewPosition, DivideNewVelocityBy)
		-- Set's the position of the kinetic model. Using this, it'll calculate velocity.

		DivideNewVelocityBy = DivideNewVelocityBy or 1 -- Used by Scrollbar. 

		local CurrentTime = tick()
		local ElapsedTime = CurrentTime - self.TimeStamp

		if NewPosition > self.Maximum then
			-- print("[KineticModel] - Past Max Manual @ "..NewPosition)
			-- Dampen position so it can't go over. In this case, summation with Maximum/2 as the first term, 0.5 as the rate.

			local Displacement = math.abs(NewPosition - self.Maximum)
			local TimesOver = Displacement / self.MaxBounce
			local DisplayPosition = (((self.MaxBounce/2) * (1 - 0.5 ^ TimesOver)) / 0.5)
			self.Position = NewPosition

			self.DisplayPosition = DisplayPosition
			self.OnPositionChange(DisplayPosition)
		elseif NewPosition < self.Minimum then
			-- print("[KineticModel] - Past Min Manual @ "..NewPosition)

			local Displacement = math.abs(NewPosition - self.Minimum)
			local TimesOver = Displacement / self.MaxBounce
			local DisplayPosition = self.Minimum - (((self.MaxBounce/2) * (1 - 0.5 ^ TimesOver)) / 0.5)
			self.Position = NewPosition

			self.DisplayPosition = DisplayPosition
			self.OnPositionChange(DisplayPosition)
		else
			self.Position = NewPosition

			self.DisplayPosition = self.Position
			self.OnPositionChange(self.Position)
		end

		local LocalVelocity = (((self.Position - self.LastPosition)) / ElapsedTime) / DivideNewVelocityBy
		self.TimeStamp = CurrentTime
		self:SetVelocity((0.2 * self.Velocity) + (0.8 * LocalVelocity)) -- 20% previous velocity maintained, 80% of new velocity used.


		self.LastPosition = self.Position
		-- print("[KineticModel] - Set Velocity @ "..self.Velocity.."; Local Velocity @ "..LocalVelocity.."; ElapsedTime: "..ElapsedTime)
	end

	function KineticModel:SetVelocity(Velocity)
		-- Set's the velocity

		-- local TargetPosition = self.Position + Velocity
		--print("[KineticModel] - Set Velocity @ "..Velocity)
		self.Velocity = Velocity

	end

	function KineticModel:AddVelocity(AddVelocity)
		-- Set's the velocity

		self.Velocity = self.Velocity + AddVelocity
	end

	function KineticModel:ResetSpeed()
		-- Reset's the speed to 0, stops update loops. 

		--print("[KineticModel] - Reset Speed")
		self.Velocity = 0
		self.LastPosition = self.Position
		self.UpdatingId = self.UpdatingId + 1
		self.TimeStamp = tick()
	end

	function KineticModel:ScrollTo(NewPosition, DoNotAnimate)
		if not DoNotAnimate then
			self:ResetSpeed()
			self:SetVelocity(NewPosition - self.Position) -- -160 - (-180) 20 Instead, -180 - -160
			self:Release()
			-- print("[KineticModel] - Scrolling velocity ScrollTo @ "..(self.Position - NewPosition).."; target @ "..NewPosition)
		else
			self:ResetSpeed()
			if NewPosition > self.Maximum then -- Check if we're overbounds, and scale accordingly. 
				local Displacement = math.abs(NewPosition - self.Maximum)
				local TimesOver = Displacement / self.MaxBounce
				local DisplayPosition = (((self.MaxBounce/2) * (1 - 0.5 ^ TimesOver)) / 0.5)
				self.Position = NewPosition

				self.DisplayPosition = DisplayPosition
				self.OnPositionChange(DisplayPosition)
				self:Release()
			elseif NewPosition < self.Minimum then -- Check if we're overbounds, and scale accordingly. 
				local Displacement = math.abs(NewPosition - self.Minimum)
				local TimesOver = Displacement / self.MaxBounce
				local DisplayPosition = self.Minimum - (((self.MaxBounce/2) * (1 - 0.5 ^ TimesOver)) / 0.5)
				self.Position = NewPosition

				self.DisplayPosition = DisplayPosition
				self.OnPositionChange(DisplayPosition)
				self:Release()
			else
				self.Position = NewPosition

				self.DisplayPosition = NewPosition
				self.OnPositionChange(self.Position)
			end
			-- print("Update position @ "..self.Position .. " NewPosition @ " .. NewPosition)
		end
	end

	function KineticModel:Release()
		-- Start the update...

		-- print("[KineticModel] - Release @ "..self.Position.."; Velocity @ "..self.Velocity)
		local Amplitude = self.Velocity
		local Start = self.Position
		--local TargetPosition = self.Position + Amplitude
		--local TimeConstant = self.Duration--1 + self.Duration /  6;
		self.TimeStamp = tick()

		self.UpdatingId = self.UpdatingId + 1
		local LocalUpdateId = self.UpdatingId
		-- print("release start " .. LocalUpdateId)
		Spawn(function() -- Update loop start.
			while (LocalUpdateId == self.UpdatingId) do
				local ElapsedTime = tick() - self.TimeStamp
				local NewPosition = Start + Amplitude * ((ElapsedTime/self.Duration)^(1/2))

				-- print("[KineticModel] - Updating @ "..self.Position.."; Amplitude = "..(Amplitude).."; ElapsedTime = " .. ElapsedTime)

				if (ElapsedTime > self.Duration) or self.Position > self.Maximum or self.Position < self.Minimum then -- WE're over the timelimit,
					local Velocity
					if self.Position > self.Maximum then -- Check if we're overbounds so we can bounce back. 
						local Displacement = math.abs(self.Position - self.Minimum)
						local TimesOver = Displacement / self.MaxBounce
						local Difference = (((self.MaxBounce/2) * (1 - 0.5 ^ TimesOver)) / 0.5)
						self.Position = Difference -- Set position to the display position...
						Velocity = -Difference

					elseif self.Position < self.Minimum then
						local Displacement = math.abs(self.Position - self.Minimum)
						local TimesOver = Displacement / self.MaxBounce
						local Difference = (((self.MaxBounce/2) * (1 - 0.5 ^ TimesOver)) / 0.5)
						self.Position = self.Minimum - Difference
						Velocity = Difference -- Calculate velocity via difference. :D
					else -- Nope, not over bounds, we can stop. 
						self:ResetSpeed()
						self.OnScrollStop(self.Position)
						-- print("[KineticModel] - Stopped @ "..self.Position.."; ElapsedTime @ "..ElapsedTime)
					end

					if Velocity then -- Bounce back, we're over
						-- print(Velocity)
						self.Velocity = Velocity

						self.TimeStamp = tick()
						Start = self.Position
						while LocalUpdateId == self.UpdatingId do
							local ElapsedTime = tick() - self.TimeStamp
							self.Position = Start + Velocity * ((ElapsedTime/self.BounceBackDuration)^(1/2))
							
							self.DisplayPosition = self.Position
							self.OnPositionChange(self.Position)

							if (ElapsedTime > self.BounceBackDuration) then
								self:ResetSpeed()
								self.OnScrollStop(self.Position)
								-- print("[KineticModel] - Stopped (2) @ "..self.Position.."; ElapsedTime @ "..ElapsedTime)
							end
							RunService.Heartbeat:wait(self.UpdateInterval)
							-- wait(self.UpdateInterval)
						end

						self.DisplayPosition = Start + Velocity
						self.OnPositionChange(Start + Velocity)
					else
						self.DisplayPosition = Start + Amplitude
						self.OnPositionChange(Start + Amplitude)
					end
				else
					if NewPosition > self.Maximum then -- Check if we're overbounds, and scale accordingly. 
						local Displacement    = math.abs(NewPosition - self.Maximum)
						local TimesOver       = Displacement / self.MaxBounce
						local DisplayPosition = (((self.MaxBounce/2) * (1 - 0.5 ^ TimesOver)) / 0.5)
						self.Position         = NewPosition
						
						self.DisplayPosition  = DisplayPosition
						self.OnPositionChange(DisplayPosition)
					elseif NewPosition < self.Minimum then -- Check if we're overbounds, and scale accordingly. 
						local Displacement    = math.abs(NewPosition - self.Minimum)
						local TimesOver       = Displacement / self.MaxBounce
						local DisplayPosition = self.Minimum - (((self.MaxBounce/2) * (1 - 0.5 ^ TimesOver)) / 0.5)
						self.Position         = NewPosition

						self.DisplayPosition = DisplayPosition
						self.OnPositionChange(DisplayPosition)
					else
						self.Velocity = NewPosition - self.Position
						self.Position = NewPosition

						self.DisplayPosition = self.Position
						self.OnPositionChange(self.Position)
					end
				end
				RunService.Heartbeat:wait(self.UpdateInterval)
				-- wait(self.UpdateInterval)
			end

			-- print("release end" .. LocalUpdateId)

		end)--]]
	end
end)
lib.MakeKineticModel = MakeKineticModel

local MakeScroller = Class(function(Scroller, Container, Content, ScreenGui, Axis)
	--- Models an iOS style window / a scroll bar.
	-- @param Container The content frame. This is the space that renders. Stuff from 'Content' will
	--        display inside of this. If it's a GuiButton, then it will also allow for ROBLOX user input,
	--        like iOS scrolling. It is suggested you use a GuiButton. 
	-- @param Content The frame inside of the container that contains the actual content.  Probably larger
	--        then the Container, otherwise, there's nothing to scroll...
	-- @param ScreenGui The screengui the Container and Content are in.
	-- @param Axis a char of 'X' or 'Y' that defines what axis the scrollbar works upon.  Only Y works for scroll bars. 

	-- Axis: Char 'X' or Char 'Y'
	Axis = Axis or 'Y';

	--[[
		Positioning is based on some super hacky negative scale

		0 VERY TOP


		-500 VERY BOTTOM

		The range is represented as thus.  That is, the "smallest" size is the Content's absoluteSize + The Container's absoluteSize
		
		So if you have a Container sized at 100, and the content of 500...
		You have a range of 400. Your scroll bar is at 20% (100 / 500) of it's frame. 
		Your maximum is always 0
		Your minimum is negative 400. 

		KineticModel takes in absolute values. Scroller will adjust these absolute positions (relative to the frame)
		to be relative to the Content Frame. 
	
		The positioning mechanism is this:

		Content.Position = UDim2.new(Content.Position.X.Scale, Content.Position.X.Offset, 0, NewPosition)

		You can see it maintains X axis (this is for a Y axis scroller). NewPosition is set directly. 

		Thus, at 0 it is actually at the very bottom, and at -400 it's at the very top. Heck. that's confusing.
	--]]

	local KineticModel       = MakeKineticModel()
	local Pressed            = false
	local ScrollbarPressed -- Hold's a 'Scrollbar' object. 
	-- local MouseScrollEnabled = false -- Can we use the mouse wheel to scroll around? Glitches in First Person. 
	local ReferencePosition  = 0 -- Reference position to the last 'Drag' position, and then calculate velocity from this. :D
	local MouseDrag          = qGUI.GenerateMouseDrag() -- A big GUI to capture Mouse.Moved()
	local Mouse              = Players.LocalPlayer:GetMouse()
	local Scrollbars         = {}
	local StepEvent
	
	Scroller.PixelsPerWheelTurn = 80; -- How many pixels it'll scroll during a wheel turn.
	Scroller.KineticModel       = KineticModel
	Scroller.Content            = Content
	Scroller.Container          = Container
	Scroller.Axis               = Axis
	Scroller.MouseDrag          = MouseDrag
	Scroller.CanDrag            = true
	Scroller.ScrollFinished     = CreateSignal() -- Fires an event whenever a scroll finishes moving. 
	Scroller.InputFinished      = CreateSignal() -- When mouse down, this fires when mouse up
	Scroller.ScrollStarted      = CreateSignal()

	-- For scrollbaroverlays
	local ScrollbarDefaultColor3 = Color3.new(0, 0, 0)
	local ScrollbarMouseOverColor3 = Color3.new(0.1, 0.1, 0.1)

	local function StopStepEvent()
		if StepEvent then
			StepEvent:disconnect()
			StepEvent = nil
		end
	end

	function Scroller:AdjustRange()
		-- Readjustes the range on the scroller.

		local Maximum = 0
		local Minimum = -Content.AbsoluteSize[Axis] + Container.AbsoluteSize[Axis]

		for _, Scrollbar in pairs(Scrollbars) do -- Adjust all the scrollbar's ranges too. :D
			Scrollbar.ResizeBar()
		end

		-- print("[Scroller] - Adjusting range to max @ "..Maximum)
		KineticModel:SetRange(Minimum, Maximum)
	end

	function Scroller.CanScroll()
		return Content.AbsoluteSize[Axis] >= Container.AbsoluteSize[Axis] and Scroller.CanDrag
	end

	function Scroller.StartDrag(PositionX, PositionY)
		-- Position X/Y should be absolute coordinates 
		if ScrollbarPressed then
			print("[Scroller] - Scrollbar is already pressed")
			return false
		elseif not Scroller.CanScroll() then
			return false
		end

		ReferencePosition = Vector2.new(PositionX, PositionY)[Axis]

		Scroller.ScrollStarted:fire(KineticModel.DisplayPosition)

		StopStepEvent()
		StepEvent = RunService.Heartbeat:connect(function() Scroller.Drag(Mouse.X, Mouse.Y) end)

		-- print("[Scroller] - Start drag, reference position @ "..tostring(ReferencePosition))

		Pressed = true
		MouseDrag.Parent = ScreenGui
		KineticModel:ResetSpeed()
	end

	function Scroller.Drag(PositionX, PositionY)
		-- Position X/Y should be absolute coordinates 

		-- print("[Scroller] - Dragging @ (" .. PositionX .. ", " .. PositionY..")")
		if not Scroller.CanScroll() then
			print("[Scroller] - Cannot scroll")
			return false
		end

		local MouseClickPosition = Vector2.new(PositionX, PositionY)

		local Change = (MouseClickPosition[Axis]) - ReferencePosition
		-- if math.abs(Change) >= 1 then
			if Pressed then
				
				local NewPosition = KineticModel.Position + Change

				--print("[Scroller] - Drag, NewPosition @ "..NewPosition.."; Change @ "..Change)
				KineticModel:SetPosition(NewPosition)
				ReferencePosition = MouseClickPosition[Axis]
			elseif ScrollbarPressed then

				local MaxDisplayRange = ScrollbarPressed.ScrollBarContainer.AbsoluteSize[Axis] - ScrollbarPressed.Bar.AbsoluteSize[Axis] 
				                        -- Range displayable by the scrollbar...


				if MaxDisplayRange == 0 then -- can't divide by 0
					KineticModel:SetPosition(0)
				else
					local MinimumScrollerRange, MaximumScrollerRange = KineticModel:GetRange()
					local TotalScrollerRange = MaximumScrollerRange - MinimumScrollerRange -- Total range of the scroller
					--local PercentScrolled = (ScrollbarPressed.Bar.AbsolutePosition - ScrollbarPressed.ScrollBarContainer.AbsolutePosition)[Axis] / MaxDisplayRange
					Change = (Change / MaxDisplayRange) * TotalScrollerRange
					local NewPosition = KineticModel.Position - Change

					--print("[Scroller] - Drag, Scrollbar, NewPosition @ "..NewPosition.."; Change @ "..Change)
					KineticModel:SetPosition(NewPosition, TotalScrollerRange / MaxDisplayRange)
					ReferencePosition = MouseClickPosition[Axis]
				end
			else
				--print("[Scroller] - Scroller not pressed")
				KineticModel:SetPosition(KineticModel.Position)
			end
		-- else
			-- print("[Scroller] - Change too small for drag to register.")
		-- end
	end

	function Scroller.StopDrag()
		--- Stop's it from dragging.

		-- Position X/Y should be absolute coordinates 
		Scroller.InputFinished:fire()
		StopStepEvent()
		Pressed          = false
		ScrollbarPressed = nil 
		KineticModel:Release()
		MouseDrag.Parent = nil
	end

	function Scroller.ScrollDown()
		if Scroller.CanScroll() then
			--print("[Scroller] - Scroll down")
			--local OldVelocity = KineticModel.Velocity

			StopStepEvent()
			
			-- KineticModel:ResetSpeed()
			-- KineticModel:SetVelocity(-Scroller.PixelsPerWheelTurn)
			KineticModel:AddVelocity(-Scroller.PixelsPerWheelTurn)
			KineticModel:Release()
		end
	end

	function Scroller.ScrollUp()
		if Scroller.CanScroll() then
			--print("[Scroller] - Scroll up")
			--local OldVelocity = KineticModel.Velocity

			StopStepEvent()

			-- KineticModel:ResetSpeed()
			-- KineticModel:SetVelocity(Scroller.PixelsPerWheelTurn)
			KineticModel:AddVelocity(Scroller.PixelsPerWheelTurn)
			KineticModel:Release()
		end
	end

	function Scroller.ScrollTo(NewPosition, DoNotAnimate)
		-- @param NewPosition The new position to scroll to. Should be based upon range.

		StopStepEvent()
		KineticModel:ScrollTo(NewPosition, DoNotAnimate)
	end

	function Scroller:AddScrollBar(ScrollBarContainer, DoNotDecorate)
		--- Add's a ScrollBar in the 'ScrollBarContainer', linked to this scrolling frame. Will generate the scroll bar and
		--  Parent to the ScrollBarContainer. 
		-- @param ScrollBarContainer the container that it should be generated in. A frame object.
		-- @pre ScrollBarContainer is a Gui, and it's actually called on the class it comes from...
		-- @post ScrollBarContainer is decorated unless DoNotDecorate is set to true,
		--        There is now a scroll bar inside of ScrollBarContainer linked to the
		--        Scroller. 
		
		--TODO: Add support for horizontal rendering

		local Scrollbar = {}
		Scrollbar.ScrollBarContainer = ScrollBarContainer
		local KineticModel = Scroller.KineticModel
		local Backing

		local Bar = Make("ImageButton", {
			Name                   = "ScrollBar";
			Parent                 = ScrollBarContainer;
			ZIndex                 = math.max(math.min(10, ScrollBarContainer.ZIndex + 1), 0);
			BackgroundTransparency = 1;
			BorderSizePixel        = 0;
			BackgroundColor3       = Color3.new(0, 0, 0);
			Active                 = true;
		})
		Scrollbar.Bar = Bar

		function Scrollbar.ResizeBar() -- Resizes the scrollbar's bar. :D
			if Scroller.Axis == 'Y' then -- Make sure we resize on the correct axis. 
				Bar.Size = UDim2.new(1, 0, (Scroller.Container.AbsoluteSize.Y / Scroller.Content.AbsoluteSize.Y), 0)
			else
				Bar.Size = UDim2.new((Scroller.Container.AbsoluteSize.X / Scroller.Content.AbsoluteSize.X), 0, 1, 0)
			end
		end

		function Scrollbar.Render(NewPosition) -- Rerenders the bar. 

			-- Repositions the ScrollBar. Probably called every time the scroller is moved. 

			-- Prerequests: Scrollbar has been resized correctlyi. 
			-- PostResults: ScrollBar is positioned correctly...

			local MaxDisplayRange = ScrollBarContainer.AbsoluteSize[Axis] - Bar.AbsoluteSize[Axis] -- Range displayable by the scrollbar...
			local MinimumScrollerRange, MaximumScrollerRange = KineticModel:GetRange()
			local TotalScrollerRange = MaximumScrollerRange - MinimumScrollerRange -- Total range of the scroller
			local PercentScrolled = math.abs(KineticModel:Clamp(NewPosition) / TotalScrollerRange)

			--print("[Scroller][ScrollBar] - Render @ "..NewPosition.."; PercentScrolled @ "..PercentScrolled.."; Display @ "..(MaxDisplayRange * PercentScrolled))

			if Scroller.Axis == 'Y' then
				Bar.Position = UDim2.new(0, 0, 0, MaxDisplayRange * PercentScrolled)
			else
				Bar.Position = UDim2.new(0, MaxDisplayRange * PercentScrolled, 0, 0)
			end
		end

		function Scrollbar.OnEnterDisplay()
			if Backing then
				Backing.BackgroundColor3 = ScrollbarMouseOverColor3
			end
		end

		function Scrollbar.OnLeaveDisplay()
			if Backing then
				Backing.BackgroundColor3 = ScrollbarDefaultColor3
			end
		end

		local EventId = 0;

		function Scrollbar.StopScrollFromWhitespace()
			EventId = EventId + 1;
		end

		function Scrollbar.MouseDownOnWhitespace(PositionX, PositionY)
			local PositionDown = Vector2.new(PositionX, PositionY)
			EventId = EventId + 1
			local LocalEventId = EventId

			while LocalEventId == EventId do
				KineticModel:ResetSpeed()
				if math.abs(Bar.AbsolutePosition[Scroller.Axis] - PositionDown[Scroller.Axis] + Bar.AbsoluteSize[Scroller.Axis]/2) < Bar.AbsoluteSize[Scroller.Axis]/2 then
					-- print("[Scroller][ScrollBar] - Stop Down")
					Scrollbar.StopScrollFromWhitespace()
				elseif Bar.AbsolutePosition[Scroller.Axis] < PositionDown[Scroller.Axis] then
					KineticModel:SetVelocity(-Scroller.Container.AbsoluteSize[Scroller.Axis])
				else
					KineticModel:SetVelocity(Scroller.Container.AbsoluteSize[Scroller.Axis])
				end
				KineticModel:Release()
				wait(0.2)
			end
		end

		function Scrollbar.StartDrag(PositionX, PositionY)
			-- Start's the 'Drag' on the scrollbar, so it really fires on Button1Down

			if ScrollbarPressed then
				print("[Scroller] - Scroller is already pressed")
				return false
			end

			Scroller.ScrollStarted:fire(KineticModel.DisplayPosition)

			StopStepEvent()
			KineticModel:ResetSpeed()
			StepEvent = RunService.Heartbeat:connect(function() Scroller.Drag(Mouse.X, Mouse.Y) end)

			ScrollbarPressed = Scrollbar
			ReferencePosition = Vector2.new(PositionX, PositionY)[Axis]

			MouseDrag.Parent = ScreenGui
			KineticModel:ResetSpeed()


			-- print("[Scroller] - Start drag, reference position @ "..tostring(ReferencePosition))
		end

		if not DoNotDecorate then
			Backing = CreateFlatBacking(Bar, 1)
			Backing.BackgroundColor3 = ScrollbarDefaultColor3
			Backing.BackgroundTransparency = 0.5;
		end

		Bar.MouseButton1Down:connect(Scrollbar.StartDrag) -- Hookup events...
		Bar.MouseButton1Up:connect(Scrollbar.StopScrollFromWhitespace)

		ScrollBarContainer.Active = true
		if ScrollBarContainer:IsA("GuiButton") then
			-- These events actually do have to be hooked up, if the container is a thing.
			ScrollBarContainer.MouseButton1Down:connect(Scrollbar.MouseDownOnWhitespace) -- Hookup events...
			ScrollBarContainer.MouseButton1Up:connect(Scrollbar.StopScrollFromWhitespace)
			ScrollBarContainer.MouseEnter:connect(Scrollbar.OnEnterDisplay)
			ScrollBarContainer.MouseLeave:connect(Scrollbar.OnLeaveDisplay)
		else
			Bar.MouseEnter:connect(Scrollbar.OnEnterDisplay)
			Bar.MouseLeave:connect(Scrollbar.OnLeaveDisplay)
		end
		Scrollbar.ResizeBar()
		Scrollbars[#Scrollbars+1] = Scrollbar -- Add the scrollbar 'Object' to the list of scrollbars. 
	end

	local function OnAbsoluteSizeAdjust(Property)
		-- Whenever a component changes size, it adjusts the range. This function is for hooking up to .Changed events.

		if Property == "AbsoluteSize" then
			Scroller:AdjustRange() -- Make sure we don't get into an absoltue loop.
		end
	end

	KineticModel.OnPositionChange = function(NewPosition)
		-- Goes off when the position changes. 

		--print("[Scroller] - Position Changed to "..NewPosition)
		if Axis == 'Y' then
			Content.Position = UDim2.new(Content.Position.X.Scale, Content.Position.X.Offset, 0, NewPosition)
		else
			Content.Position = UDim2.new(0, NewPosition, NewPositionContent.Position.Y.Scale, Content.Position.Y.Offset)
		end

		for _, Scrollbar in pairs(Scrollbars) do
			Scrollbar.Render(NewPosition)
		end
	end

	Content.Active = true
	if Content:IsA("GuiButton") then
		-- Content.MouseEnter:connect(function()
		-- 	Scroller.EnabledMouseScroll()
		-- 	--[[for _, Scrollbar in pairs(Scrollbars) do
		-- 		Scrollbar.OnEnterDisplay()
		-- 	end--]]
		-- end)
		-- Content.MouseLeave:connect(function()
		-- 	Scroller.DisableMouseScroll()
		-- 	--[[for _, Scrollbar in pairs(Scrollbars) do
		-- 		Scrollbar.OnLeaveDisplay()
		-- 	end--]]
		-- end)
		Content.MouseButton1Down:connect(Scroller.StartDrag)
	end

	Content.MouseWheelForward:connect(function()
		--print("[Scroller] - Wheel Move Forward")
		Scroller.ScrollUp()
	end)
	Content.MouseWheelBackward:connect(function()
		--print("[Scroller] - Wheel Move Backwards")
		Scroller.ScrollDown()
	end)

	--MouseDrag.MouseMoved:connect(Scroller.Drag)
	MouseDrag.MouseButton1Up:connect(function()
		Scroller.StopDrag()
	end)
	Container.Changed:connect(OnAbsoluteSizeAdjust)
	Content.Changed:connect(OnAbsoluteSizeAdjust)

	Scroller:AdjustRange()

	KineticModel.OnScrollStop = function(Position)
		Scroller.ScrollFinished:fire(KineticModel.DisplayPosition)
	end
end)
lib.MakeScroller = MakeScroller

return lib