local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local GuiService        = game:GetService("GuiService")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qGUI = LoadCustomLibrary("qGUI")
local MakeMaid = LoadCustomLibrary("Maid").MakeMaid

-- @author Quenty
-- Provides a lightweight feedback on an operation at the base of the screen,
-- that hide after a timeout or user interaction. Only one is visible at once.

-- You'll want to make a SnackbarManager to handle all the construction

local lib = {}

local function MakeDropShadow(Parent, Radius)
	Radius = Radius or 4

	local Gui      = Instance.new("Frame")
	Gui.Size       = UDim2.new(1, Radius*2, 1, Radius*2)
	Gui.Position   = UDim2.new(0, -Radius, 0, -Radius)
	Gui.Name       = "DropShadow"
	Gui.Parent     = Parent
	Gui.ZIndex     = Parent.ZIndex-1
	Gui.FrameStyle = "DropShadow"

	return Gui
end

local function MapNumber(OldValue, OldMin, OldMax, NewMin, NewMax)
	-- Maps a number from one range to another
	-- http://stackoverflow.com/questions/929103/convert-a-number-range-to-another-range-maintaining-ratio
	-- Make sure old range is not 0

	return (((OldValue - OldMin) * (NewMax - NewMin)) / (OldMax - OldMin)) + NewMin
end



-- Snackbars provide lightweight feedback on an operation
-- at the base of the screen. They automatically disappear 
-- after a timeout or user interaction. There can only be
-- one on the screen at a time.

-- Base clase, not functional.
local Snackbar           = {}
Snackbar.ClassName       = "Snackbar"
Snackbar.__index         = Snackbar
Snackbar.Height          = 48
Snackbar.MinimumWidth    = 288 -- Taken from google material design
Snackbar.MaximumWidth    = 700--568
Snackbar.TextWidthOffset = 24
Snackbar.Position        = UDim2.new(1, -10, 1, -10 - Snackbar.Height)
Snackbar.FadeTime        = 0.16
Snackbar.CornerRadius    = 2--24

