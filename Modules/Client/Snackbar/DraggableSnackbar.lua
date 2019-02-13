--- Snackbar, but draggable
-- @classmod DraggableSnackbar

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players  = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local Snackbar = require("Snackbar")
local qGUI = require("qGUI")

local DraggableSnackbar = setmetatable({}, Snackbar)
DraggableSnackbar.ClassName = "DraggableSnackbar"
DraggableSnackbar.__index = DraggableSnackbar
DraggableSnackbar.Vertical = true
DraggableSnackbar.DefaultFadeOut = "FadeOutDown"
DraggableSnackbar.Duration = 3

-- By default the Snackbar will close automatically if the user types outside or presses the esc key.
DraggableSnackbar.AutoCloseDisabled = false

--- Note that this will not show until :Show() is called
-- @constructor
-- @param [GCOnDismissal] If true, will destroy itself and GC after being dismissed. Defaults to true
-- @param [Options] Table of optional values, adds call to actions, et cetera
function DraggableSnackbar.new(Parent, Text, GCOnDismissal, Options)
	local self = setmetatable(Snackbar.new(Parent, Text, Options), DraggableSnackbar)

	self._visible = false
	self._draggingCoroutine = nil
	self._shouldDismiss = false
	self._showId = 0

	self._mouse = Players.LocalPlayer:GetMouse()
	self._gcOnDismissal = GCOnDismissal == nil and true or false

	-- Set to transparency and faded out direction automatically
	self[self.DefaultFadeOut](self, true)

	return self
end

function DraggableSnackbar:Show()
	if not self._visible then
		self._visible = true
		self:FadeIn()
		local LocalShowId = self._showId + 1
		self._showId = LocalShowId

		-- Connect events
		self._whileActiveMaid:GiveTask(self.Gui.MouseButton1Down:Connect(function(X, Y)
			if self._showId == LocalShowId then
				if not self._draggingCoroutine then
					self:StartTrack(X, Y)
				end
			else
				warn("[DraggingBeginEvent] - self._showId ~= LocalShowId, but event fired")
			end
		end))

		self._whileActiveMaid:GiveTask(UserInputService.InputBegan:Connect(function(InputObject, GameProcessedEvent)
			if GameProcessedEvent then
				return
			end

			if self._showId ~= LocalShowId then
				warn("[InputDismissEvent] - self._showId ~= LocalShowId, but event fired")
				return
			end
			if self.AutoCloseDisabled then
				return
			end

			if qGUI.MouseOver(self._mouse, self.Gui) then
				return
			end

			if self.AbsolutePosition ~= self.Gui.AbsolutePosition then
				return -- Animating / dragging
			end

			if InputObject.UserInputType == Enum.UserInputType.Touch
				or InputObject.UserInputType == Enum.UserInputType.MouseButton1 then

				self:Dismiss()
			end
		end))

		--- Setup hide on dismissal
		delay(self.Duration, function()
			if self.Destroy and self._showId == LocalShowId and self._visible then
				self:Dismiss()
			end
		end)
	end
end

function DraggableSnackbar:StartTrack(X, Y)
	if self.Vertical then
		self._startDragPosition = Y
	else
		self._startDragPosition = X
	end
	self.DragOffset = 0

	local localDraggingCoroutine
	localDraggingCoroutine = coroutine.create(function()
		while self._draggingCoroutine == localDraggingCoroutine do
			self:Track()
			RunService.Stepped:Wait()
		end
	end)
	self._draggingCoroutine = localDraggingCoroutine

	self._whileActiveMaid.DraggingEnded = UserInputService.InputEnded:Connect(function(InputObject)
		if self._draggingCoroutine == localDraggingCoroutine then
			if InputObject.UserInputType.Name == "MouseButton1" then
				self:EndTrack()
			end
		else
			warn("[DraggableSnackbar] - InputEnded fire, but DraggingCoroutine was not the localDraggingCoroutine")
		end
	end)

	self._whileActiveMaid.TouchDraggingEnded = UserInputService.TouchEnded:Connect(function(InputObject)
		if self._draggingCoroutine == localDraggingCoroutine then
			self:EndTrack()
		else
			warn("[DraggableSnackbar] - TouchEnded fire, but DraggingCoroutine was not the localDraggingCoroutine")
		end
	end)

	assert(coroutine.resume(self._draggingCoroutine))
end

function DraggableSnackbar:Track()
	local DragOffset, DragLength
	local TopLeftInset, _ = GuiService:GetGuiInset()

	if self.Vertical then
		DragOffset = (self._mouse.Y + TopLeftInset.Y) - self._startDragPosition
		DragLength = self.Gui.AbsoluteSize.Y

		self.Gui.Position = self.Position + UDim2.new(0, 0, 0, DragOffset)
	else
		DragOffset = (self._mouse.X + TopLeftInset.X) - self._startDragPosition
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
	self._startDragPosition = nil
	self._draggingCoroutine = nil

	-- Cleanup events
	self._whileActiveMaid.DraggingEnded = nil
	self._whileActiveMaid.TouchDraggingEnded = nil

	-- Dismissal if dragged out
	if self._shouldDismiss then
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
	if self._visible then
		if (self._draggingCoroutine) then
			self._shouldDismiss = true
		else
			self._visible = false
			self._shouldDismiss = nil
			self._whileActiveMaid:DoCleaning()

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
			if self._gcOnDismissal then
				self._gcOnDismissal = false -- Make sure this is only called once...
				delay(self.FadeTime, function()
					self:Destroy()
				end)
			end
		end
	else
		warn("[DraggableSnackbar] - Cannot dismiss, already hidden")
	end
end

function DraggableSnackbar:IsVisible()
	return self._visible
end

function DraggableSnackbar:Destroy()
	self.Gui:Destroy()
	self.Gui = nil

	self.TextLabel:Destroy()
	self.TextLabel = nil

	self._whileActiveMaid:DoCleaning()
	self._whileActiveMaid = nil

	self._visible = false
	self._draggingCoroutine = nil

	setmetatable(self, nil)
end

return DraggableSnackbar
