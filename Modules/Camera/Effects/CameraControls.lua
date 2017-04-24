local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local ContextActionService  = game:GetService("ContextActionService")

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
CameraControls.DragBeginTypes = {Enum.UserInputType.MouseButton2, Enum.UserInputType.Touch}

function CameraControls.new()
	local self = setmetatable({}, CameraControls)

	self.Enabled = false
	self.Key = tostring(self) .. "CameraControls"
	
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

	if self.ZoomedCamera then
		local Delta = ClampNumber(-InputObject.Position.Z, -1, 1)*1.4
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

function CameraControls:BeginDrag(BeginInputObject)
	if not self.RotatedCamera then
		self.Maid.DragMaid = nil
		return
	end
	
	local Maid = MakeMaid()
	
	self.LastMousePosition = BeginInputObject.Position
	local IsMouse = BeginInputObject.UserInputType.Name:find("Mouse")
	
	if IsMouse then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end
	
	Maid.InputEnded = UserInputService.InputEnded:connect(function(InputObject, GameProcessed)
		if InputObject == BeginInputObject then
			self:EndDrag()
		end
	end)
	
	Maid.InputChanged = UserInputService.InputChanged:connect(function(InputObject)
		if IsMouse and InputObject.UserInputType == Enum.UserInputType.MouseMovement 
			or InputObject == BeginInputObject then
			
			self:HandleMouseMovement(InputObject)
		end
	end)

	
	
	if self.RotatedCamera.ClassName == "SmoothRotatedCamera" then
		self.RotVelocityTracker = self:GetVelocityTracker(0.05, Vector2.new())
	end
	
	
	
	self.Maid.DragMaid = Maid
end


function CameraControls:EndDrag()
	if self.RotVelocityTracker then
		local Position = self.RotatedCamera.AngleXZ
		local Velocity = self.RotVelocityTracker:GetVelocity().X
		local NewVelocityTarget = Position + Velocity
		local Target = self.RotatedCamera.TargetAngleXZ
		
		if math.abs(NewVelocityTarget - Position) > math.abs(Target - Position) then
			self.RotatedCamera.TargetAngleXZ = NewVelocityTarget
		end
		
		self.RotVelocityTracker = nil
		
		self.RotatedCamera:SnapIntoBounds()
	end
	self.LastMousePosition = nil
	self.Velocity = nil
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	
	self.Maid.DragMaid = nil
end

function CameraControls:IsEnabled()
	return self.Enabled
end

function CameraControls:GetKey()
	return self.Key
end

function CameraControls:Enable()
	if not self.Enabled then
		assert(not self.Maid)
		self.Enabled = true

		self.Maid = MakeMaid()
		
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
		
		self.Maid.Cleanup = function()
			ContextActionService:UnbindAction(self.Key)
			ContextActionService:UnbindAction(self.Key .. "Drag")
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