function Snackbar.new(Parent, Text, Options)
	local self = {}
	setmetatable(self, Snackbar)

	local Gui                  = Instance.new("ImageButton")
	Gui.ZIndex                 = 7
	Gui.Name                   = "Snackbar"
	Gui.Size                   = UDim2.new(0, 100, 0, self.Height)
	Gui.BorderSizePixel        = 0
	Gui.BackgroundColor3       = Color3.new(0.196, 0.196, 0.196) -- Google design specifications
	Gui.Archivable             = false
	Gui.ClipsDescendants       = false
	Gui.Position               = self.Position
	Gui.AutoButtonColor        = false
	Gui.BackgroundTransparency = 1
	self.Gui                   = Gui

	self.BackgroundImages = {qGUI.BackWithRoundedRectangle(Gui, self.CornerRadius, Gui.BackgroundColor3)}
	
	local ShadowRadius = 1
	local ShadowContainer                  = Instance.new("Frame")
	ShadowContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	ShadowContainer.Parent                 = Gui
	ShadowContainer.Name                   = "ShadowContainer"
	ShadowContainer.BackgroundTransparency = 1
	ShadowContainer.Size                   = UDim2.new(1, ShadowRadius*2, 1, ShadowRadius*2)
	ShadowContainer.Archivable             = false
	ShadowContainer.Position = UDim2.new(0.5, 0, 0.5, 0)--UDim2.new(0, -ShadowRadius, 0, -ShadowRadius + 2)
	--ShadowContainer.Style = Enum.FrameStyle.DropShadow
	
	--- Image is blurred at 
	self.ShadowImages = {qGUI.AddNinePatch(ShadowContainer, "rbxassetid://191838004", Vector2.new(150, 150), self.CornerRadius + ShadowRadius, "ImageLabel")}

	for _, Item in pairs(self.ShadowImages) do
		Item.ImageTransparency = 0.74
		Item.ZIndex = Gui.ZIndex - 2
	end

	for _, Item in pairs(self.BackgroundImages) do
		Item.ZIndex = Gui.ZIndex - 1
	end

	local TextLabel                  = Instance.new("TextLabel")
	TextLabel.Size                   = UDim2.new(1, -self.TextWidthOffset*2, 0, 16)
	TextLabel.Position               = UDim2.new(0, self.TextWidthOffset, 0, 16)
	TextLabel.TextXAlignment         = Enum.TextXAlignment.Left
	TextLabel.TextYAlignment         = Enum.TextYAlignment.Center
	TextLabel.Name                   = "SnackbarLabel"
	TextLabel.TextTransparency       = 0.87
	TextLabel.TextColor3             = Color3.new(1, 1, 1)
	TextLabel.BackgroundTransparency = 1
	TextLabel.BorderSizePixel        = 0
	TextLabel.Font                   = Enum.Font.SourceSans--"Arial"
	TextLabel.Text                   = Text
	TextLabel.FontSize               = Enum.FontSize.Size18
	TextLabel.ZIndex                 = Gui.ZIndex-1
	TextLabel.Parent = Gui
	self.TextLabel                   = TextLabel
	
	self.WhileActiveMaid = MakeMaid()
	self.Gui.Parent = Parent
	
	local CallToActionText
	if Options and Options.CallToAction then
		CallToActionText = (type(Options.CallToAction) == "string" and Options.CallToAction or tostring(Options.CallToAction.Text)):upper()
		local DefaultTextColor3 = Color3.new(78/255,205/255,196/255)
		
		local Button = Instance.new("TextButton")
		Button.Name = "CallToActionButton"
		Button.AnchorPoint = Vector2.new(1, 0.5)
		Button.BackgroundTransparency = 1
		Button.Position = UDim2.new(1, -self.TextWidthOffset, 0.5, 0)
		Button.Size = UDim2.new(0.5, 0, 0.8, 0)
		Button.Text = CallToActionText
		Button.Font = Enum.Font.SourceSans
		Button.FontSize = TextLabel.FontSize
		--Button.TextScaled = true
		Button.TextXAlignment = Enum.TextXAlignment.Right
		Button.TextColor3 = DefaultTextColor3
		Button.ZIndex = Gui.ZIndex
		Button.Parent = Gui
		
		-- Resize
		Button.Size = UDim2.new(UDim.new(0, Button.TextBounds.X), Button.Size.Y)
		
		self.WhileActiveMaid.CallToActionClick = Button.MouseButton1Click:connect(function()
			if Options.CallToAction.OnClick then
				Options.CallToAction.OnClick()
				self:Dismiss()
			end
		end)
		
		self.WhileActiveMaid[Button.MouseEnter] = Button.MouseEnter:connect(function()
			Button.TextColor3 = DefaultTextColor3:lerp(Color3.new(0, 0, 0), 0.2)
		end)
		
		self.WhileActiveMaid[Button.MouseLeave] = Button.MouseLeave:connect(function()
			Button.TextColor3 = DefaultTextColor3
		end)
		
		self.CallToActionButton = Button
	end
	
	
	local Width = self.TextLabel.TextBounds.X + self.TextWidthOffset*2
	if self.CallToActionButton then
		Width = Width + self.CallToActionButton.Size.X.Offset + self.TextWidthOffset*2
	end
	
	if Width < self.MinimumWidth then
		Width = self.MinimumWidth
	elseif Width > self.MaximumWidth then
		Width = self.MaximumWidth
	end
	
	if CallToActionText then
		self.TextLabel.Text = Text
	end

	self.Gui.Size = UDim2.new(0, Width, 0, self.Height)

	self.Position = self.Position + UDim2.new(0, -Width, 0, 0)
	self.Gui.Position = self.Position
	self.AbsolutePosition = self.Gui.AbsolutePosition
		
	return self
end

function Snackbar:Dismiss()
	error("Not implemented")
end

function Snackbar:SetBackgroundTransparency(Transparency)
	for _, Item in pairs(self.BackgroundImages) do
		Item.ImageTransparency = Transparency
	end
	for _, Item in pairs(self.ShadowImages) do
		Item.ImageTransparency = MapNumber(Transparency, 0, 1, 0.74, 1)
	end
end

