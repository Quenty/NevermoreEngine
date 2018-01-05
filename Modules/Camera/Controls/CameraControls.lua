--- Interface between user input and camera controls
-- @classmod CameraControls

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Maid = require("Maid")
local AccelTween = require("AccelTween")

local GamepadRotate = {}
GamepadRotate.__index = GamepadRotate
GamepadRotate.ClassName = "GamepadRotate"

function GamepadRotate.new()
	local self = setmetatable({}, GamepadRotate)

	self.DEADZONE = 0.1
	self.SpeedMultiplier = Vector2.new(0.1, 0.1)

	self.RampVelocityX = AccelTween.new(5)
	self.RampVelocityY = AccelTween.new(5)

	self.IsRotating = Instance.new("BoolValue")
	self.IsRotating.Value = false

	return self
end

do
	-- See: https://github.com/Roblox/Core-Scripts/blob/cad3a477e39b93ecafdd610b1d8b89d239ab18e2/PlayerScripts/StarterPlayerScripts/CameraScript/RootCamera.lua#L395
	-- K is a tunable parameter that changes the shape of the S-curve
	-- the larger K is the more straight/linear the curve gets
	local k = 0.35
	local lowerK = 0.8
	function GamepadRotate:SCurveTranform(t)
		t = math.clamp(t, -1, 1)
		if t >= 0 then
			return (k*t) / (k - t + 1)
		end
		return -((lowerK*-t) / (lowerK + t + 1))
	end
end

function GamepadRotate:ToSCurveSpace(t)
	return (1 + self.DEADZONE) * (2*math.abs(t) - 1) - self.DEADZONE
end

function GamepadRotate:FromSCurveSpace(t)
	return t/2 + 0.5
end

function GamepadRotate:GamepadLinearToCurve(ThumbstickPosition)
	local function OnAxis(AxisValue)
		local Sign = math.sign(AxisValue)
		local Point = self:FromSCurveSpace(self:SCurveTranform(self:ToSCurveSpace(math.abs(AxisValue))))
		return math.clamp(Point * Sign, -1, 1)
	end
	return Vector2.new(OnAxis(ThumbstickPosition.x), OnAxis(ThumbstickPosition.y))
end

function GamepadRotate:OutOfDeadzone(InputObject)
	local StickOffset = InputObject.Position
	return StickOffset.magnitude >= self.DEADZONE
end

function GamepadRotate:GetThumbstickDeltaAngle()
	if not self.LastInputObject then
		return Vector2.new()
	end

	return Vector2.new(self.RampVelocityX.p, self.RampVelocityY.p)
end

function GamepadRotate:StopRotate()
	self.LastInputObject = nil
	self.RampVelocityX.t = 0
	self.RampVelocityX.p = self.RampVelocityX.t

	self.RampVelocityY.t = 0
	self.RampVelocityY.p = self.RampVelocityY.t

	self.IsRotating.Value = false
end

function GamepadRotate:HandleThumbstickInput(InputObject)
	local OutOfDeadZone = self:OutOfDeadzone(InputObject)

	if OutOfDeadZone then
		self.LastInputObject = InputObject


		local StickOffset = self.LastInputObject.Position
		StickOffset = Vector2.new(StickOffset.x, -StickOffset.y)  -- Invert axis!

		local AdjustedStickOffset = self:GamepadLinearToCurve(StickOffset)
		self.RampVelocityX.t = AdjustedStickOffset.x * self.SpeedMultiplier.x
		self.RampVelocityY.t = AdjustedStickOffset.y * self.SpeedMultiplier.y

		self.IsRotating.Value = true
	else
		self:StopRotate()
	end
end


local CameraControls = {}
CameraControls.__index = CameraControls
CameraControls.ClassName = "CameraControls"
CameraControls.MOUSE_SENSITIVITY = Vector2.new(math.pi*4, math.pi*1.9)
CameraControls.DragBeginTypes = {Enum.UserInputType.MouseButton2, Enum.UserInputType.Touch}

