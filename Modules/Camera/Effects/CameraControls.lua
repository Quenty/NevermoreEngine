local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local MakeMaid          = LoadCustomLibrary("Maid").MakeMaid

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

function CameraControls:HandleMouseWheel(InputObject)
	self.ZoomCamera:ZoomIn(InputObject.Position.Z*1.4, -1.4, 1.4)
end

function CameraControls:MouseTranslationToAngle(translationVector)
	local xTheta = (translationVector.x / 1920)
	local yTheta = (translationVector.y / 1200)
	return Vector2.new(xTheta, yTheta)
end

function CameraControls:HandleMouseMovement(InputObject)
	if self.LastMousePosition then

		-- This calculation may seem weird, but either .Position updates (if it's locked), or .Delta updates (if it's not).
		local Delta = -InputObject.Delta + self.LastMousePosition - InputObject.Position
		self.RotationCamera:RotateXY(self:MouseTranslationToAngle(Delta) * self.MOUSE_SENSITIVITY)
		
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