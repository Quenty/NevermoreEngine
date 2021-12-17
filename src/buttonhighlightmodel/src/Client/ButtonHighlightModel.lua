--- Contains model information for the current button
-- @classmod ButtonHighlightModel
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local AccelTween = require("AccelTween")
local BaseObject = require("BaseObject")
local StepUtils = require("StepUtils")
local Maid = require("Maid")
local Blend = require("Blend")
local Rx = require("Rx")

local ButtonHighlightModel = setmetatable({}, BaseObject)
ButtonHighlightModel.ClassName = "ButtonHighlightModel"
ButtonHighlightModel.__index = ButtonHighlightModel

function ButtonHighlightModel.new(button, onUpdate)
	local self = setmetatable(BaseObject.new(assert(button, "Bad button")), ButtonHighlightModel)

	self._onUpdate = onUpdate

	-- Readonly
	self.InteractionEnabled = Instance.new("BoolValue")
	self.InteractionEnabled.Value = true
	self._maid:GiveTask(self.InteractionEnabled)

	-- readonly
	self.IsSelected = Instance.new("BoolValue")
	self.IsSelected.Value = false
	self._maid:GiveTask(self.IsSelected)

	-- readonly
	self.IsMouseOrTouchOver = Instance.new("BoolValue")
	self.IsMouseOrTouchOver.Value = false
	self._maid:GiveTask(self.IsMouseOrTouchOver)

	self._isMouseDown = Instance.new("BoolValue")
	self._isMouseDown.Value = false
	self._maid:GiveTask(self._isMouseDown)

	self._numFingerDown = Instance.new("IntValue")
	self._numFingerDown.Value = 0
	self._maid:GiveTask(self._numFingerDown)

	-- readonly
	self.IsChoosen = Instance.new("BoolValue")
	self.IsChoosen.Value = false
	self._maid:GiveTask(self.IsChoosen)

	self._isKeyDown = Instance.new("BoolValue")
	self._isKeyDown.Value = false
	self._maid:GiveTask(self._isKeyDown)

	self._isMouseOver = Instance.new("BoolValue")
	self._isMouseOver.Value = false
	self._maid:GiveTask(self._isMouseOver)

	-- readonly
	self.IsHighlighted = Instance.new("BoolValue")
	self.IsHighlighted.Value = false
	self._maid:GiveTask(self.IsHighlighted)

	-- readonly
	self.IsPressed = Instance.new("BoolValue")
	self.IsPressed.Value = false
	self._maid:GiveTask(self.IsPressed)

	self._maid:GiveTask(self._obj.InputEnded:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
			self._isMouseOver.Value = false
		end

		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			self._isMouseDown.Value = false
		end

		if inputObject.UserInputType == Enum.UserInputType.Touch then
			self:_stopTouchTrack(inputObject)
		end
	end))

	self._maid:GiveTask(self._obj.SelectionGained:Connect(function()
		self.IsSelected.Value = true
	end))

	self._maid:GiveTask(self._obj.SelectionLost:Connect(function()
		self.IsSelected.Value = false
	end))

	self._maid:GiveTask(self._obj.InputBegan:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
			self._isMouseOver.Value = true
		end

		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			self._isMouseDown.Value = true
		end

		if inputObject.UserInputType == Enum.UserInputType.Touch then
			self:_trackTouch(inputObject)
		end
	end))

	-- Legacy update stepping mode
	if self._onUpdate then
		self._percentHighlightedAccelTween = AccelTween.new(200)
		self._percentHighlightedAccelTween.t = 0
		self._percentHighlightedAccelTween.p = 0

		self._maid:GiveTask(self.IsHighlighted.Changed:Connect(function()
			self._percentHighlightedAccelTween.t = self.IsHighlighted.Value and 1 or 0
			self:StartAnimation()
		end))

		self._percentChoosenAccelTween = AccelTween.new(200)
		self._percentChoosenAccelTween.t = 0
		self._percentChoosenAccelTween.p = 0

		self._maid:GiveTask(self.IsChoosen.Changed:Connect(function()
			self._percentChoosenAccelTween.t = self.IsChoosen.Value and 1 or 0
			self:StartAnimation()
		end))

		self._percentPressAccelTween = AccelTween.new(200)
		self._percentPressAccelTween.t = 0
		self._percentPressAccelTween.p = 0

		self._maid:GiveTask(self.IsPressed.Changed:Connect(function()
			self._percentPressAccelTween.t = self.IsPressed.Value and 1 or 0
			self:StartAnimation()
		end))

		self.StartAnimation, self._maid._stop = StepUtils.bindToRenderStep(self._update)
		self:StartAnimation()
	end

	self._maid:GiveTask(self._isMouseOver.Changed:Connect(function()
		self:_updateTargets()
	end))
	self._maid:GiveTask(self._numFingerDown.Changed:Connect(function()
		self:_updateTargets()
	end))

	self._maid:GiveTask(self.IsChoosen.Changed:Connect(function()
		self:_updateTargets()
	end))

	self._maid:GiveTask(self._isKeyDown.Changed:Connect(function()
		self:_updateTargets()
	end))

	self._maid:GiveTask(self.IsSelected.Changed:Connect(function()
		self:_updateTargets()
	end))

	self._maid:GiveTask(self._isMouseDown.Changed:Connect(function()
		self:_updateTargets()
	end))
	self:_updateTargets()

	return self
