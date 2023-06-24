--[=[
	@class ColorPickerInput
]=]

local require = require(script.Parent.loader).load(script)

local UserInputService = game:GetService("UserInputService")

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local InputObjectUtils = require("InputObjectUtils")
local ValueObject = require("ValueObject")

local ColorPickerInput = setmetatable({}, BaseObject)
ColorPickerInput.ClassName = "ColorPickerInput"
ColorPickerInput.__index = ColorPickerInput

function ColorPickerInput.new()
	local self = setmetatable(BaseObject.new(), ColorPickerInput)

	self._isMouseDown = Instance.new("BoolValue")
	self._isMouseDown.Value = false
	self._maid:GiveTask(self._isMouseDown)

	self._numFingerDown = Instance.new("IntValue")
	self._numFingerDown.Value = 0
	self._maid:GiveTask(self._numFingerDown)

	self._currentPosition = ValueObject.new(Vector2.zero, "Vector2")
	self._maid:GiveTask(self._currentPosition)

	self._activePositions = {}

	self._isPressed = Instance.new("BoolValue")
	self._isPressed.Value = false
	self._maid:GiveTask(self._isPressed)

	self._maid:GiveTask(self._isMouseDown.Changed:Connect(function()
		self:_updateIsPressed()
	end))
	self._maid:GiveTask(self._numFingerDown.Changed:Connect(function()
		self:_updateIsPressed()
	end))

	self.PositionChanged = self._currentPosition.Changed
	self.IsPressedChanged = self._isPressed.Changed

	return self
end

function ColorPickerInput:GetIsPressedValue()
	return self._isPressed
end

function ColorPickerInput:GetPosition()
	return self._currentPosition.Value
end

function ColorPickerInput:GetIsPressed()
	return self._isPressed.Value
end

function ColorPickerInput:SetButton(button)
	if not button then
		self._maid._button = nil
		return
	end

	local maid = Maid.new()

	maid:GiveTask(button.InputBegan:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			self._isMouseDown.Value = true
			self._activePositions.mouse = self:_toButtonSpace(button, inputObject.Position)
			self:_updateCurrentPosition()
		end

		if inputObject.UserInputType == Enum.UserInputType.Touch then
			self:_trackTouch(maid, button, inputObject)
		end
	end))

	maid:GiveTask(button.InputEnded:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			self._isMouseDown.Value = false
		end

		if inputObject.UserInputType == Enum.UserInputType.Touch then
			self:_stopTouchTrack(maid, inputObject)
		end
	end))

	maid:GiveTask(UserInputService.InputEnded:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			self._isMouseDown.Value = false
		end
	end))

	maid:GiveTask(function()
		self._isMouseDown.Value = false
	end)

	maid:GiveTask(self._isMouseDown.Changed:Connect(function()
		self:_updateMouseTracking(maid, button)
	end))

	self._maid._button = maid
end

function ColorPickerInput:_updateIsPressed()
	if self._numFingerDown.Value > 0 or self._isMouseDown.Value then
		self._isPressed.Value = true
	else
		self._isPressed.Value = false
	end
end

function ColorPickerInput:_updateMouseTracking(buttonMaid, button)
	if not self._isMouseDown.Value then
		buttonMaid._mouse = nil
		return
	end

	local maid = Maid.new()

	maid:GiveTask(UserInputService.InputChanged:Connect(function(inputObject)
		if not InputObjectUtils.isMouseUserInputType(inputObject.UserInputType) then
			return
		end

		local screenGui = button:FindFirstAncestorWhichIsA("ScreenGui")
		if not screenGui then
			return
		end

		if not (screenGui:FindFirstAncestorWhichIsA("PlayerGui") or screenGui:FindFirstAncestorWhichIsA("CoreGui")) then
			-- TODO: Handle billboard guis
			return
		end

		self._activePositions.mouse = self:_toButtonSpace(button, inputObject.Position)
		self:_updateCurrentPosition()
	end))

	maid:GiveTask(button.InputChanged:Connect(function(inputObject)
		if InputObjectUtils.isMouseUserInputType(inputObject.UserInputType) then
			self._activePositions.mouse = self:_toButtonSpace(button, inputObject.Position)
			self:_updateCurrentPosition()
		end
	end))

	maid:GiveTask(function()
		self._activePositions.mouse = nil
		self:_updateCurrentPosition()
	end)

	buttonMaid._mouse = maid
end

function ColorPickerInput:_trackTouch(buttonMaid, button, inputObject)
	buttonMaid[inputObject] = nil

	if inputObject.UserInputState == Enum.UserInputState.End then
		return
	end

	local maid = Maid.new()

	self._activePositions[inputObject] = self:_toButtonSpace(button, inputObject.Position)
	self._numFingerDown.Value = self._numFingerDown.Value + 1

	maid:GiveTask(inputObject:GetPropertyChangedSignal("Position"):Connect(function()
		self._activePositions[inputObject] = self:_toButtonSpace(button, inputObject.Position)
		self:_updateCurrentPosition()
	end))
	maid:GiveTask(inputObject:GetPropertyChangedSignal("UserInputState"):Connect(function()
		if inputObject.UserInputState == Enum.UserInputState.End then
			maid[inputObject] = nil
		end
	end))

	maid:GiveTask(function()
		self._activePositions[inputObject] = nil
		self._numFingerDown.Value = self._numFingerDown.Value - 1
		self:_updateCurrentPosition()
	end)

	self:_updateCurrentPosition()

	maid[inputObject] = maid
end

function ColorPickerInput:_stopTouchTrack(buttonMaid, inputObject)
	-- Clears the input tracking as we slide off the button
	buttonMaid[inputObject] = nil
end

function ColorPickerInput:_toButtonSpace(button, position)
	local pos = button.AbsolutePosition
	local size = button.AbsoluteSize

	local result = (Vector2.new(position.x, position.y) - pos)/size
	return Vector2.new(math.clamp(result.x, 0, 1), math.clamp(result.y, 0, 1))
end

function ColorPickerInput:_updateCurrentPosition()
	local current = Vector2.zero
	local count = 0
	for _, item in pairs(self._activePositions) do
		current = current + item
		count = count + 1
	end
	if count == 0 then
		return
	end

	current = current/count
	self._currentPosition.Value = current
end

return ColorPickerInput