--[=[
	Contains model information for the current button.

	Usage with Blend!

	```lua
	function Button.new()
		local self = setmetatable(BaseObject.new(), Button)

		-- Store the button model in the actual button so we can ensure it cleans up
		-- this assumes only one render. We can also construct it in the Button.Render

		self._buttonModel = ButtonHighlightModel.new()
		self._maid:GiveTask(self._buttonModel)

		return self
	end

	function Button:Render()
		...
		return Blend.New "ImageButton" {
			...
			[Blend.Instance] = function(button)
				self._buttonModel:SetButton(button)
			end;
			BackgroundTransparency = Blend.Computed(self._buttonModel:ObservePercentPressed(), function(pressed)
				return 1 - pressed
			end);
		}
	end
	```

	@class ButtonHighlightModel
]=]

local require = require(script.Parent.loader).load(script)

local AccelTween = require("AccelTween")
local BaseObject = require("BaseObject")
local Blend = require("Blend")
local Maid = require("Maid")
local Rx = require("Rx")
local StepUtils = require("StepUtils")
local ValueObject = require("ValueObject")
local RectUtils = require("RectUtils")
local RxInstanceUtils = require("RxInstanceUtils")

local ButtonHighlightModel = setmetatable({}, BaseObject)
ButtonHighlightModel.ClassName = "ButtonHighlightModel"
ButtonHighlightModel.__index = ButtonHighlightModel

--[=[
	A model that dictates the current state of a button.
	@param button? GuiBase
	@param onUpdate function?
	@return ButtonHighlightModel
]=]
function ButtonHighlightModel.new(button, onUpdate)
	local self = setmetatable(BaseObject.new(), ButtonHighlightModel)

	self._onUpdate = onUpdate

	self._interactionEnabled = self._maid:Add(ValueObject.new(true, "boolean"))
	self._isSelected = self._maid:Add(ValueObject.new(false, "boolean"))
	self._isMouseOrTouchOver = self._maid:Add(ValueObject.new(false, "boolean"))
	self._isMouseDown = self._maid:Add(ValueObject.new(false, "boolean"))
	self._numFingerDown = self._maid:Add(ValueObject.new(0, "number"))
	self._isChoosen = self._maid:Add(ValueObject.new(false, "boolean"))
	self._isMouseOver = self._maid:Add(ValueObject.new(false, "boolean"))
	self._isKeyDown = self._maid:Add(ValueObject.new(false, "boolean"))
	self._isHighlighted = self._maid:Add(ValueObject.new(false, "boolean"))

	-- Mouse state
	self._isMouseOverBasedUponMouseMovement = self._maid:Add(ValueObject.new(false, "boolean"))
	self._isMouseOverScrollingCheck = self._maid:Add(ValueObject.new(false, "boolean"))
	self._lastMousePositionForScrollingCheck = self._maid:Add(ValueObject.new(nil))

--[=[
	@prop InteractionEnabledChanged Signal<boolean>
	@readonly
	@within ButtonHighlightModel
]=]
	self.InteractionEnabledChanged = self._interactionEnabled.Changed

--[=[
	@prop IsSelectedChanged Signal<boolean>
	@readonly
	@within ButtonHighlightModel
]=]
	self.IsSelectedChanged = self._isSelected.Changed

--[=[
	@prop IsMouseOrTouchOverChanged Signal<boolean>
	@readonly
	@within ButtonHighlightModel
]=]
	self.IsMouseOrTouchOverChanged = self._isMouseOrTouchOver.Changed

--[=[
	@prop IsHighlightedChanged Signal<boolean>
	@readonly
	@within ButtonHighlightModel
]=]
	self.IsHighlightedChanged = self._isHighlighted.Changed

	self._isPressed = self._maid:Add(ValueObject.new(false))