function Snackbar:FadeOutTransparency(PercentFaded)
	if PercentFaded then
		-- self.Gui.BackgroundTransparency = MapNumber(PercentFaded, 0, 1, 0, 1)
		self:SetBackgroundTransparency(MapNumber(PercentFaded, 0, 1, 0, 1))
		self.TextLabel.TextTransparency = MapNumber(PercentFaded, 0, 1, 0.13, 1)
		
		if self.CallToActionButton then
			self.CallToActionButton.TextTransparency = PercentFaded
		end
	else
		--[[qGUI.TweenTransparency(self.Gui, {
			BackgroundTransparency = 1;
		}, self.FadeTime, true)--]]
	
		local NewProperties = {
			ImageTransparency = 1;
		}

		for _, Item in pairs(self.BackgroundImages) do
			qGUI.TweenTransparency(Item, NewProperties, self.FadeTime, true)
		end
		for _, Item in pairs(self.ShadowImages) do
			qGUI.TweenTransparency(Item, NewProperties, self.FadeTime, true)
		end

		qGUI.TweenTransparency(self.TextLabel, {
			TextTransparency = 1;
		}, self.FadeTime, true)
		
		if self.CallToActionButton then
			qGUI.TweenTransparency(self.CallToActionButton, {
				TextTransparency = 1;
			}, self.FadeTime, true)
		end
	end
end

function Snackbar:FadeInTransparency(PercentFaded)
	--- Will animate unless given PercentFaded

	if PercentFaded then
		-- self.Gui.BackgroundTransparency = MapNumber(PercentFaded, 0, 1, 1, 0)
		self:SetBackgroundTransparency(MapNumber(PercentFaded, 0, 1, 1, 0))
		self.TextLabel.TextTransparency = MapNumber(PercentFaded, 0, 1, 1, 0.13)
		
		if self.CallToActionButton then
			self.CallToActionButton.TextTransparency = PercentFaded
		end
	else
		-- Should be an ease-in-out transparency fade.
		--[[qGUI.TweenTransparency(self.Gui, {
			BackgroundTransparency = 0;
		}, self.FadeTime, true)--]]
		local NewProperties = {
			ImageTransparency = 0;
		}
		for _, Item in pairs(self.BackgroundImages) do
			qGUI.TweenTransparency(Item, NewProperties, self.FadeTime, true)
		end

		local NewProperties = {
			ImageTransparency = 0.74;
		}
		for _, Item in pairs(self.ShadowImages) do
			qGUI.TweenTransparency(Item, NewProperties, self.FadeTime, true)
		end

		qGUI.TweenTransparency(self.TextLabel, {
			TextTransparency = 0.13;
		}, self.FadeTime, true)
		
		if self.CallToActionButton then
			qGUI.TweenTransparency(self.CallToActionButton, {
				TextTransparency = 0;
			}, self.FadeTime, true)
		end
	end
end

function Snackbar:FadeHandler(NewPosition, DoNotAnimate, IsFadingOut)
	-- Utility function

	assert(NewPosition, "[Snackbar] - Internal function should not have been called. Missing NewPosition")
	
	if IsFadingOut then
		self:FadeOutTransparency(DoNotAnimate and 1 or nil)
	else
		self:FadeInTransparency(DoNotAnimate and 1 or nil)
	end

	if DoNotAnimate then
		self.Gui.Position = NewPosition
	else
		self.Gui:TweenPosition(NewPosition, "InOut", "Quad", self.FadeTime, true)
	end
end

function Snackbar:FadeOutUp(DoNotAnimate)
	local NewPosition = self.Position + UDim2.new(0, 0, 0, -self.Gui.AbsoluteSize.Y)
	self:FadeHandler(NewPosition, DoNotAnimate, true)
end

function Snackbar:FadeOutDown(DoNotAnimate)
	local NewPosition = self.Position + UDim2.new(0, 0, 0, self.Gui.AbsoluteSize.Y)
	self:FadeHandler(NewPosition, DoNotAnimate, true)
end

function Snackbar:FadeOutRight(DoNotAnimate)
	local NewPosition = self.Position + UDim2.new(0, self.Gui.AbsoluteSize.X, 0, 0)
	self:FadeHandler(NewPosition, DoNotAnimate, true)
end

function Snackbar:FadeOutLeft(DoNotAnimate)
	local NewPosition = self.Position + UDim2.new(0, -self.Gui.AbsoluteSize.X, 0, 0)
	self:FadeHandler(NewPosition, DoNotAnimate, true)
end

function Snackbar:FadeIn(DoNotAnimate)
	self:FadeHandler(self.Position, DoNotAnimate, false)
end





local DraggableSnackbar = {}
DraggableSnackbar.ClassName = "DraggableSnackbar"
DraggableSnackbar.__index = DraggableSnackbar
setmetatable(DraggableSnackbar, Snackbar)

