local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local CameraState = LoadCustomLibrary("CameraState")
local SummedCamera = LoadCustomLibrary("SummedCamera")
local qCFrame = LoadCustomLibrary("qCFrame")

local GetRotationInXZPlane = qCFrame.GetRotationInXZPlane
local SpringPhysics = LoadCustomLibrary("SpringPhysics")

-- Intent: Allow freedom of movement around a current place, much like the classic script works now.
-- Not intended to be use with the current character script. This is the rotation component.

-- Intended to be used with a SummedCamera, relative.

local SmoothRotatedCamera = {}
SmoothRotatedCamera.ClassName = "SmoothRotatedCamera"

-- Max/Min aim up and down
SmoothRotatedCamera._MaxY = math.rad(80)
SmoothRotatedCamera._MinY = math.rad(-80)
SmoothRotatedCamera._ZoomGiveY = math.rad(5) -- ONly on th
--SmoothRotatedCamera._AngleXZ = 0
--SmoothRotatedCamera._AngleY = 0

function SmoothRotatedCamera.new()
	local self = setmetatable({}, SmoothRotatedCamera)
	
	self.SpringX = SpringPhysics.NumberSpring.New()
	self.SpringY = SpringPhysics.NumberSpring.New()
	self.Speed = 15
	
	return self
end

function SmoothRotatedCamera:RotateXY(XYRotateVector)
	-- @param XYRotateVector Vector2, the delta rotation to apply

	self.AngleX = self.AngleX + XYRotateVector.x
	self.AngleY = self.AngleY + XYRotateVector.y
	self.TargetAngleX = self.AngleX
	self.TargetAngleY = self.AngleY
end

function SmoothRotatedCamera:__add(Other)
	return SummedCamera.new(self, Other)
end

function SmoothRotatedCamera:__newindex(Index, Value)
	if Index == "CoordinateFrame" or Index == "CFrame" then
		local XZRotation = GetRotationInXZPlane(Value)
		self.AngleXZ = math.atan2(XZRotation.lookVector.x, XZRotation.lookVector.z) + math.pi

		local YRotation = XZRotation:toObjectSpace(Value).lookVector.y
		self.AngleY = math.asin(YRotation)
	elseif Index == "TargetCoordinateFrame" or Index == "TargetCFrame" then
		local XZRotation = GetRotationInXZPlane(Value)
		self.TargetAngleXZ = math.atan2(XZRotation.lookVector.x, XZRotation.lookVector.z) + math.pi

		local YRotation = XZRotation:toObjectSpace(Value).lookVector.y
		self.TargetAngleY = math.asin(YRotation)
	elseif Index == "AngleY" then
		self.SpringY.Value = Value
	elseif Index == "AngleX" or Index == "AngleXZ" then
		self.SpringX.Value = Value
	elseif Index == "TargetAngleY" then
		self.SpringY.Target = Value
	elseif Index == "TargetAngleX" or Index == "TargetAngleXZ" then
		self.SpringX.Target = Value
	elseif Index == "MaxY" then
		assert(Value >= self.MinY, "MaxY must be greater than MinY")
		self._MaxY = Value
		--self.TargetAngleY = self.TargetAngleY
		--self.AngleY = self.AngleY -- Reclamp value
	elseif Index == "MinY" then
		assert(Value <= self.MaxY, "MinY must be less than MaxY")
		self._MinY = Value
		--self.TargetAngleY = self.TargetAngleY
		--self.AngleY = self.AngleY -- Reclamp value
	elseif Index == "SpeedAngleX" or Index == "SpeedAngleXZ" then
		self.SpringX.Speed = Value
	elseif Index == "SpeedAngleY" then
		self.SpringY.Speed = Value
	elseif Index == "Speed" then
		self.SpeedAngleX = Value
		self.SpeedAngleY = Value
	elseif Index == "ZoomGiveY" then
		self._ZoomGiveY = Value
	elseif SmoothRotatedCamera[Index] ~= nil or Index == "SpringX" or Index == "SpringY" then
		rawset(self, Index, Value)
	else
		error(Index .. " is not a valid member or SmoothRotatedCamera")
	end
end

function SmoothRotatedCamera:SnapIntoBounds()
	self.TargetAngleY = math.clamp(self.TargetAngleY, self.MinY, self.MaxY)
end

function SmoothRotatedCamera:GetPastBounds(Angle)
	if Angle < self.MinY then
		return Angle - self.MinY
	elseif Angle > self.MaxY then
		return Angle - self.MaxY
	else
		return 0
	end
end

function SmoothRotatedCamera:__index(Index)
	if Index == "State" or Index == "CameraState" or Index == "Camera" then
		local State = CameraState.new()
		State.CoordinateFrame = self.CoordinateFrame
		return State
	elseif Index == "LookVector" then
		return self.Rotation.lookVector
	elseif Index == "CoordinateFrame" or Index == "CFrame" then
		return CFrame.Angles(0, self.RenderAngleXZ, 0) * CFrame.Angles(self.RenderAngleY, 0, 0)
	elseif Index == "TargetCoordinateFrame" or Index == "TargetCFrame" then
		return CFrame.Angles(0, self.TargetAngleXZ, 0) * CFrame.Angles(self.TargetAngleY, 0, 0)
	elseif Index == "RenderAngleY" then
		local Angle = self.AngleY
		local Past = self:GetPastBounds(Angle)
		
		local TimesOverBounds = math.abs(Past) / self.ZoomGiveY
		local Scale = (1 - 0.25 ^ math.abs(TimesOverBounds))
		
		if Past < 0 then
			return self.MinY - self.ZoomGiveY*Scale
		elseif Past > 0 then
			return self.MaxY + self.ZoomGiveY*Scale
		else
			return Angle
		end
	elseif Index == "RenderAngleX" or Index == "RenderAngleXZ" then
		return self.AngleX
	elseif Index == "AngleY" then
		return self.SpringY.Value
	elseif Index == "AngleX" or Index == "AngleXZ" then
		return self.SpringX.Value
	elseif Index == "TargetAngleY" then
		return self.SpringY.Target
	elseif Index == "TargetAngleX" or Index == "TargetAngleXZ" then
		return self.SpringX.Target
	elseif Index == "SpeedAngleY" then
		return self.SpringX.Speed
	elseif Index == "MaxY" then
		return self._MaxY
	elseif Index == "MinY" then
		return self._MinY
	elseif Index == "ZoomGiveY" then
		return self._ZoomGiveY
	else
		return SmoothRotatedCamera[Index]
	end
end

return SmoothRotatedCamera