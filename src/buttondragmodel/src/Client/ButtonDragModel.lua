--!strict
--[=[
	Computes the position of a user dragging a button around

	@class ButtonDragModel
]=]

local require = require(script.Parent.loader).load(script)

local UserInputService = game:GetService("UserInputService")

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local InputObjectUtils = require("InputObjectUtils")
local ValueObject = require("ValueObject")
local _Observable = require("Observable")
local _Brio = require("Brio")
local _Signal = require("Signal")

local ButtonDragModel = setmetatable({}, BaseObject)
ButtonDragModel.ClassName = "ButtonDragModel"
ButtonDragModel.__index = ButtonDragModel

export type ButtonDragModel = typeof(setmetatable(
	{} :: {
		_dragPosition: ValueObject.ValueObject<Vector2?>,
		_dragDelta: ValueObject.ValueObject<Vector2?>,
		_isMouseDown: ValueObject.ValueObject<boolean>,
		_button: ValueObject.ValueObject<GuiButton?>,
		_absoluteSize: ValueObject.ValueObject<Vector2>,
		_isPressed: ValueObject.ValueObject<boolean>,
		_clampWithinButton: ValueObject.ValueObject<boolean>,
		_activePositions: { [InputObject | string]: Vector2? },

		DragPositionChanged: _Signal.Signal<Vector2>,
		IsDraggingChanged: _Signal.Signal<boolean>,
	},
	{} :: typeof({ __index = ButtonDragModel })
)) & BaseObject.BaseObject

--[=[
	Construst a new drag model for the button

	@param initialButton GuiButton? -- Optional
	@return ButtonDragModel
]=]
function ButtonDragModel.new(initialButton: GuiButton?): ButtonDragModel
	local self: ButtonDragModel = setmetatable(BaseObject.new() :: any, ButtonDragModel)

	self._isMouseDown = self._maid:Add(ValueObject.new(false, "boolean"))
	self._dragPosition = self._maid:Add(ValueObject.new(nil))
	self._dragDelta = self._maid:Add(ValueObject.new(nil))
	self._button = self._maid:Add(ValueObject.new(nil))

	self._absoluteSize = self._maid:Add(ValueObject.new(Vector2.zero, "Vector2"))
	self._isPressed = self._maid:Add(ValueObject.new(false, "boolean"))
	self._clampWithinButton = self._maid:Add(ValueObject.new(false, "boolean"))

	self._activePositions = {}

	self._maid:GiveTask(self._dragPosition.Changed:Connect(function()
		self._isPressed.Value = self._dragPosition.Value ~= nil
	end))

	self.DragPositionChanged = self._dragPosition.Changed
	self.IsDraggingChanged = self._isPressed.Changed :: any

	if initialButton then
		self:SetButton(initialButton)
	end

	self._maid:GiveTask(self._button
		:ObserveBrio(function(button: GuiButton?)
			return button ~= nil
		end)
		:Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local maid, button: any = brio:ToMaidAndValue()
			self:_setupDragging(maid, button)
		end))

	return self
end

--[=[
	Returns true if pressed

	@return boolean
]=]
function ButtonDragModel.IsPressed(self: ButtonDragModel): boolean
	return self._isPressed.Value
end

--[=[
	Observes if anything is pressing down on the button itself

	@return Observable<boolean>
]=]
function ButtonDragModel.ObserveIsPressed(self: ButtonDragModel): _Observable.Observable<boolean>
	return self._isPressed:Observe()
end

--[=[
	@return Observable<Brio<true>>
]=]
function ButtonDragModel.ObserveIsPressedBrio(self: ButtonDragModel): _Observable.Observable<_Brio.Brio<boolean>>
	return self._isPressed:ObserveBrio(function(value)
		return value :: any
	end) :: any
end

--[=[
	@return Observable<Vector2?>
]=]
function ButtonDragModel.ObserveDragDelta(self: ButtonDragModel): _Observable.Observable<Vector2?>
	return self._dragDelta:Observe()
end

--[=[
	@return Vector2?
]=]
function ButtonDragModel.GetDragDelta(self: ButtonDragModel): Vector2?
	return self._dragDelta.Value
end

--[=[
	Returns the scale position on the Gui from 0 to 1

	This is reletive to the GUI, so top left is 0, 0

	@return Vector2?
]=]
function ButtonDragModel.GetDragPosition(self: ButtonDragModel): Vector2?
	return self._dragPosition.Value
end

--[=[
	Observes the scale position on the Gui from 0 to 1

	This is reletive to the GUI, so top left is 0, 0

	@return Observable<Vector2?>
]=]
function ButtonDragModel.ObserveDragPosition(self: ButtonDragModel): _Observable.Observable<Vector2?>
	return self._dragPosition:Observe()
end

--[=[
	Sets whether to clamp the results within the button bounds
	@param clampWithinButton boolean
]=]
function ButtonDragModel.SetClampWithinButton(self: ButtonDragModel, clampWithinButton: boolean)
	self._clampWithinButton.Value = clampWithinButton
end

--[=[
	Sets the current button for the model

	@param button GuiButton
	@return () -> () -- Cleanup function
]=]
function ButtonDragModel.SetButton(self: ButtonDragModel, button: GuiButton): () -> ()
	assert(typeof(button) == "Instance" or button == nil, "Bad button")

	self._button.Value = button

	return function()
		if self._button.Value == button then
			self._button.Value = nil
		end
	end