DraggableSnackbar.Vertical = true
DraggableSnackbar.DefaultFadeOut = "FadeOutDown"
DraggableSnackbar.Duration = 3
DraggableSnackbar.AutoCloseDisabled = false -- By default the Snackbar will close automatically if
-- the user types outside or presses the esc key.

function DraggableSnackbar.new(Parent, Text, GCOnDismissal, Options)
	--- Note that this will not show until :Show() is called
	-- @param [GCOnDismissal] If true, will destroy itself and GC after being dismissed. Defaults to true
	-- @param [Options] Table of optional values, adds call to actions, et cetera
	
	local self = Snackbar.new(Parent, Text, Options)
	setmetatable(self, DraggableSnackbar)

	self.Visible = false
	self.DraggingCoroutine = nil
	self.ShouldDismiss = false
	self.ShowId = 0

	self.Mouse = Players.LocalPlayer:GetMouse()
	self.GCOnDismissal = GCOnDismissal == nil and true or false
	
	-- Set to transparency and faded out direction automatically
	self[self.DefaultFadeOut](self, true)
	-- self:Show()

	return self
end

function DraggableSnackbar:Show()
	if not self.Visible then
		self.Visible = true
		self:FadeIn()
		local LocalShowId = self.ShowId + 1
		self.ShowId = LocalShowId

		-- Connect events
		self.WhileActiveMaid.DraggingBeginEvent = self.Gui.MouseButton1Down:connect(function(X, Y)
			if self.ShowId == LocalShowId then
				if not self.DraggingCoroutine then
					self:StartTrack(X, Y)
				end
			else
				warn("[DraggingBeginEvent] - self.ShowId ~= LocalShowId, but event fired")
			end
		end)

		self.WhileActiveMaid.InputDismissEvent = UserInputService.InputBegan:connect(function(InputObject)
			local UserInputTypeName = InputObject.UserInputType.Name

			if self.ShowId == LocalShowId then
				if not self.AutoCloseDisabled then
					if not qGUI.MouseOver(self.Mouse, self.Gui) then
						if self.AbsolutePosition == self.Gui.AbsolutePosition then
							if UserInputTypeName == "Touch" or UserInputTypeName == "MouseButton1" then
								self:Dismiss()
							end
						end
					end
				end
			else
				warn("[InputDismissEvent] - self.ShowId ~= LocalShowId, but event fired")
			end
		end)

		--- Setup hide on dismissal
		delay(self.Duration, function()
			if self.Destroy and self.ShowId == LocalShowId and self.Visible then
				self:Dismiss()
			end
		end)
	end
end


function DraggableSnackbar:StartTrack(X, Y)
	if self.Vertical then
		self.StartDragPosition = Y
	else
		self.StartDragPosition = X
	end
	self.DragOffset = 0

	local LocalDraggingCoroutine
	LocalDraggingCoroutine = coroutine.create(function()
		while self.DraggingCoroutine == LocalDraggingCoroutine do
			self:Track()
			RunService.RenderStepped:wait()
		end
	end)
	self.DraggingCoroutine = LocalDraggingCoroutine

	self.WhileActiveMaid.DraggingEnded = UserInputService.InputEnded:connect(function(InputObject)
		if self.DraggingCoroutine == LocalDraggingCoroutine then
			if InputObject.UserInputType.Name == "MouseButton1" then
				self:EndTrack()
			end
		else
			warn("[DraggableSnackbar] - InputEnded fire, but DraggingCoroutine was not the LocalDraggingCoroutine")
		end
	end)

	self.WhileActiveMaid.TouchDraggingEnded = UserInputService.TouchEnded:connect(function(InputObject)
		if self.DraggingCoroutine == LocalDraggingCoroutine then
			self:EndTrack()
		else
			warn("[DraggableSnackbar] - TouchEnded fire, but DraggingCoroutine was not the LocalDraggingCoroutine")
		end
	end)

	assert(coroutine.resume(self.DraggingCoroutine))
end

