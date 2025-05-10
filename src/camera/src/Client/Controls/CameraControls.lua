--!strict
--[=[
	Interface between user input and camera controls
	@class CameraControls
]=]

local require = require(script.Parent.loader).load(script)

local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GamepadRotateModel = require("GamepadRotateModel")
local InputObjectUtils = require("InputObjectUtils")
local Maid = require("Maid")
local PushCamera = require("PushCamera")
local SmoothRotatedCamera = require("SmoothRotatedCamera")
local SmoothZoomedCamera = require("SmoothZoomedCamera")

-- Stolen directly from ROBLOX's core scripts.
-- Looks like a simple integrator.
-- Called (zoom, zoomScale, 1) returns zoom
local function rk4Integrator(position: number, velocity: number, t: number): (number, number)
	local direction = velocity < 0 and -1 or 1
	local function acceleration(p: number, _: number): number
		local accel = direction * math.max(1, (p / 3.3) + 0.5)
		return accel
	end

	local p1 = position
	local v1 = velocity
	local a1 = acceleration(p1, v1)
	local p2 = p1 + v1 * (t / 2)
	local v2 = v1 + a1 * (t / 2)
	local a2 = acceleration(p2, v2)
	local p3 = p1 + v2 * (t / 2)
	local v3 = v1 + a2 * (t / 2)
	local a3 = acceleration(p3, v3)
	local p4 = p1 + v3 * t
	local v4 = v1 + a3 * t
	local a4 = acceleration(p4, v4)

	local positionResult = position + (v1 + 2 * v2 + 2 * v3 + v4) * (t / 6)
	local velocityResult = velocity + (a1 + 2 * a2 + 2 * a3 + a4) * (t / 6)
	return positionResult, velocityResult
end

local CameraControls = {}
CameraControls.__index = CameraControls
CameraControls.ClassName = "CameraControls"
CameraControls.MOUSE_SENSITIVITY = Vector2.new(math.pi * 4, math.pi * 1.9)
CameraControls._dragBeginTypes = { Enum.UserInputType.MouseButton2, Enum.UserInputType.Touch }

export type CameraControls = typeof(setmetatable(
	{} :: {
		_enabled: boolean,
		_key: string,
		_maid: Maid.Maid?,
		_strength: number,
		_zoomedCamera: SmoothZoomedCamera.SmoothZoomedCamera?,
		_rotatedCamera: SmoothRotatedCamera.SmoothRotatedCamera?,
		_gamepadRotateModel: GamepadRotateModel.GamepadRotateModel,
		_rotVelocityTracker: any?,
		_lastMousePosition: Vector3?,
		_startZoomScale: number,
		_dragMaid: Maid.Maid?,
	},
	{} :: typeof({ __index = CameraControls })
))

function CameraControls.new(
	zoomedCamera: SmoothZoomedCamera.SmoothZoomedCamera?,
	rotatedCamera: SmoothRotatedCamera.SmoothRotatedCamera?
): CameraControls
	local self: CameraControls = setmetatable({} :: any, CameraControls)

	self._enabled = false
	self._key = tostring(self) .. "CameraControls"

	-- Destroyed below
	self._gamepadRotateModel = GamepadRotateModel.new()

	if zoomedCamera then
		self:SetZoomedCamera(zoomedCamera)
	end
	if rotatedCamera then
		self:SetRotatedCamera(rotatedCamera)
	end

	return self
end

--[=[
	Sets the gamepad rotation acceleration
	@param acceleration number
]=]
function CameraControls.SetGamepadRotationAcceleration(self: CameraControls, acceleration: number)
	assert(type(acceleration) == "number", "Bad acceleration")

	self._gamepadRotateModel:SetAcceleration(acceleration)
end

function CameraControls.GetKey(self: CameraControls): string
	return self._key
end

function CameraControls.IsEnabled(self: CameraControls): boolean
	return self._enabled
end

