--!strict
--[=[
	Input handler that drives a [ConstrainedLookCamera]. Reacts to right-click
	drag on mouse, drag on touchscreen, and right thumbstick on gamepad.

	@class ConstrainedLookControls
]=]

local require = require(script.Parent.loader).load(script)

local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ConstrainedLookCamera = require("ConstrainedLookCamera")
local GamepadRotateModel = require("GamepadRotateModel")
local InputObjectUtils = require("InputObjectUtils")
local Maid = require("Maid")

local ConstrainedLookControls = {}
ConstrainedLookControls.__index = ConstrainedLookControls
ConstrainedLookControls.ClassName = "ConstrainedLookControls"

ConstrainedLookControls.MOUSE_SENSITIVITY = Vector2.new(math.pi * 4, math.pi * 1.9)
ConstrainedLookControls.GAMEPAD_SENSITIVITY = 0.1
ConstrainedLookControls._dragBeginTypes = { Enum.UserInputType.MouseButton2, Enum.UserInputType.Touch }

export type ConstrainedLookControls = typeof(setmetatable(
	{} :: {
		_camera: ConstrainedLookCamera.ConstrainedLookCamera,
		_enabled: boolean,
		_key: string,
		_maid: Maid.Maid?,
		_gamepadRotateModel: GamepadRotateModel.GamepadRotateModel,
		_lastMousePosition: Vector3?,
		_mouseSensitivity: Vector2,
		_gamepadSensitivity: number,
	},
	{} :: typeof({ __index = ConstrainedLookControls })
))

--[=[
	Constructs a new ConstrainedLookControls bound to the given camera.
]=]
function ConstrainedLookControls.new(camera: ConstrainedLookCamera.ConstrainedLookCamera): ConstrainedLookControls
	local self: ConstrainedLookControls = setmetatable({} :: any, ConstrainedLookControls)

	self._camera = assert(camera, "Bad camera")
	self._enabled = false
	self._key = tostring(self) .. "ConstrainedLookControls"
	self._mouseSensitivity = ConstrainedLookControls.MOUSE_SENSITIVITY
	self._gamepadSensitivity = ConstrainedLookControls.GAMEPAD_SENSITIVITY
	self._gamepadRotateModel = GamepadRotateModel.new()

	return self
end

--[=[
	Sets mouse sensitivity.
]=]
function ConstrainedLookControls.SetMouseSensitivity(self: ConstrainedLookControls, sensitivity: Vector2)
	self._mouseSensitivity = sensitivity
end

--[=[
	Sets gamepad sensitivity.
]=]
function ConstrainedLookControls.SetGamepadSensitivity(self: ConstrainedLookControls, sensitivity: number)
	self._gamepadSensitivity = sensitivity
end

--[=[
	Returns whether controls are enabled.
]=]
function ConstrainedLookControls.IsEnabled(self: ConstrainedLookControls): boolean
	return self._enabled
end

--[=[
	Enables input. Binds drag (MouseButton2 / Touch) and gamepad Thumbstick2.
]=]
function ConstrainedLookControls.Enable(self: ConstrainedLookControls)
	if self._enabled then
		return
	end
	assert(not self._maid, "Maid already defined")
	self._enabled = true

	local maid = Maid.new()
	self._maid = maid

	maid:GiveTask(self._gamepadRotateModel.IsRotating.Changed:Connect(function()
		if self._gamepadRotateModel.IsRotating.Value then
			self:_handleGamepadRotateStart()
		else
			self:_handleGamepadRotateStop()
		end
	end))

	ContextActionService:BindAction(self._key .. "Drag", function(_, userInputState, inputObject)
		if userInputState == Enum.UserInputState.Begin then
			self:_beginDrag(inputObject)
		end
		return Enum.ContextActionResult.Pass
	end, false, unpack(self._dragBeginTypes))

	ContextActionService:BindAction(self._key .. "Rotate", function(_, _, inputObject)
		self._gamepadRotateModel:HandleThumbstickInput(inputObject)
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Thumbstick2)

	maid:GiveTask(function()
		ContextActionService:UnbindAction(self._key .. "Drag")
		ContextActionService:UnbindAction(self._key .. "Rotate")
	end)

	maid:GiveTask(function()
		self._camera:Release()
	end)
end

--[=[
	Disables input and releases the camera.
]=]
function ConstrainedLookControls.Disable(self: ConstrainedLookControls)
	if not self._enabled then
		return
	end
	assert(self._maid, "Must be enabled")
	self._enabled = false

	self._maid:DoCleaning()
	self._maid = nil
	self._lastMousePosition = nil
end

function ConstrainedLookControls._beginDrag(self: ConstrainedLookControls, beginInputObject: InputObject)
	assert(self._maid, "Must be enabled")

	local maid = Maid.new()
	self._lastMousePosition = beginInputObject.Position

	local isMouse = InputObjectUtils.isMouseUserInputType(beginInputObject.UserInputType)
	if isMouse then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		maid:GiveTask(function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end)
	end

	maid:GiveTask(UserInputService.InputEnded:Connect(function(inputObject: InputObject)
		if inputObject == beginInputObject then
			self:_endDrag()
		end
	end))

	maid:GiveTask(UserInputService.InputChanged:Connect(function(inputObject: InputObject)
		if InputObjectUtils.isMouseUserInputType(inputObject.UserInputType) or inputObject == beginInputObject then
			self:_handleDragMovement(inputObject)
		end
	end))

	maid:GiveTask(function()
		self._lastMousePosition = nil
		self._camera:Release()
	end)

	self._maid._dragMaid = maid
end

function ConstrainedLookControls._endDrag(self: ConstrainedLookControls)
	assert(self._maid, "Must be enabled")
	self._maid._dragMaid = nil
end

function ConstrainedLookControls._handleDragMovement(self: ConstrainedLookControls, inputObject: InputObject)
	if not self._lastMousePosition then
		return
	end

	local delta = -inputObject.Delta
	if InputObjectUtils.isMouseUserInputType(inputObject.UserInputType) then
		delta += self._lastMousePosition - inputObject.Position
	end

	local xTheta = delta.X / 1920
	local yTheta = delta.Y / 1200
	local deltaAngle = Vector2.new(xTheta, yTheta) * self._mouseSensitivity
	self._camera:RotateXY(deltaAngle)

	self._lastMousePosition = inputObject.Position
end

function ConstrainedLookControls._handleGamepadRotateStart(self: ConstrainedLookControls)
	assert(self._maid, "Must be enabled")

	local maid = Maid.new()

	maid:GiveTask(RunService.Stepped:Connect(function()
		local deltaAngle = self._gamepadSensitivity * self._gamepadRotateModel:GetThumbstickDeltaAngle()
		self._camera:RotateXY(deltaAngle)
	end))

	maid:GiveTask(function()
		self._camera:Release()
	end)

	self._maid._dragMaid = maid
end

function ConstrainedLookControls._handleGamepadRotateStop(self: ConstrainedLookControls)
	assert(self._maid, "Must be enabled")
	self._maid._dragMaid = nil
end

function ConstrainedLookControls.Destroy(self: ConstrainedLookControls)
	self:Disable()
	self._gamepadRotateModel:Destroy()
	setmetatable(self :: any, nil)
end

return ConstrainedLookControls