function DraggableSnackbar:Track()
	local DragOffset, DragLength
	local TopLeftInset, BottomRightInset = GuiService:GetGuiInset()
	
	if self.Vertical then
		DragOffset = (self.Mouse.Y + TopLeftInset.Y) - self.StartDragPosition
		DragLength = self.Gui.AbsoluteSize.Y

		self.Gui.Position = self.Position + UDim2.new(0, 0, 0, DragOffset)
	else
		DragOffset = (self.Mouse.X + TopLeftInset.X) - self.StartDragPosition
		DragLength = self.Gui.AbsoluteSize.Y

		self.Gui.Position = self.Position + UDim2.new(0, DragOffset, 0, 0)
	end

	local PercentFaded = math.abs(DragOffset) / DragLength
	if PercentFaded > 1 then
		PercentFaded = 1
	elseif PercentFaded < 0 then
		PercentFaded = 0
	end

	self:FadeOutTransparency(PercentFaded)
end

function DraggableSnackbar:GetOffsetXY()
	local Offset = self.Gui.AbsolutePosition - self.AbsolutePosition
	return Offset
end

function DraggableSnackbar:EndTrack()
	self.StartDragPosition = nil
	self.DraggingCoroutine = nil

	-- Cleanup events
	self.WhileActiveMaid.DraggingEnded = nil
	self.WhileActiveMaid.TouchDraggingEnded = nil

	-- Dismissal if dragged out
	if self.ShouldDismiss then
		self:Dismiss()
	else
		local OffsetXY = self:GetOffsetXY()
		local SizeXY = self.Gui.AbsoluteSize

		if math.abs(OffsetXY.X) >= SizeXY.X or math.abs(OffsetXY.Y) >= SizeXY.Y then
			self:Dismiss()
		else
			self:FadeIn()
		end
	end
end

function DraggableSnackbar:Dismiss()
	if self.Visible then
		if (self.DraggingCoroutine) then
			self.ShouldDismiss = true
		else
			self.Visible = false
			self.ShouldDismiss = nil
			self.WhileActiveMaid:DoCleaning()

			local OffsetXY = self:GetOffsetXY()
			-- Determine what direction to fade out...
			if OffsetXY.X > 0 then
				self:FadeOutRight()
			elseif OffsetXY.X < 0 then
				self:FadeOutLeft()
			elseif OffsetXY.Y > 0 then
				self:FadeOutUp()
			elseif OffsetXY.Y < 0 then
				self:FadeOutDown()
			else
				self[self.DefaultFadeOut](self)
			end

			-- GC stuff
			if self.GCOnDismissal then
				self.GCOnDismissal = false -- Make sure this is only called once...
				delay(self.FadeTime, function()
					self:Destroy()
				end)
			end
		end
	else
		error("[DraggableSnackbar] - Cannot dismiss, already hidden")
	end
end

function DraggableSnackbar:Destroy()
	self.Gui:Destroy()
	self.Gui = nil

	self.TextLabel:Destroy()
	self.TextLabel = nil

	self.WhileActiveMaid:DoCleaning()
	self.WhileActiveMaid = nil

	self.Visible = false
	self.DraggingCoroutine = nil

	setmetatable(self, nil)
end
lib.DraggableSnackbar = DraggableSnackbar




local SnackbarManager = {}
SnackbarManager.ClassName = "SnackbarManager"
SnackbarManager.__index = SnackbarManager

-- Guarantees that only one snackbar is visible at once
function SnackbarManager.new()
	local self = {}
	setmetatable(self, SnackbarManager)

	self.CurrentSnackbar = nil

	return self
end

function SnackbarManager:ShowSnackbar(Snackbar)
	-- Cleanup existing snackbar

	assert(Snackbar, "Must send a Snackbar")

	if self.CurrentSnackbar == Snackbar and self.CurrentSnackbar.Visible then
		Snackbar:Dismiss()
	else
		local DismissedSnackbar = false

		if self.CurrentSnackbar then
			if self.CurrentSnackbar.Visible then
				self.CurrentSnackbar:Dismiss()
				self.CurrentSnackbar = nil
				DismissedSnackbar = true
			end
		end

		self.CurrentSnackbar = Snackbar
		if DismissedSnackbar then
			delay(Snackbar.FadeTime, function()
				if self.CurrentSnackbar == Snackbar then
					Snackbar:Show()
				end
			end)
		else
			Snackbar:Show()
		end
	end
end

function SnackbarManager:MakeSnackbar(Parent, Text, Options)
	-- Automatically makes a snackbar and then adds it.

	local NewSnackbar = DraggableSnackbar.new(Parent, Text, nil, Options)
	self:ShowSnackbar(NewSnackbar)
end
lib.SnackbarManager = SnackbarManager


return lib