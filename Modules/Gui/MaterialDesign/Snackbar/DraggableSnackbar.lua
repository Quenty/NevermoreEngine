local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players  = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))

local Snackbar = require("Snackbar")
local qGUI = require("qGUI")

--- Snackbar, but draggable
local DraggableSnackbar = setmetatable({}, Snackbar)
DraggableSnackbar.ClassName = "DraggableSnackbar"
DraggableSnackbar.__index = DraggableSnackbar
DraggableSnackbar.Vertical = true
DraggableSnackbar.DefaultFadeOut = "FadeOutDown"
DraggableSnackbar.Duration = 3
DraggableSnackbar.AutoCloseDisabled = false -- By default the Snackbar will close automatically if the user types outside or presses the esc key.

--- Note that this will not show until :Show() is called
-- @param [GCOnDismissal] If true, will destroy itself and GC after being dismissed. Defaults to true
-- @param [Options] Table of optional values, adds call to actions, et cetera
function DraggableSnackbar.new(Parent, Text, GCOnDismissal, Options)
	local self = setmetatable(Snackbar.new(Parent, Text, Options), DraggableSnackbar)

	self.Visible = false
	self.DraggingCoroutine = nil
	self.ShouldDismiss = false
	self.ShowId = 0

	self.Mouse = Players.LocalPlayer:GetMouse()
	self.GCOnDismissal = GCOnDismissal == nil and true or false
	
	-- Set to transparency and faded out direction automatically
	self[self.DefaultFadeOut](self, true)

	return self
end

function DraggableSnackbar:Show()
	if not self.Visible then
		self.Visible = true
		self:FadeIn()
		local LocalShowId = self.ShowId + 1
		self.ShowId = LocalShowId

		-- Connect events
		self.WhileActiveMaid.DraggingBeginEvent = self.Gui.MouseButton1Down:Connect(function(X, Y)
			if self.ShowId == LocalShowId then
				if not self.DraggingCoroutine then
					self:StartTrack(X, Y)
				end
			else
				warn("[DraggingBeginEvent] - self.ShowId ~= LocalShowId, but event fired")
			end
		end)

		self.WhileActiveMaid.InputDismissEvent = UserInputService.InputBegan:Connect(function(InputObject, GameProcessedEvent)
			if GameProcessedEvent then
				return
			end
			
			if self.ShowId ~= LocalShowId then
				warn("[InputDismissEvent] - self.ShowId ~= LocalShowId, but event fired")
				return
			end
			if self.AutoCloseDisabled then
				return
			end
			
			if qGUI.MouseOver(self.Mouse, self.Gui) then
				return
			end
				
			if self.AbsolutePosition ~= self.Gui.AbsolutePosition then
				return -- Animating / dragging
			end
			
			if InputObject.UserInputType == Enum.UserInputType.Touch 
				or InputObject.UserInputType == Enum.UserInputType.MouseButton1 then
				
				self:Dismiss()
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
			RunService.Stepped:Wait()
		end
	end)
	self.DraggingCoroutine = LocalDraggingCoroutine

	self.WhileActiveMaid.DraggingEnded = UserInputService.InputEnded:Connect(function(InputObject)
		if self.DraggingCoroutine == LocalDraggingCoroutine then
			if InputObject.UserInputType.Name == "MouseButton1" then
				self:EndTrack()
			end
		else
			warn("[DraggableSnackbar] - InputEnded fire, but DraggingCoroutine was not the LocalDraggingCoroutine")
		end
	end)

	self.WhileActiveMaid.TouchDraggingEnded = UserInputService.TouchEnded:Connect(function(InputObject)
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

return DraggableSnackbar