end

function ButtonDragModel._setupDragging(self: ButtonDragModel, maid: Maid.Maid, button: GuiButton)
	maid:GiveTask(self._clampWithinButton.Changed:Connect(function()
		self:_updateCurrentPosition()
	end))

	maid:GiveTask(button.InputBegan:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			self._activePositions.mouse = self:_toButtonSpace(button, inputObject.Position)
			self._isMouseDown.Value = true
			self:_updateCurrentPosition()
		end

		if inputObject.UserInputType == Enum.UserInputType.Touch then
			self:_trackTouch(maid, button, inputObject)
		end
	end))

	maid:GiveTask(button.InputEnded:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			self._activePositions.mouse = nil
			self._isMouseDown.Value = false
		end

		if inputObject.UserInputType == Enum.UserInputType.Touch then
			self:_stopTouchTrack(maid, inputObject)
		end
	end))

	maid:GiveTask(UserInputService.InputEnded:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			self._activePositions.mouse = nil
			self._isMouseDown.Value = false
		end
	end))

	maid:GiveTask(function()
		self._activePositions.mouse = nil
		self._isMouseDown.Value = false
	end)

	maid:GiveTask(self._isMouseDown.Changed:Connect(function()
		if self._isMouseDown.Value then
			maid._mouse = self:_updateMouseTracking(button)
		else
			maid._mouse = nil
		end
	end))
end

function ButtonDragModel._updateMouseTracking(self: ButtonDragModel, button: GuiButton)
	local maid = Maid.new()

	local lastMousePosition: Vector3? = nil

	local function setMousePosition(inputObject: InputObject)
		local previous = lastMousePosition
		local current = inputObject.Position

		lastMousePosition = current

		if previous then
			local delta = current - previous
			self:_incrementDragDelta(delta)
		end

		self._activePositions.mouse = self:_toButtonSpace(button, current)
		self:_updateCurrentPosition()
	end

	maid:GiveTask(UserInputService.InputChanged:Connect(function(inputObject)
		if not InputObjectUtils.isMouseUserInputType(inputObject.UserInputType) then
			return
		end

		local screenGui = button:FindFirstAncestorWhichIsA("ScreenGui")
		if not screenGui then
			self._activePositions.mouse = nil
			self:_updateCurrentPosition()
			return
		end

		if not (screenGui:FindFirstAncestorWhichIsA("PlayerGui") or screenGui:FindFirstAncestorWhichIsA("CoreGui")) then
			-- TODO: Handle billboard guis
			self._activePositions.mouse = nil
			self:_updateCurrentPosition()
			return
		end

		setMousePosition(inputObject)
	end))

	maid:GiveTask(button.InputChanged:Connect(function(inputObject)
		if InputObjectUtils.isMouseUserInputType(inputObject.UserInputType) then
			setMousePosition(inputObject)
		end
	end))

	maid:GiveTask(function()
		self._activePositions.mouse = nil
		self:_updateCurrentPosition()
	end)

	return maid
end

function ButtonDragModel._trackTouch(
	self: ButtonDragModel,
	buttonMaid: Maid.Maid,
	button: GuiButton,
	inputObject: InputObject
)
	buttonMaid[inputObject] = nil

	if inputObject.UserInputState == Enum.UserInputState.End then
		return
	end

	local maid = Maid.new()

	self._activePositions[inputObject] = self:_toButtonSpace(button, inputObject.Position)
	self:_incrementDragDelta(inputObject.Delta)

	maid:GiveTask(inputObject:GetPropertyChangedSignal("Delta"):Connect(function()
		self:_incrementDragDelta(inputObject.Delta)
	end))

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
		self:_updateCurrentPosition()
	end)

	self:_updateCurrentPosition()

	maid[inputObject] = maid
end

function ButtonDragModel._stopTouchTrack(_self: ButtonDragModel, buttonMaid: Maid.Maid, inputObject: InputObject)
	-- Clears the input tracking as we slide off the button
	buttonMaid[inputObject] = nil
end

function ButtonDragModel._toButtonSpace(_self: ButtonDragModel, button: GuiButton, position: Vector3): Vector2
	local pos = button.AbsolutePosition
	local size = button.AbsoluteSize

	return (Vector2.new(position.X, position.Y) - pos) / size
end

function ButtonDragModel._updateCurrentPosition(self: ButtonDragModel): ()
	local current: Vector2 = Vector2.zero
	local count = 0
	for _, item: any in self._activePositions do
		current += item
		count = count + 1
	end
	if count == 0 then
		self._dragPosition.Value = nil
		self._dragDelta.Value = nil
		return
	end

	current = current / count
	local x = current.X
	local y = current.Y

	if self._clampWithinButton.Value then
		x = math.clamp(x, 0, 1)
		y = math.clamp(y, 0, 1)
	end

	local position = Vector2.new(x, y)
	self._dragPosition.Value = position

	if not self._dragDelta.Value then
		self._dragDelta.Value = Vector2.zero
	end
end

function ButtonDragModel._incrementDragDelta(self: ButtonDragModel, delta: Vector3)
	local current: Vector2 = self._dragDelta.Value or Vector2.zero
	self._dragDelta.Value = current + Vector2.new(delta.X, delta.Y)
end

return ButtonDragModel