--- Interface between user input and camera controls
-- @classmod CameraControls

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Maid = require("Maid")
local GamepadRotateModel = require("GamepadRotateModel")

--- Stolen directly from ROBLOX's core scripts.
-- Looks like a simple integrator.
-- Called (zoom, zoomScale, 1) returns zoom
local function rk4Integrator(position, velocity, t)
	local direction = velocity < 0 and -1 or 1
	local function acceleration(p, v)
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
CameraControls.MOUSE_SENSITIVITY = Vector2.new(math.pi*4, math.pi*1.9)
CameraControls._dragBeginTypes = { Enum.UserInputType.MouseButton2, Enum.UserInputType.Touch }

function CameraControls.new(zoomCamera, rotatedCamera)
	local self = setmetatable({}, CameraControls)

	self._enabled = false
	self._key = tostring(self) .. "CameraControls"
	self._gamepadRotateModel = GamepadRotateModel.new()

	if zoomCamera then
		self:SetZoomedCamera(zoomCamera)
	end
	if rotatedCamera then
		self:SetRotatedCamera(rotatedCamera)
	end

	return self
end

function CameraControls:GetKey()
	return self._key
end

function CameraControls:IsEnabled()
	return self._enabled
end

function CameraControls:Enable()
	if self._enabled then
		return
	end

	assert(not self._maid)
	self._enabled = true

	self._maid = Maid.new()

	self._maid:GiveTask(self._gamepadRotateModel.IsRotating.Changed:Connect(function()
		if self._gamepadRotateModel.IsRotating.Value then
			self:_handleGamepadRotateStart()
		else
			self:_handleGamepadRotateStop()
		end
	end))

	ContextActionService:BindAction(self._key, function(actionName, userInputState, inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseWheel then
			self:_handleMouseWheel(inputObject)
		end
	end, false, Enum.UserInputType.MouseWheel)

	ContextActionService:BindAction(self._key .. "Drag", function(actionName, userInputState, inputObject)
		if userInputState == Enum.UserInputState.Begin then
			self:BeginDrag(inputObject)
		end
	end, false, unpack(self._dragBeginTypes))

	ContextActionService:BindAction(self._key .. "Rotate", function(actionName, userInputState, inputObject)
		self:_handleThumbstickInput(inputObject)
	end, false, Enum.KeyCode.Thumbstick2)

	self._maid:GiveTask(UserInputService.TouchPinch:Connect(function(touchPositions, scale, velocity, userInputState)
		self:_handleTouchPinch(scale, velocity, userInputState)
	end))

	self._maid:GiveTask(function()
		ContextActionService:UnbindAction(self._key)
		ContextActionService:UnbindAction(self._key .. "Drag")
		ContextActionService:UnbindAction(self._key .. "Rotate")
	end)
end

function CameraControls:Disable()
	if not self._enabled then
		return
	end

	self._enabled = false

	self._maid:DoCleaning()
	self._maid = nil

	self._lastMousePosition = nil
end

function CameraControls:BeginDrag(beginInputObject)
	if not self._rotatedCamera then
		self._maid._dragMaid = nil
		return
	end

	local maid = Maid.new()

	self._lastMousePosition = beginInputObject.Position
	local isMouse = beginInputObject.UserInputType.Name:find("Mouse")
	if isMouse then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end

	maid:GiveTask(UserInputService.InputEnded:Connect(function(inputObject, GameProcessed)
		if inputObject == beginInputObject then
			self:_endDrag()
		end
	end))

	maid:GiveTask(UserInputService.InputChanged:Connect(function(inputObject)
		if isMouse and inputObject.UserInputType == Enum.UserInputType.MouseMovement
			or inputObject == beginInputObject then

			self:_handleMouseMovement(inputObject)
		end
	end))

	if self._rotatedCamera.ClassName == "SmoothRotatedCamera" then
		self._rotVelocityTracker = self:_getVelocityTracker(0.05, Vector2.new())
	end

	self._maid._dragMaid = maid
end

function CameraControls:SetZoomedCamera(zoomedCamera)
	self._zoomedCamera = zoomedCamera or error()
	self._startZoomScale = self._zoomedCamera.Zoom

	return self
end

function CameraControls:SetRotatedCamera(rotatedCamera)
	self._rotatedCamera = rotatedCamera or error()
	return self
end

--- This code was the same algorithm used by ROBLOX. It makes it so you can zoom easier at further distances.
function CameraControls:_handleMouseWheel(inputObject)
	if self._zoomedCamera then
		local delta = math.clamp(-inputObject.Position.Z, -1, 1)*1.4
		local zoom = rk4Integrator(self._zoomedCamera.TargetZoom, delta, 1)

		self._zoomedCamera.TargetZoom = zoom
	end

	if self._rotatedCamera then
		if self._rotatedCamera.ClassName == "PushCamera" then
			self._rotatedCamera:StopRotateBack()
		end
	end
end

function CameraControls:_handleTouchPinch(scale, velocity, userInputState)
	if self._zoomedCamera then
		if userInputState == Enum.UserInputState.Begin then
			self._startZoomScale = self._zoomedCamera.Zoom
			self._zoomedCamera.Zoom = self._startZoomScale*1/scale
		elseif userInputState == Enum.UserInputState.End then
			self._zoomedCamera.Zoom = self._startZoomScale*1/scale
			self._zoomedCamera.TargetZoom = self._zoomedCamera.Zoom + -velocity/5
		elseif userInputState == Enum.UserInputState.Change then
			if self._startZoomScale then
				self._zoomedCamera.TargetZoom = self._startZoomScale*1/scale
				self._zoomedCamera.Zoom = self._zoomedCamera.TargetZoom
			else
				warn("[CameraControls._handleTouchPinch] - No self._startZoomScale")
			end
		end
	end
end

--- This is also a ROBLOX algorithm. Not sure why screen resolution is locked like it is.
function CameraControls:_mouseTranslationToAngle(translationVector)
	local xTheta = (translationVector.x / 1920)
	local yTheta = (translationVector.y / 1200)
	return Vector2.new(xTheta, yTheta)
end

function CameraControls:_getVelocityTracker(strength, startVelocity)
	strength = strength or 1

	local lastUpdate = tick()
	local velocity = startVelocity

	return {
		Update = function(this, delta)
			local elapsed = tick() - lastUpdate
			lastUpdate = tick()
			velocity = velocity / (2^(elapsed/strength)) + (delta / (0.0001 + elapsed)) * strength
		end;
		GetVelocity = function(this)
			this:Update(startVelocity*0)
			return velocity
		end;
	}
end

function CameraControls:_handleMouseMovement(inputObject, isMouse)
	if self._lastMousePosition then
		if self._rotatedCamera then
			-- This calculation may seem weird, but either .Position updates (if it's locked), or .Delta updates (if it's not).
			local delta
			if isMouse then
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

function CameraControls:_handleThumbstickInput(inputObject)
	self._gamepadRotateModel:HandleThumbstickInput(inputObject)
end

function CameraControls:_applyRotVelocityTracker(rotVelocityTracker)
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

function CameraControls:_endDrag()
	if self._rotVelocityTracker then
		self:_applyRotVelocityTracker(self._rotVelocityTracker)
		self._rotVelocityTracker = nil
	end

	self._lastMousePosition = nil
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default

	self._maid._dragMaid = nil
end



function CameraControls:_handleGamepadRotateStop()
	if self._rotVelocityTracker then
		self:_applyRotVelocityTracker(self._rotVelocityTracker)
		self._rotVelocityTracker = nil
	end

	self._maid._dragMaid = nil
end

function CameraControls:_handleGamepadRotateStart()
	if not self._rotatedCamera then
		self._maid._dragMaid = nil
		return
	end

	local maid = Maid.new()

	if self._rotatedCamera.ClassName == "SmoothRotatedCamera" then
		self._rotVelocityTracker = self:_getVelocityTracker(0.05, Vector2.new())
	end

	maid:GiveTask(RunService.Heartbeat:Connect(function()
		local DeltaAngle = self._gamepadRotateModel:GetThumbstickDeltaAngle()

		if self._rotatedCamera then
			self._rotatedCamera:RotateXY(DeltaAngle)
		end

		if self._rotVelocityTracker then
			self._rotVelocityTracker:Update(DeltaAngle)
		end
	end))

	self._maid._dragMaid = maid
end

function CameraControls:Destroy()
	self:Disable()
	setmetatable(self, nil)
end

return CameraControls