--[=[
	@prop IsPressedChanged Signal<boolean>
	@readonly
	@within ButtonHighlightModel
]=]
	self.IsPressedChanged = self._isPressed.Changed

	-- Legacy update stepping mode
	if self._onUpdate then
		self:_setupLegacySteppedMode()
	end

	self._maid:GiveTask(self._isMouseOver.Changed:Connect(function()
		self:_updateTargets()
	end))
	self._maid:GiveTask(self._numFingerDown.Changed:Connect(function()
		self:_updateTargets()
	end))

	self._maid:GiveTask(self._isChoosen.Changed:Connect(function()
		self:_updateTargets()
	end))

	self._maid:GiveTask(self._isKeyDown.Changed:Connect(function()
		self:_updateTargets()
	end))

	self._maid:GiveTask(self._isSelected.Changed:Connect(function()
		self:_updateTargets()
	end))

	self._maid:GiveTask(self._isMouseDown.Changed:Connect(function()
		self:_updateTargets()
	end))
	self:_updateTargets()

	if button then
		self:SetButton(button)
	end

	return self
end

--[=[
	Sets the button for the highlight model.
	@param button
]=]
function ButtonHighlightModel:SetButton(button: Instance)
	assert(typeof(button) == "Instance" or button == nil, "Bad button")

	local maid = Maid.new()

	if button then
		maid:GiveTask(button.InputEnded:Connect(function(inputObject)
			if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
				self._lastMousePositionForScrollingCheck.Value = inputObject.Position
				self._isMouseOverBasedUponMouseMovement.Value = false
			end

			if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
				self._isMouseDown.Value = false
			end

			if inputObject.UserInputType == Enum.UserInputType.Touch then
				self:_stopTouchTrack(inputObject)
			end
		end))

		maid:GiveTask(button.SelectionGained:Connect(function()
			self._isSelected.Value = true
		end))

		maid:GiveTask(button.SelectionLost:Connect(function()
			self._isSelected.Value = false
		end))

		maid:GiveTask(button.InputBegan:Connect(function(inputObject)
			if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
				self._isMouseOverBasedUponMouseMovement.Value = true
				self._isMouseOverScrollingCheck.Value = true
				self._lastMousePositionForScrollingCheck.Value = inputObject.Position
			end

			if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
				self._isMouseDown.Value = true
			end

			if inputObject.UserInputType == Enum.UserInputType.Touch then
				self:_trackTouch(inputObject)
			end
		end))

		-- Track until something indicates removal
		maid:GiveTask(self._isMouseOverBasedUponMouseMovement:ObserveBrio(function(mouseOver)
			return mouseOver
		end):Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			self:_trackIfButtonMovedOutFromMouse(brio:ToMaid(), button)
		end))

		-- We have to track as long as the mouse hasn't moved
		maid:GiveTask(Rx.combineLatest({
			isMouseOverFromInput = self._isMouseOverBasedUponMouseMovement:Observe();
			isMouseOverScrollingCheck = self._isMouseOverScrollingCheck:Observe();
		}):Subscribe(function(state)
			self._isMouseOver.Value = state.isMouseOverFromInput and state.isMouseOverScrollingCheck
		end))
	end

	self._maid._buttonMaid = maid

	return function()
		if self._maid._buttonMaid == maid then
			self._maid._buttonMaid = nil
		end
	end
end

function ButtonHighlightModel:_trackIfButtonMovedOutFromMouse(maid, button)
	maid:GiveTask(button.InputChanged:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
			self._lastMousePositionForScrollingCheck.Value = inputObject.Position
		end
	end))

	maid:GiveTask(Rx.combineLatest({
		mousePosition = self._lastMousePositionForScrollingCheck:Observe();
		absolutePosition = RxInstanceUtils.observeProperty(button, "AbsolutePosition");
		absoluteSize = RxInstanceUtils.observeProperty(button, "AbsoluteSize");
	}):Pipe({
		Rx.map(function(state)
			if not state.mousePosition then
				return true
			end

			local area = Rect.new(state.absolutePosition, state.absolutePosition + state.absoluteSize)

			if RectUtils.contains(area, Vector2.new(state.mousePosition.x, state.mousePosition.y)) then
				return true
			end

			-- TODO: check rounded corners and rotated guis

			return false
		end)
	}):Subscribe(function(state)
		self._isMouseOverScrollingCheck.Value = state
	end))

	maid:GiveTask(function()
		self._isMouseOverScrollingCheck.Value = false
		self._lastMousePositionForScrollingCheck.Value = nil
	end)