end

function ButtonHighlightModel:ObservePercentPressed()
	return Blend.AccelTween(Blend.toPropertyObservable(self.IsPressed)
		:Pipe({
			Rx.map(function(value)
				return value and 1 or 0
			end);
		}), 200)
end

function ButtonHighlightModel:ObservePercentHiglighted()
	return Blend.AccelTween(Blend.toPropertyObservable(self.IsHighlighted)
		:Pipe({
			Rx.map(function(value)
				return value and 1 or 0
			end);
		}), 200)
end

function ButtonHighlightModel:ObservePercentChoosen()
	return Blend.AccelTween(Blend.toPropertyObservable(self.IsChoosen)
		:Pipe({
			Rx.map(function(value)
				return value and 1 or 0
			end);
		}), 200)
end

function ButtonHighlightModel:IsInteractionEnabled()
	return self.InteractionEnabled.Value
end

function ButtonHighlightModel:SetKeyDown(isKeyDown)
	self._isKeyDown.Value = isKeyDown
end

function ButtonHighlightModel:SetInteractionEnabled(interactionEnabled)
	assert(type(interactionEnabled) == "boolean", "Bad interactionEnabled")

	self.InteractionEnabled.Value = interactionEnabled
end

function ButtonHighlightModel:SetIsChoosen(isChoosen)
	assert(type(isChoosen) == "boolean", "Bad isChoosen")

	self.IsChoosen.Value = isChoosen
end

function ButtonHighlightModel:_trackTouch(inputObject)
	if inputObject.UserInputState == Enum.UserInputState.End then
		return
	end

	local maid = Maid.new()
	self._maid[inputObject] = nil

	self._numFingerDown.Value = self._numFingerDown.Value + 1
	maid:GiveTask(function()
		self._numFingerDown.Value = self._numFingerDown.Value - 1
	end)
	maid:GiveTask(inputObject:GetPropertyChangedSignal("UserInputState"):Connect(function()
		if inputObject.UserInputState == Enum.UserInputState.End then
			self._maid[inputObject] = nil
		end
	end))

	self._maid[inputObject] = maid
end

function ButtonHighlightModel:_stopTouchTrack(inputObject)
	-- Clears the input tracking as we slide off the button
	self._maid[inputObject] = nil
end

function ButtonHighlightModel:_updateTargets()
	self.IsMouseOrTouchOver.Value = self._isMouseOver.Value or self._numFingerDown.Value > 0
	self.IsPressed.Value = (self._isMouseDown.Value or self._isKeyDown.Value or self._numFingerDown.Value > 0)
	self.IsHighlighted.Value = self.IsChoosen.Value
		or self.IsSelected.Value
		or self._numFingerDown.Value > 0
		or self._isKeyDown.Value
		or self._isMouseOver.Value
		or self._isMouseDown.Value
end

function ButtonHighlightModel:_update()
	return self._onUpdate(self._percentHighlightedAccelTween, self._percentChoosenAccelTween, self._percentPressAccelTween)
end

return ButtonHighlightModel