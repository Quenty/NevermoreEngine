local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local MakeMaid = LoadCustomLibrary("Maid").MakeMaid
local Signal = LoadCustomLibrary("Signal")
local SpringPhysics = LoadCustomLibrary("SpringPhysics")

local Scroller = {}
Scroller.ClassName = "Scroller"
Scroller.__index = Scroller
Scroller._Position = 0
Scroller._Min = 0
Scroller._Max = 100
Scroller._ViewSize = 50

function Scroller.new()
	local self = setmetatable({}, Scroller)
	
	self.Spring = SpringPhysics.Spring.New(0)
	self.Spring.Speed = 20
	
	return self
end

function Scroller:GetTimesOverBounds(Position)
	return self:GetDisplacementPastBounds(Position) / self.BackBounceInputRange
end

function Scroller:GetDisplacementPastBounds(Position)
	if Position > self.ContentMax then
		return Position - self.ContentMax
	elseif Position < self.ContentMin then
		return Position
	else
		return 0
	end
end

function Scroller:GetScale(TimesOverBounds)
	return (1 - 0.5 ^ math.abs(TimesOverBounds))
end

function Scroller:__index(Index)
	if Index == "TotalContentLength" then
		return self._Max - self._Min
	elseif Index == "ViewSize" then
		return self._ViewSize
	elseif Index == "Max" then
		return self._Max
	elseif Index == "ContentMax" then
		if self._Max <= self.ContentMin + self._ViewSize then
			return self.ContentMin
		else
			return self._Max - self._ViewSize -- Compensate for AnchorPoint = 0
		end
	elseif Index == "Min" or Index == "ContentMin" then
		return self._Min
	elseif Index == "Position" then
		return self.Spring.Position		
	elseif Index == "BackBounceInputRange" then
		return self._ViewSize -- Maximum distance we can drag past the end
	elseif Index == "BackBounceRenderRange" then
		return self._ViewSize
	elseif Index == "ContentScrollPercentSize" then
		if self.TotalContentLength == 0 then
			return 0
		end
		
		return (self._ViewSize / self.TotalContentLength)
	elseif Index == "RenderedContentScrollPercentSize" then
		local Position = self.Position
		return self.ContentScrollPercentSize * (1-self:GetScale(self:GetTimesOverBounds(Position)))
	elseif Index == "ContentScrollPercent" then
		return (self.Position - self._Min) / (self.TotalContentLength - self._ViewSize)
	elseif Index == "RenderedContentScrollPercent" then
		local Percent = self.ContentScrollPercent
		if Percent < 0 then
			return 0
		elseif Percent > 1 then
			return 1
		else
			return Percent
		end
	elseif Index == "BoundedRenderPosition" then
		local Position = self.Position
		local TimesOverBounds = self:GetTimesOverBounds(Position)
		local Scale = self:GetScale(TimesOverBounds)
		if TimesOverBounds > 0 then
			return -self.ContentMax - Scale*self.BackBounceRenderRange
		elseif TimesOverBounds < 0 then
			return self.ContentMin + Scale*self.BackBounceRenderRange
		else
			return -Position
		end
	elseif Index == "Velocity" then
		return self.Spring.Velocity
	elseif Index == "Target" then
		return self.Spring.Target
	elseif Index == "AtRest" then
		return math.abs(self.Spring.Target - self.Spring.Position) < 1e-5 and math.abs(self.Spring.Velocity) < 1e-5
	elseif Scroller[Index] then
		return Scroller[Index]
	else
		error(("[Scroller] - '%s' is not a valid member"):format(tostring(Index)))
	end
end