function CameraControls.new()
	local self = setmetatable({}, CameraControls)

	self.Enabled = false
	self.Key = tostring(self) .. "CameraControls"
	self.GamepadRotate = GamepadRotate.new()


	return self
end

function CameraControls:SetZoomedCamera(ZoomedCamera)
	self.ZoomedCamera = ZoomedCamera or error()
	return self
end

function CameraControls:SetRotatedCamera(RotatedCamera)
	self.RotatedCamera = RotatedCamera or error()
	return self
end

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

--- This code was the same algorithm used by ROBLOX. It makes it so you can zoom easier at further distances.
function CameraControls:HandleMouseWheel(InputObject)
	if self.ZoomedCamera then
		local Delta = math.clamp(-InputObject.Position.Z, -1, 1)*1.4
		local Zoom = rk4Integrator(self.ZoomedCamera.TargetZoom, Delta, 1)

		self.ZoomedCamera.TargetZoom = Zoom
	end

	if self.RotatedCamera then
		if self.RotatedCamera.ClassName == "PushCamera" then
			self.RotatedCamera:StopRotateBack()
		end
	end
end

function CameraControls:MouseTranslationToAngle(translationVector)
	--- This is also a ROBLOX algorithm. Not sure why screen resolution is locked like it is.

	local xTheta = (translationVector.x / 1920)
	local yTheta = (translationVector.y / 1200)
	return Vector2.new(xTheta, yTheta)
end

function CameraControls:GetVelocityTracker(Strength, StartVelocity)
	Strength = Strength or 1

	local LastUpdate = tick()
	local Velocity = StartVelocity

	return {
		Update = function(self, Delta)
			local Elapsed = tick() - LastUpdate
			LastUpdate = tick()
			Velocity = Velocity / (2^(Elapsed/Strength)) + (Delta / (0.0001 + Elapsed)) * Strength
		end;
		GetVelocity = function(self)
			self:Update(StartVelocity*0)
			return Velocity
		end;
	}
end

function CameraControls:HandleMouseMovement(InputObject, IsMouse)
	if self.LastMousePosition then

		if self.RotatedCamera then
			-- This calculation may seem weird, but either .Position updates (if it's locked), or .Delta updates (if it's not).
			local Delta
			if IsMouse then
				Delta = -InputObject.Delta + self.LastMousePosition - InputObject.Position
			else
				Delta = -InputObject.Delta
			end

			local DeltaAngle = self:MouseTranslationToAngle(Delta) * self.MOUSE_SENSITIVITY
			self.RotatedCamera:RotateXY(DeltaAngle)

			if self.RotVelocityTracker then
				self.RotVelocityTracker:Update(DeltaAngle)
			end
		end

		self.LastMousePosition = InputObject.Position
	end
end


function CameraControls:HandleThumbstickInput(InputObject)
	self.GamepadRotate:HandleThumbstickInput(InputObject)
end

function CameraControls:BeginDrag(BeginInputObject)
	if not self.RotatedCamera then
		self.Maid.DragMaid = nil
		return
	end

	local maid = Maid.new()

	self.LastMousePosition = BeginInputObject.Position
	local IsMouse = BeginInputObject.UserInputType.Name:find("Mouse")

	if IsMouse then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end

	maid.InputEnded = UserInputService.InputEnded:Connect(function(InputObject, GameProcessed)
		if InputObject == BeginInputObject then
			self:EndDrag()
		end
	end)

	maid.InputChanged = UserInputService.InputChanged:Connect(function(InputObject)
		if IsMouse and InputObject.UserInputType == Enum.UserInputType.MouseMovement
			or InputObject == BeginInputObject then

			self:HandleMouseMovement(InputObject)
		end
	end)

	if self.RotatedCamera.ClassName == "SmoothRotatedCamera" then
		self.RotVelocityTracker = self:GetVelocityTracker(0.05, Vector2.new())
	end

	self.Maid.DragMaid = maid
