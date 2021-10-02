--- Contains model information for the current button
-- @classmod ButtonHighlightModel
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local AccelTween = require("AccelTween")
local BaseObject = require("BaseObject")
local StepUtils = require("StepUtils")
local Maid = require("Maid")

local ButtonHighlightModel = setmetatable({}, BaseObject)
ButtonHighlightModel.ClassName = "ButtonHighlightModel"
ButtonHighlightModel.__index = ButtonHighlightModel

function ButtonHighlightModel.new(button, onUpdate)
	local self = setmetatable(BaseObject.new(assert(button, "Bad button")), ButtonHighlightModel)

	self._onUpdate = assert(onUpdate, "No onUpdate")

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

	self._percentHighlighted = AccelTween.new(200)
	self._percentHighlighted.t = 0
	self._percentHighlighted.p = 0

	self._percentChoosen = AccelTween.new(200)
	self._percentChoosen.t = 0
	self._percentChoosen.p = 0

	self._percentPress = AccelTween.new(200)
	self._percentPress.t = 0
	self._percentPress.p = 0

	self._isMouseDown = Instance.new("BoolValue")
	self._isMouseDown.Value = false
	self._maid:GiveTask(self._isMouseDown)

	self._numFingerDown = Instance.new("IntValue")
	self._numFingerDown.Value = 0
	self._maid:GiveTask(self._numFingerDown)

	self._isChoosen = Instance.new("BoolValue")
	self._isChoosen.Value = false
	self._maid:GiveTask(self._isChoosen)

	self._isKeyDown = Instance.new("BoolValue")
	self._isKeyDown.Value = false
	self._maid:GiveTask(self._isKeyDown)

	self._isMouseOver = Instance.new("BoolValue")
	self._isMouseOver.Value = false
	self._maid:GiveTask(self._isMouseOver)

	self.StartAnimation, self._maid._stop = StepUtils.bindToRenderStep(self._update)

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

	self._maid:GiveTask(self._isMouseOver.Changed:Connect(function()
		self:_updatePercentHighlighted()
	end))
	self._maid:GiveTask(self._numFingerDown.Changed:Connect(function()
		self:_updatePercentHighlighted()
	end))

	self._maid:GiveTask(self._isChoosen.Changed:Connect(function()
		self:_updatePercentHighlighted()
	end))

	self._maid:GiveTask(self._isKeyDown.Changed:Connect(function()
		self:_updatePercentHighlighted()
	end))

	self._maid:GiveTask(self.IsSelected.Changed:Connect(function()
		self:_updatePercentHighlighted()
	end))

	self._maid:GiveTask(self._isMouseDown.Changed:Connect(function()
		self:_updatePercentHighlighted()
	end))

	self:_updatePercentHighlighted()

	return self
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

	self._isChoosen.Value = isChoosen
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

function ButtonHighlightModel:_updatePercentHighlighted()
	self.IsMouseOrTouchOver.Value = self._isMouseOver.Value or self._numFingerDown.Value > 0

	local shouldHighlight = self._isChoosen.Value
		or self.IsSelected.Value
		or self._numFingerDown.Value > 0
		or self._isKeyDown.Value
		or self._isMouseOver.Value
		or self._isMouseDown.Value

	self._percentPress.t = (self._isMouseDown.Value or self._isKeyDown.Value or self._numFingerDown.Value > 0) and 1 or 0
	self._percentChoosen.t = self._isChoosen.Value and 1 or 0
	self._percentHighlighted.t = shouldHighlight and 1 or 0

	self:StartAnimation()
end

function ButtonHighlightModel:_update()
	return self._onUpdate(self._percentHighlighted, self._percentChoosen, self._percentPress)
end

return ButtonHighlightModel