end

--[=[
	Gets if the button is pressed
	@return boolean
]=]
function ButtonHighlightModel:IsPressed()
	return self._isPressed.Value
end

--[=[
	Observes if the button is pressed
	@return Observable<boolean>
]=]
function ButtonHighlightModel:ObserveIsPressed()
	return self._isPressed:Observe()
end

--[=[
	Observes how pressed down the button is

	@param acceleration number | nil
	@return Observable<number>
]=]
function ButtonHighlightModel:ObservePercentPressed(acceleration)
	return Blend.AccelTween(Blend.toPropertyObservable(self._isPressed)
		:Pipe({
			Rx.map(function(value)
				return value and 1 or 0
			end);
		}), acceleration or 200)
end

--[=[
	Observes target for how pressed the button is
	@return Observable<number>
]=]
function ButtonHighlightModel:ObservePercentPressedTarget()
	return self._isPressed:Observe()
		:Pipe({
			Rx.map(function(value)
				return value and 1 or 0
			end);
		})
end

--[=[
	Returns true if highlighted

	@return boolean
]=]
function ButtonHighlightModel:IsHighlighted()
	return self._isHighlighted.Value
end

--[=[
	Observes if we're highlighted

	@return Observable<boolean>
]=]
function ButtonHighlightModel:ObserveIsHighlighted()
	return self._isHighlighted:Observe()
end

--[=[
	Observes target for how highlighted the button is
	@return Observable<number>
]=]
function ButtonHighlightModel:ObservePercentHighlightedTarget()
	return self._isHighlighted:Observe()
		:Pipe({
			Rx.map(function(value)
				return value and 1 or 0
			end);
		})
end

--[=[
	Observes how highlighted the button is

	@param acceleration number | nil
	@return Observable<number>
]=]
function ButtonHighlightModel:ObservePercentHighlighted(acceleration)
	return Blend.AccelTween(self:ObservePercentHighlightedTarget(), acceleration or 200)
end

--[=[
	Returns true if selected

	@return boolean
]=]
function ButtonHighlightModel:IsSelected()
	return self._isSelected.Value
end

--[=[
	Returns an observable for if we're selected

	@return Observable<boolean>
]=]
function ButtonHighlightModel:ObserveIsSelected()
	return self._isSelected:Observe()
end

--[=[
	Gets if mouse or touch is over specifically. This can be used
	for hover effects.

	@return Observable<boolean>
]=]
function ButtonHighlightModel:IsMouseOrTouchOver()
	return self._isMouseOrTouchOver.Value
end

--[=[
	Observes if mouse or touch is over specifically. This can be used
	for hover effects.

	@return Observable<boolean>
]=]
function ButtonHighlightModel:ObserveIsMouseOrTouchOver()
	return self._isMouseOrTouchOver:Observe()
end

--[=[
	Sets whether the model is choosen
	@param isChoosen boolean
	@param doNotAnimate boolean
]=]
function ButtonHighlightModel:SetIsChoosen(isChoosen, doNotAnimate)
	assert(type(isChoosen) == "boolean", "Bad isChoosen")

	self._isChoosen:SetValue(isChoosen, doNotAnimate)
end

--[=[
	Returns true if choosen

	@return boolean
]=]
function ButtonHighlightModel:IsChoosen()
	return self._isChoosen.Value
end

--[=[
	Observes if the instance is "choosen"

	@return boolean
]=]
function ButtonHighlightModel:ObserveIsChoosen()
	return self._isChoosen:Observe()
end

--[=[
	Observes target for if the button is selected or not
	@return Observable<number>
]=]
function ButtonHighlightModel:ObservePercentChoosenTarget()
	return self._isChoosen:Observe()
		:Pipe({
			Rx.map(function(value)
				return value and 1 or 0
			end);
		})
end