end

function CameraControls:ApplyRotVelocityTracker(RotVelocityTracker)
	if self.RotatedCamera then
		local Position = self.RotatedCamera.AngleXZ
		local Velocity = RotVelocityTracker:GetVelocity().X
		local NewVelocityTarget = Position + Velocity
		local Target = self.RotatedCamera.TargetAngleXZ

		if math.abs(NewVelocityTarget - Position) > math.abs(Target - Position) then
			self.RotatedCamera.TargetAngleXZ = NewVelocityTarget
		end

		self.RotatedCamera:SnapIntoBounds()
	end
end

function CameraControls:EndDrag()
	if self.RotVelocityTracker then
		self:ApplyRotVelocityTracker(self.RotVelocityTracker)
		self.RotVelocityTracker = nil
	end

	self.LastMousePosition = nil
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default

	self.Maid.DragMaid = nil
end

function CameraControls:IsEnabled()
	return self.Enabled
end

function CameraControls:GetKey()
	return self.Key
end

function CameraControls:HandleGamepadRotateStop()
	if self.RotVelocityTracker then
		self:ApplyRotVelocityTracker(self.RotVelocityTracker)
		self.RotVelocityTracker = nil
	end

	self.Maid.DragMaid = nil
end

function CameraControls:HandleGamepadRotateStart()
	if not self.RotatedCamera then
		self.Maid.DragMaid = nil
		return
	end

	local maid = Maid.new()

	if self.RotatedCamera.ClassName == "SmoothRotatedCamera" then
		self.RotVelocityTracker = self:GetVelocityTracker(0.05, Vector2.new())
	end

	maid:GiveTask(RunService.Heartbeat:Connect(function()
		local DeltaAngle = self.GamepadRotate:GetThumbstickDeltaAngle()

		if self.RotatedCamera then
			self.RotatedCamera:RotateXY(DeltaAngle)
		end

		if self.RotVelocityTracker then
			self.RotVelocityTracker:Update(DeltaAngle)
		end
	end))

	self.Maid.DragMaid = maid
end

function CameraControls:Enable()
	if not self.Enabled then
		assert(not self.Maid)
		self.Enabled = true

		self.Maid = Maid.new()

		self.Maid:GiveTask(self.GamepadRotate.IsRotating.Changed:Connect(function()
			if self.GamepadRotate.IsRotating.Value then
				self:HandleGamepadRotateStart()
			else
				self:HandleGamepadRotateStop()
			end
		end))

		ContextActionService:BindAction(self.Key, function(ActionName, UserInputState, InputObject)
			if InputObject.UserInputType == Enum.UserInputType.MouseWheel then
				self:HandleMouseWheel(InputObject)
			end
		end, false, Enum.UserInputType.MouseWheel)

		ContextActionService:BindAction(self.Key .. "Drag", function(ActionName, UserInputState, InputObject)
			if UserInputState == Enum.UserInputState.Begin then
				self:BeginDrag(InputObject)
			end
		end, false, unpack(self.DragBeginTypes))

		ContextActionService:BindAction(self.Key .. "Rotate", function(ActionName, UserInputState, InputObject)
			self:HandleThumbstickInput(InputObject)
		end, false, Enum.KeyCode.Thumbstick2)

		self.Maid.Cleanup = function()
			ContextActionService:UnbindAction(self.Key)
			ContextActionService:UnbindAction(self.Key .. "Drag")
			ContextActionService:UnbindAction(self.Key .. "Rotate")
		end
	end
end

function CameraControls:Disable()
	if self.Enabled then
		self.Enabled = false

		self.Maid:DoCleaning()
		self.Maid = nil

		self.LastMousePosition = nil
	end
end

function CameraControls:Destroy()
	self:Disable()
	setmetatable(self, nil)
end

return CameraControls