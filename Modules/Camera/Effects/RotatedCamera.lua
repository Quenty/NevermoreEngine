--- Allow freedom of movement around a current place, much like the classic script works now.
-- Not intended to be use with the current character script. This is the rotation component.
-- Intended to be used with a SummedCamera, relative.
-- @classmod RotatedCamera

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))

local CameraState = require("CameraState")
local SummedCamera = require("SummedCamera")
local qCFrame = require("qCFrame")

local GetRotationInXZPlane = qCFrame.GetRotationInXZPlane

local RotatedCamera = {}
RotatedCamera.ClassName = "RotatedCamera"

SummedCamera.addToClass(RotatedCamera)

-- Max/Min aim up and down
RotatedCamera._MaxY = math.rad(80)
RotatedCamera._MinY = math.rad(-80)
RotatedCamera._AngleXZ = 0
RotatedCamera._AngleY = 0

function RotatedCamera.new()
	local self = setmetatable({}, RotatedCamera)

	return self
end

---
-- @param XYRotateVector Vector2, the delta rotation to apply
function RotatedCamera:RotateXY(XYRotateVector)
	self.AngleX = self.AngleX + XYRotateVector.x
	self.AngleY = self.AngleY + XYRotateVector.y
end

function RotatedCamera:__newindex(Index, Value)
	if Index == "CoordinateFrame" then
		local XZRotation = GetRotationInXZPlane(Value)
		self.AngleXZ = math.atan2(XZRotation.lookVector.x, XZRotation.lookVector.z) + math.pi

		local YRotation = XZRotation:toObjectSpace(Value).lookVector.y
		self.AngleY = math.asin(YRotation)
	elseif Index == "AngleY" then
		self._AngleY = math.clamp(Value, self.MinY, self.MaxY)
	elseif Index == "AngleX" or Index == "AngleXZ" then
		self._AngleXZ = Value
	elseif Index == "MaxY" then
		assert(Value >= self.MinY, "MaxY must be greater than MinY")
		self._MaxY = Value
		self.AngleY = self.AngleY -- Reclamp value
	elseif Index == "MinY" then
		assert(Value <= self.MaxY, "MinY must be less than MaxY")
		self._MinY = Value
		self.AngleY = self.AngleY -- Reclamp value
	elseif RotatedCamera[Index] ~= nil then
		rawset(self, Index, Value)
	else
		error(Index .. " is not a valid member or RotatedCamera")
	end
end

function RotatedCamera:__index(Index)
	if Index == "State" or Index == "CameraState" or Index == "Camera" then
		local State = CameraState.new()
		State.CoordinateFrame = self.CoordinateFrame
		return State
	elseif Index == "LookVector" then
		return self.Rotation.lookVector
	elseif Index == "CoordinateFrame" then
		return CFrame.Angles(0, self.AngleXZ, 0) * CFrame.Angles(self.AngleY, 0, 0)
	elseif Index == "AngleY" then
		return self._AngleY
	elseif Index == "AngleX" or Index == "AngleXZ" then
		return self._AngleXZ
	elseif Index == "MaxY" then
		return self._MaxY
	elseif Index == "MinY" then
		return self._MinY
	else
		return RotatedCamera[Index]
	end
end

return RotatedCamera