function Scroller:__newindex(Index, Value)
	if Scroller[Index] or Index == "Spring" then
		rawset(self, Index, Value)	
	elseif Index == "Min" or Index == "ContentMin" then
		self._Min = Value
	elseif Index == "Max" then
		self._Max = Value
		self.Target = self.Target -- Force update! 
	elseif Index == "TotalContentLength" then
		self.Max = self._Min + Value
	elseif Index == "ViewSize" then
		self._ViewSize = Value
	elseif Index == "Position" then
		self.Spring.Position = Value
	elseif Index == "TargetContentScrollPercent" then
		self.Target = self._Min + Value * (self.TotalContentLength - self._ViewSize)
	elseif Index == "ContentScrollPercent" then
		self.Position = self._Min + Value * (self.TotalContentLength - self._ViewSize)
	elseif Index == "Target" then
		if Value > self.ContentMax then
			Value = self.ContentMax
		elseif Value < self.ContentMin then
			Value = self.ContentMin
		end
		self.Spring.Target = Value
	elseif Index == "Velocity" then
		self.Spring.Velocity = Value
	else
		error(("[Scroller] - '%s' is not a valid member"):format(tostring(Index)))
	end
end


local BaseScroller = {}
BaseScroller.ClassName = "Base"
BaseScroller.__index = BaseScroller

function BaseScroller.new(Gui)
	local self = setmetatable({}, BaseScroller)
	
	self.Maid = MakeMaid()
	self.Gui = Gui or error("No Gui")
	self.Container = self.Gui.Parent or error("No container")
	
	return self
end

function BaseScroller:Destroy()
	self.Maid:DoCleaning()
	self.Maid = nil

	setmetatable(self, nil)
end

local Scrollbar = setmetatable({}, BaseScroller)
Scrollbar.ClassName = "Scrollbar"
Scrollbar.__index = Scrollbar

function Scrollbar.new(Gui, ScrollingFrame)
	local self = setmetatable(BaseScroller.new(Gui), Scrollbar)
		
	self.ScrollingFrame = ScrollingFrame or error("No ScrollingFrame")
	self.ParentScroller = self.ScrollingFrame:GetScroller()
	self:UpdateRender()
	
	self.DraggingBegan = Signal.new()
	
	self.Maid.InputBeganGui = self.Gui.InputBegan:connect(function(InputObject)
		if InputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			self:InputBegan(InputObject)
		end
	end)
	
	self.Maid.InputBeganContainer = self.Container.InputBegan:connect(function(InputObject)
		if InputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			self.LastContainerInputObject = InputObject
		end
	end)
	
	self.Maid.InputEndedContainer = self.Container.InputEnded:connect(function(InputObject)
		if InputObject == self.LastContainerInputObject then
			local ScrollbarSize = self.Container.AbsoluteSize.Y * self.ParentScroller.ContentScrollPercentSize
			local Offset = InputObject.Position.Y - self.Container.AbsolutePosition.Y - ScrollbarSize/2 -- In the middle of the bar
			local Percent = Offset / (self.Container.AbsoluteSize.Y * (1 - self.ParentScroller.ContentScrollPercentSize))
			
			self.ParentScroller.TargetContentScrollPercent = Percent
			self.ParentScroller.Velocity = 0
			self.ScrollingFrame:FreeScroll()
		end
	end)
	
	return self
end

function Scrollbar:StopDrag()
	self.ScrollingFrame:StopDrag()
end

function Scrollbar:InputBegan(InputBeganObject)
	local Maid = MakeMaid()
	
	local StartPosition = InputBeganObject.Position
	local StartPercent = self.ParentScroller.ContentScrollPercent
	local UpdateVelocity = self.ScrollingFrame:GetVelocityTracker(0.25)
	
	Maid.InputChanged = UserInputService.InputChanged:connect(function(InputObject)
		if InputObject.UserInputType == Enum.UserInputType.MouseMovement then
			local Offset = (InputObject.Position - StartPosition).y
			local Percent = Offset / (self.Container.AbsoluteSize.Y * (1 - self.ParentScroller.ContentScrollPercentSize))
			self.ParentScroller.ContentScrollPercent = StartPercent + Percent
			self.ParentScroller.TargetContentScrollPercent = self.ParentScroller.ContentScrollPercent
			
			self.ScrollingFrame:UpdateRender()
			UpdateVelocity()
		end
	end)
	
	Maid.InputEnded = UserInputService.InputEnded:connect(function(InputObject)
		if InputObject == InputBeganObject then
			self:StopDrag()
		end
	end)
	
	self.Maid.UpdateMaid = Maid
	self.ScrollingFrame.Maid.UpdateMaid = Maid
end

