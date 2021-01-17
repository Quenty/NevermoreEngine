--- Contains model information for the current button
-- @classmod ButtonHighlightModel
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local AccelTween = require("AccelTween")
local BaseObject = require("BaseObject")
local StepUtils = require("StepUtils")

local ButtonHighlightModel = setmetatable({}, BaseObject)
ButtonHighlightModel.ClassName = "ButtonHighlightModel"
ButtonHighlightModel.__index = ButtonHighlightModel

function ButtonHighlightModel.new(button, onUpdate)
	local self = setmetatable(BaseObject.new(assert(button)), ButtonHighlightModel)

	self._onUpdate = assert(onUpdate, "No onUpdate")

	-- Readonly
	self.InteractionEnabled = Instance.new("BoolValue")
	self.InteractionEnabled.Value = true
	self._maid:GiveTask(self.InteractionEnabled)

	self._percentHighlighted = AccelTween.new(200)
	self._percentHighlighted.t = 0
	self._percentHighlighted.p = 0

	self._percentChoosen = AccelTween.new(200)
	self._percentChoosen.t = 0
	self._percentChoosen.p = 0

	self._percentPress = AccelTween.new(200)
	self._percentPress.t = 0
	self._percentPress.p = 0

	self._isPressed = Instance.new("BoolValue")
	self._isPressed.Value = false
	self._maid:GiveTask(self._isPressed)

	self._isChoosen = Instance.new("BoolValue")
	self._isChoosen.Value = false
	self._maid:GiveTask(self._isChoosen)

	-- readonly
	self.IsSelected = Instance.new("BoolValue")
	self.IsSelected.Value = false
	self._maid:GiveTask(self.IsSelected)

	self._isKeyDown = Instance.new("BoolValue")
	self._isKeyDown.Value = false
	self._maid:GiveTask(self._isKeyDown)

	-- readonly
	self.IsMouseOrTouchOver = Instance.new("BoolValue")
	self.IsMouseOrTouchOver.Value = false
	self._maid:GiveTask(self.IsMouseOrTouchOver)

	self.StartAnimation, self._maid._stop = StepUtils.bindToRenderStep(self._update)

	self._maid:GiveTask(self._obj.InputEnded:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseMovement
		or inputObject.UserInputType == Enum.UserInputType.Touch then
			self.IsMouseOrTouchOver.Value = false
		end

		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			self._isPressed.Value = false
		end
	end))

	self._maid:GiveTask(self._obj.SelectionGained:Connect(function()
		self.IsSelected.Value = true
	end))

	self._maid:GiveTask(self._obj.InputBegan:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseMovement
		or inputObject.UserInputType == Enum.UserInputType.Touch then
			self.IsMouseOrTouchOver.Value = true
		end

		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			self._isPressed.Value = true
		end
	end))

	self._maid:GiveTask(self._obj.SelectionLost:Connect(function()
		self.IsSelected.Value = false
	end))

	self._maid:GiveTask(self._isChoosen.Changed:Connect(function()
		self:_updatePercentHighlighted()
	end))

	self._maid:GiveTask(self._isKeyDown.Changed:Connect(function()
		self:_updatePercentHighlighted()
	end))

	self._maid:GiveTask(self.IsMouseOrTouchOver.Changed:Connect(function()
		self:_updatePercentHighlighted()
	end))

	self._maid:GiveTask(self.IsSelected.Changed:Connect(function()
		self:_updatePercentHighlighted()
	end))

	self._maid:GiveTask(self._isPressed.Changed:Connect(function()
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
	assert(type(interactionEnabled) == "boolean")

	self.InteractionEnabled.Value = interactionEnabled
end

function ButtonHighlightModel:SetIsChoosen(isChoosen)
	assert(type(isChoosen) == "boolean")

	self._isChoosen.Value = isChoosen
end

function ButtonHighlightModel:_updatePercentHighlighted()
	local shouldHighlight = self._isChoosen.Value
		or self.IsMouseOrTouchOver.Value
		or self.IsSelected.Value
		or self._isKeyDown.Value
		or self._isPressed.Value

	self._percentPress.t = (self._isPressed.Value or self._isKeyDown.Value) and 1 or 0
	self._percentChoosen.t = self._isChoosen.Value and 1 or 0
	self._percentHighlighted.t = shouldHighlight and 1 or 0

	self:StartAnimation()
end

function ButtonHighlightModel:_update()
	return self._onUpdate(self._percentHighlighted, self._percentChoosen, self._percentPress)
end

return ButtonHighlightModel