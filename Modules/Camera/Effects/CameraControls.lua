local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local MakeMaid          = LoadCustomLibrary("Maid").MakeMaid
local qMath             = LoadCustomLibrary("qMath")

local ClampNumber = qMath.ClampNumber

-- Intent: Interface between user input and camera controls

local CameraControls = {}
CameraControls.__index = CameraControls
CameraControls.ClassName = "CameraControls"
CameraControls.MOUSE_SENSITIVITY = Vector2.new(math.pi*4, math.pi*1.9)

function CameraControls.new()
	local self = setmetatable({}, CameraControls)

	self.Enabled = false

	return self
end

function CameraControls:SetZoomCamera(ZoomCamera)
	self.ZoomCamera = ZoomCamera or error()
	return self
end

function CameraControls:SetRotationCamera(RotationCamera)
	self.RotationCamera = RotationCamera or error()
	return self
end

local function rk4Integrator(position, velocity, t)
	-- Stolen directly from ROBLOX's core scripts.
	-- Looks like a simple integrator. 
	-- Called (zoom, zoomScale, 1) returns zoom

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

function CameraControls:HandleMouseWheel(InputObject)
	--- This code was the same algorithm used by ROBLOX. It makes it so you can zoom easier at further distances.

	local Delta = ClampNumber(-InputObject.Position.Z, -1, 1)*1.4
	local Zoom = rk4Integrator(self.ZoomCamera.TargetZoom, Delta, 1)

	if self.RotationCamera then
		if self.RotationCamera.ClassName == "PushCamera" then
			self.RotationCamera:StopRotateBack()
		end
	end

	self.ZoomCamera.TargetZoom = Zoom
end

function CameraControls:MouseTranslationToAngle(translationVector)
	--- This is also a ROBLOX algorithm. Not sure why screen resolution is locked like it is.

	local xTheta = (translationVector.x / 1920)
	local yTheta = (translationVector.y / 1200)
	return Vector2.new(xTheta, yTheta)
end

function CameraControls:HandleMouseMovement(InputObject)
	if self.LastMousePosition then

		if self.RotationCamera then
			-- This calculation may seem weird, but either .Position updates (if it's locked), or .Delta updates (if it's not).
			local Delta = -InputObject.Delta + self.LastMousePosition - InputObject.Position
			self.RotationCamera:RotateXY(self:MouseTranslationToAngle(Delta) * self.MOUSE_SENSITIVITY)
		end
		
		self.LastMousePosition = InputObject.Position
	end
end

function CameraControls:Enable()
	if not self.Enabled then
		self.Enabled = true

		self.Maid = MakeMaid()

		self.Maid.InputChanged = UserInputService.InputChanged:connect(function(InputObject, Processed)
			if InputObject.UserInputType.Name == "MouseWheel" then
				self:HandleMouseWheel(InputObject)
			elseif InputObject.UserInputType.Name == "MouseMovement" then
				self:HandleMouseMovement(InputObject)
			end
		end)

		self.Maid.InputBegan = UserInputService.InputBegan:connect(function(InputObject, Processed)
			if InputObject.UserInputType.Name == "MouseButton2" then
				self.LastMousePosition = InputObject.Position
				UserInputService.MouseBehavior = "LockCurrentPosition"
			end
		end)

		self.Maid.InputEnded = UserInputService.InputEnded:connect(function(InputObject, Processed)
			if InputObject.UserInputType.Name == "MouseButton2" then
				self.LastMousePosition = nil
				UserInputService.MouseBehavior = "Default"
			end
		end)
	end
end

function CameraControls:Disable()
	if self.Enabled then
		self.Enabled = false

		self.Maid:DoCleaning()
		self.Maid = nil

		self.LastMousePosition = nil
		UserInputService.MouseBehavior = "Default"
	end
end

function CameraControls:Destroy()
	self:Disable()
	setmetatable(self, nil)
end

return CameraControls