function Scrollbar:UpdateRender()
	if self.ParentScroller.TotalContentLength > self.ParentScroller.ViewSize then
		local RenderedContentScrollPercentSize = self.ParentScroller.RenderedContentScrollPercentSize
		self.Gui.Size = UDim2.new(self.Gui.Size.X, UDim.new(RenderedContentScrollPercentSize, 0))
		self.Gui.Position = UDim2.new(self.Gui.Position.X, UDim.new((1-RenderedContentScrollPercentSize) * self.ParentScroller.RenderedContentScrollPercent, 0))
		self.Gui.Visible = true
	else
		self.Gui.Visible = false
	end
end

local ScrollingFrame = setmetatable({}, BaseScroller)
ScrollingFrame.ClassName = "ScrollingFrame"
ScrollingFrame.__index = ScrollingFrame

function ScrollingFrame.new(Gui)
	local self = setmetatable(BaseScroller.new(Gui), ScrollingFrame)

	self.Scrollbars = {}
	self.Scroller = Scroller.new()
	
	self:BindInput(Gui)
	self:BindInput(self.Container)
	
	self.Maid.ContainerChanged = self.Container:GetPropertyChangedSignal("AbsoluteSize"):connect(function()
		self:UpdateScroller()
		self:FreeScroll(true)
	end)
	
	self.Maid.GuiChanged = self.Gui:GetPropertyChangedSignal("AbsoluteSize"):connect(function(Property)
		self:UpdateScroller()
		self:FreeScroll(true)
	end)
	
	self:UpdateScroller()
	self:UpdateRender()

	return self
end

function ScrollingFrame:GetScroller()
	return self.Scroller
end

function ScrollingFrame:AddScrollbar(Gui)
	local Bar = Scrollbar.new(Gui, self)
	table.insert(self.Scrollbars, Bar)
	
	self.Maid[Gui] = Bar
end

function ScrollingFrame:AddScrollbarFromContainer(Container)
	local ScrollBar = Instance.new("ImageButton")
	ScrollBar.Size = UDim2.new(1, 0, 0, 100)
	ScrollBar.Name = "ScrollBar"
	ScrollBar.BackgroundColor3 = Color3.new(0.8, 0.8, 0.8)
	ScrollBar.BorderSizePixel = 0
	ScrollBar.Image = ""
	ScrollBar.Parent = Container
	ScrollBar.AutoButtonColor = false
	ScrollBar.ZIndex = Container.ZIndex
	ScrollBar.Parent = Container
	
	return self:AddScrollbar(ScrollBar)
end

function ScrollingFrame:UpdateScroller()
	self.Scroller.TotalContentLength = self.Gui.AbsoluteSize.y
	self.Scroller.ViewSize = self.Container.AbsoluteSize.y
end

function ScrollingFrame:UpdateRender()	
	self.Gui.Position = UDim2.new(self.Gui.Position.X, UDim.new(0, self.Scroller.BoundedRenderPosition))
	for _, Scrollbar in pairs(self.Scrollbars) do
		Scrollbar:UpdateRender()
	end
end

function ScrollingFrame:StopUpdate()
	self.Maid.UpdateMaid = nil
end

function ScrollingFrame:StopDrag()
	local Position = self.Scroller.Position
	
	if self.Scroller:GetDisplacementPastBounds(self.Scroller.Position) == 0 then
		if self.Scroller.Velocity > 0 then
			self.Scroller.Target = math.max(self.Scroller.Target, self.Scroller.Position + self.Scroller.Velocity * 0.5)
		else
			self.Scroller.Target = math.min(self.Scroller.Target, self.Scroller.Position + self.Scroller.Velocity * 0.5)
		end
	end
	
	self:FreeScroll()
end

function ScrollingFrame:FreeScroll(LowPriority)
	if LowPriority and self.Maid.UpdateMaid then
		return
	end

	local Maid = MakeMaid()
	
	self:UpdateRender()
	Maid.RenderStepped = RunService.RenderStepped:connect(function()
		self:UpdateRender()
		if self.Scroller.AtRest then
			self:StopUpdate()
		end
	end)
	
	self.Maid.UpdateMaid = Maid
end