--[=[
	Observes how choosen the button is

	@param acceleration number | nil
	@return Observable<number>
]=]
function ButtonHighlightModel:ObservePercentChoosen(acceleration)
	return Blend.AccelTween(self._isChoosen:Observe()
		:Pipe({
			Rx.map(function(value)
				return value and 1 or 0
			end);
		}), acceleration or 200)
end

--[=[
	Sets whether interaction is enabled
	@param interactionEnabled boolean
]=]
function ButtonHighlightModel:SetInteractionEnabled(interactionEnabled)
	self._interactionEnabled:Mount(interactionEnabled)
end

--[=[
	Gets if interaction enabled
	@return boolean
]=]
function ButtonHighlightModel:IsInteractionEnabled()
	return self._interactionEnabled.Value
end

--[=[
	Observes if interaction enabled
	@return Observable<boolean>
]=]
function ButtonHighlightModel:ObserveIsInteractionEnabled()
	return self._interactionEnabled:Observe()
end

--[=[
	Sets whether a key is down
	@param isKeyDown boolean
	@param doNotAnimate boolean -- Optional
]=]
function ButtonHighlightModel:SetKeyDown(isKeyDown, doNotAnimate)
	assert(type(isKeyDown) == "boolean", "Bad isKeyDown")

	self._isKeyDown:SetValue(isKeyDown, doNotAnimate)
end

function ButtonHighlightModel:_trackTouch(inputObject)
	if inputObject.UserInputState == Enum.UserInputState.End then
		return
	end

	local maid = Maid.new()
	self._maid[inputObject] = nil

	self._numFingerDown.Value = self._numFingerDown.Value + 1
	maid:GiveTask(function()
		if self._numFingerDown.Destroy then
			self._numFingerDown.Value = self._numFingerDown.Value - 1
		end
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
	self._isMouseOrTouchOver.Value = self._isMouseOver.Value or self._numFingerDown.Value > 0

	-- Assume event emission can lead to cleanup in middle of call
	if self._isPressed.Destroy then
		self._isPressed.Value = (self._isMouseDown.Value or self._isKeyDown.Value or self._numFingerDown.Value > 0)
	end

	if self._isHighlighted.Destroy then
		self._isHighlighted.Value = self._isSelected.Value
			or self._numFingerDown.Value > 0
			or self._isKeyDown.Value
			or self._isMouseOver.Value
			or self._isMouseDown.Value
	end
end

function ButtonHighlightModel:_update()
	return self._onUpdate(self._percentHighlightedAccelTween, self._percentChoosenAccelTween, self._percentPressAccelTween)
end

function ButtonHighlightModel:_setupLegacySteppedMode()
	self._percentHighlightedAccelTween = AccelTween.new(200)
	self._percentHighlightedAccelTween.t = 0
	self._percentHighlightedAccelTween.p = 0

	self._maid:GiveTask(self._isHighlighted.Changed:Connect(function()
		self._percentHighlightedAccelTween.t = self._isHighlighted.Value and 1 or 0
		self:StartAnimation()
	end))

	self._percentChoosenAccelTween = AccelTween.new(200)
	self._percentChoosenAccelTween.t = 0
	self._percentChoosenAccelTween.p = 0

	self._maid:GiveTask(self._isChoosen.Changed:Connect(function(isChoosen, _, doNotAnimate)
		self._percentChoosenAccelTween.t = isChoosen and 1 or 0
		if doNotAnimate then
			self._percentChoosenAccelTween.p = self._percentChoosenAccelTween.t
			self._percentChoosenAccelTween.v = 0
		end
		self:StartAnimation()
	end))

	self._percentPressAccelTween = AccelTween.new(200)
	self._percentPressAccelTween.t = 0
	self._percentPressAccelTween.p = 0

	self._maid:GiveTask(self._isPressed.Changed:Connect(function()
		self._percentPressAccelTween.t = self._isPressed.Value and 1 or 0
		self:StartAnimation()
	end))

	self.StartAnimation, self._maid._stop = StepUtils.bindToRenderStep(self._update)
	self:StartAnimation()
end

return ButtonHighlightModel