--[=[
	Enables the control.
]=]
function CameraControls.Enable(self: CameraControls)
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

	ContextActionService:BindAction(self._key, function(_, _, inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseWheel then
			self:_handleMouseWheel(inputObject)
		end
	end, false, Enum.UserInputType.MouseWheel)

	ContextActionService:BindAction(self._key .. "Drag", function(_, userInputState, inputObject)
		if userInputState == Enum.UserInputState.Begin then
			self:BeginDrag(inputObject)
		end
	end, false, unpack(self._dragBeginTypes))

	ContextActionService:BindAction(self._key .. "Rotate", function(_, _, inputObject)
		self:_handleThumbstickInput(inputObject)
	end, false, Enum.KeyCode.Thumbstick2)

	maid:GiveTask(UserInputService.TouchPinch:Connect(function(_, scale, velocity, userInputState)
		self:_handleTouchPinch(scale, velocity, userInputState)
	end))

	maid:GiveTask(function()
		ContextActionService:UnbindAction(self._key)
		ContextActionService:UnbindAction(self._key .. "Drag")
		ContextActionService:UnbindAction(self._key .. "Rotate")
	end)
end

--[=[
	Disables the control.
]=]
function CameraControls.Disable(self: CameraControls)
	if not self._enabled then
		return
	end

	assert(self._maid, "Must be enabled")
	self._enabled = false

	self._maid:DoCleaning()
	self._maid = nil

	self._lastMousePosition = nil
end

function CameraControls.BeginDrag(self: CameraControls, beginInputObject)
	assert(self._maid, "Must be enabled")

	if not self._rotatedCamera then
		self._maid._dragMaid = nil
		return
	end

	local maid = Maid.new()

	self._lastMousePosition = beginInputObject.Position
	local isMouse = InputObjectUtils.isMouseUserInputType(beginInputObject.UserInputType)
	if isMouse then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end

	maid:GiveTask(UserInputService.InputEnded:Connect(function(inputObject, _)
		if inputObject == beginInputObject then
			self:_endDrag()
		end
	end))

	maid:GiveTask(UserInputService.InputChanged:Connect(function(inputObject)
		if InputObjectUtils.isMouseUserInputType(inputObject.UserInputType) or inputObject == beginInputObject then
			self:_handleMouseMovement(inputObject)
		end
	end))

	if self._rotatedCamera.ClassName == "SmoothRotatedCamera" then
		self._rotVelocityTracker = self:_getVelocityTracker(self._strength or 0.05, Vector2.zero)
	end

	self._maid._dragMaid = maid
end

function CameraControls.SetZoomedCamera(
	self: CameraControls,
	zoomedCamera: SmoothZoomedCamera.SmoothZoomedCamera
): CameraControls
	self._zoomedCamera = assert(zoomedCamera, "Bad zoomedCamera")
	self._startZoomScale = zoomedCamera.Zoom

	return self
end

function CameraControls.SetRotatedCamera(
	self: CameraControls,
	rotatedCamera: SmoothRotatedCamera.SmoothRotatedCamera
): CameraControls
	self._rotatedCamera = assert(rotatedCamera, "Bad rotatedCamera")
	return self
end

-- This code was the same algorithm used by Roblox. It makes it so you can zoom easier at further distances.
function CameraControls._handleMouseWheel(self: CameraControls, inputObject: InputObject): ()
	local zoomedCamera = self._zoomedCamera
	if zoomedCamera then
		local delta = math.clamp(-inputObject.Position.Z, -1, 1) * 1.4
		local zoom = rk4Integrator(zoomedCamera.TargetZoom, delta, 1)

		zoomedCamera.TargetZoom = zoom
	end

	local rotatedCamera = self._rotatedCamera
	if rotatedCamera then
		if rotatedCamera.ClassName == "PushCamera" then
			((rotatedCamera :: any) :: PushCamera.PushCamera):StopRotateBack()
		end
	end
end

function CameraControls._handleTouchPinch(
	self: CameraControls,
	scale: number,
	velocity: number,
	userInputState: Enum.UserInputState
)
	if self._zoomedCamera then
		if userInputState == Enum.UserInputState.Begin then
			self._startZoomScale = self._zoomedCamera.Zoom
			self._zoomedCamera.Zoom = self._startZoomScale * 1 / scale
		elseif userInputState == Enum.UserInputState.End then
			self._zoomedCamera.Zoom = self._startZoomScale * 1 / scale
			self._zoomedCamera.TargetZoom = self._zoomedCamera.Zoom + -velocity / 5
		elseif userInputState == Enum.UserInputState.Change then
			if self._startZoomScale then
				self._zoomedCamera.TargetZoom = self._startZoomScale * 1 / scale
				self._zoomedCamera.Zoom = self._zoomedCamera.TargetZoom
			else
				warn("[CameraControls._handleTouchPinch] - No self._startZoomScale")
			end
		end
	end
end

-- This is also a Roblox algorithm. Not sure why screen resolution is locked like it is.
function CameraControls._mouseTranslationToAngle(_self: CameraControls, translationVector: Vector3): Vector2
	local xTheta = (translationVector.X / 1920)
	local yTheta = (translationVector.Y / 1200)
	return Vector2.new(xTheta, yTheta)
end

function CameraControls.SetVelocityStrength(self: CameraControls, strength: number): ()
	self._strength = strength
end

function CameraControls._getVelocityTracker(_self: CameraControls, initialStrength: number?, startVelocity: Vector2)
	local strength = initialStrength or 1

	local lastUpdate = os.clock()
	local velocity: Vector2 = startVelocity

	return {
		Update = function(_this, delta: Vector2)
			local elapsed = os.clock() - lastUpdate
			lastUpdate = os.clock()
			velocity = velocity / (2 ^ (elapsed / strength)) + (delta / (0.0001 + elapsed)) * strength
		end,
		GetVelocity = function(this)
			this:Update(startVelocity * 0)
			return velocity
		end,
	}
end

function CameraControls._handleMouseMovement(self: CameraControls, inputObject: InputObject)
	if self._lastMousePosition then
		if self._rotatedCamera then
			-- This calculation may seem weird, but either .Position updates (if it's locked), or .Delta updates (if it's not).
			local delta: Vector3
			if InputObjectUtils.isMouseUserInputType(inputObject.UserInputType) then
				delta = -inputObject.Delta + self._lastMousePosition - inputObject.Position
			else
				delta = -inputObject.Delta
			end

			local deltaAngle = self:_mouseTranslationToAngle(delta) * self.MOUSE_SENSITIVITY
			self._rotatedCamera:RotateXY(deltaAngle)

			if self._rotVelocityTracker then
				self._rotVelocityTracker:Update(deltaAngle)
			end
		end

		self._lastMousePosition = inputObject.Position
	end
end

function CameraControls._handleThumbstickInput(self: CameraControls, inputObject: InputObject)
	self._gamepadRotateModel:HandleThumbstickInput(inputObject)
end

function CameraControls._applyRotVelocityTracker(self: CameraControls, rotVelocityTracker)
	if self._rotatedCamera then
		local position = self._rotatedCamera.AngleXZ
		local velocity = rotVelocityTracker:GetVelocity().X
		local newVelocityTarget = position + velocity
		local target = self._rotatedCamera.TargetAngleXZ

		if math.abs(newVelocityTarget - position) > math.abs(target - position) then
			self._rotatedCamera.TargetAngleXZ = newVelocityTarget
		end

		self._rotatedCamera:SnapIntoBounds()
	end
end

function CameraControls._endDrag(self: CameraControls): ()
	assert(self._maid, "Must be enabled")

	if self._rotVelocityTracker then
		self:_applyRotVelocityTracker(self._rotVelocityTracker)
		self._rotVelocityTracker = nil
	end

	self._lastMousePosition = nil
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default

	self._maid._dragMaid = nil
end

function CameraControls._handleGamepadRotateStop(self: CameraControls): ()
	assert(self._maid, "Must be enabled")

	if self._rotVelocityTracker then
		self:_applyRotVelocityTracker(self._rotVelocityTracker)
		self._rotVelocityTracker = nil
	end

	self._maid._dragMaid = nil
end

function CameraControls._handleGamepadRotateStart(self: CameraControls): ()
	assert(self._maid, "Must be enabled")

	if not self._rotatedCamera then
		self._maid._dragMaid = nil
		return
	end

	local maid = Maid.new()

	if self._rotatedCamera.ClassName == "SmoothRotatedCamera" then
		self._rotVelocityTracker = self:_getVelocityTracker(0.05, Vector2.zero)
	end

	maid:GiveTask(RunService.Stepped:Connect(function()
		local deltaAngle: Vector2 = 0.1 * self._gamepadRotateModel:GetThumbstickDeltaAngle()

		if self._rotatedCamera then
			self._rotatedCamera:RotateXY(deltaAngle)
		end

		if self._rotVelocityTracker then
			self._rotVelocityTracker:Update(deltaAngle)
		end
	end))

	self._maid._dragMaid = maid
end

function CameraControls.Destroy(self: CameraControls)
	self:Disable()
	self._gamepadRotateModel:Destroy()
	setmetatable(self :: any, nil)
end

return CameraControls