function ScrollingFrame:GetVelocityTracker(Strength)
	Strength = Strength or 1
	self.Scroller.Velocity = 0
	
	local LastUpdate = tick()
	local LastPosition = self.Scroller.Position

	return function()
		local Position = self.Scroller.Position
		
		local Elapsed = tick() - LastUpdate
		LastUpdate = tick()
		local Delta = LastPosition - Position
		LastPosition = Position
		self.Scroller.Velocity = self.Scroller.Velocity - (Delta / (0.0001 + Elapsed)) * Strength
	end
end

function ScrollingFrame:GetProcessInput(InputBeganObject)
	local Start = self.Scroller.Position
	local UpdateVelocity = self:GetVelocityTracker()
	local OriginalPosition = InputBeganObject.Position

	return function(InputObject)
		local Distance = (InputObject.Position - OriginalPosition).y
		local Position = Start - Distance
		self.Scroller.Position = Position
		self.Scroller.Target = Position
		
		self:UpdateRender()
		UpdateVelocity()
		
		return Distance
	end
end

function ScrollingFrame:ScrollTo(Position, DoNotAnimate)
	self.Scroller.Target = Position
	if DoNotAnimate then
		self.Scroller.Position = self.Scroller.Target
		self.Scroller.Velocity = 0
	end
end

function ScrollingFrame:ScrollToTop(DoNotAnimate)
	self:ScrollTo(self.Scroller.Min, DoNotAnimate)
end

function ScrollingFrame:ScrollToBottom(DoNotAnimate)
	self:ScrollTo(self.Scroller.Max, DoNotAnimate)
end

function ScrollingFrame:BindInput(Gui, Options)
	local Maid = MakeMaid()
	
	Maid.GuiInputBegan = Gui.InputBegan:connect(function(InputObject)
		self:InputBegan(InputObject, Options)
	end)
	
	Maid.GuiInputChanged = Gui.InputChanged:connect(function(InputObject)
		if InputObject.UserInputType == Enum.UserInputType.MouseWheel and Gui.Active then
			self.Scroller.Target = self.Scroller.Target + -InputObject.Position.z * 80 -- We have to be active to avoid scrolling
			self:FreeScroll()
		end
	end)
	
	return Maid
end

function ScrollingFrame:InputBegan(InputBeganObject, Options)
	if InputBeganObject.UserInputType == Enum.UserInputType.MouseButton1 or InputBeganObject.UserInputType == Enum.UserInputType.Touch then
		local Maid = MakeMaid()
		
		local StartTime = tick()
		local TotalScrollDistance = 0
		local ProcessInput = self:GetProcessInput(InputBeganObject)
		
		if InputBeganObject.UserInputType == Enum.UserInputType.MouseButton1 then
			Maid.InputChanged = UserInputService.InputChanged:connect(function(InputObject, GameProcessed)
				if InputObject.UserInputType == Enum.UserInputType.MouseMovement then
					TotalScrollDistance = TotalScrollDistance + math.abs(ProcessInput(InputObject))
				end	
			end)
		elseif InputBeganObject.UserInputType == Enum.UserInputType.Touch then
			local function Update(InputObject, GameProcessed)
				if InputObject.UserInputType == Enum.UserInputType.Touch then
					TotalScrollDistance = TotalScrollDistance + math.abs(ProcessInput(InputObject))
				end	
			end
			
			Maid.InputChanged = UserInputService.InputChanged:connect(Update)
		end
		
		Maid.Cleanup = function()
			self:UpdateRender()
			if Options and Options.OnClick then
				local ElapsedTime = tick() - StartTime
				local ConsideredClick = (ElapsedTime <= 0.05) or (TotalScrollDistance < 1)
				if ConsideredClick then
					Options.OnClick(InputBeganObject)
				end
			end
		end
	
		Maid.InputEnded = UserInputService.InputEnded:connect(function(InputObject, GameProcessed)
			if InputObject == InputBeganObject then
				self:StopDrag()
			end
		end)
		
		Maid.WindowFocusReleased = UserInputService.WindowFocusReleased:connect(function()
			self:StopDrag()
		end)
	
		self.Maid.UpdateMaid = Maid
	end
end

return ScrollingFrame