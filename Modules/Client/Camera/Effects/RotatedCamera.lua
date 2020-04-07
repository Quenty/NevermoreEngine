--- Allow freedom of movement around a current place, much like the classic script works now.
-- Not intended to be use with the current character script. This is the rotation component.
-- Intended to be used with a SummedCamera, relative.
-- @classmod RotatedCamera

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local CameraState = require("CameraState")
local getRotationInXZPlane = require("getRotationInXZPlane")
local SummedCamera = require("SummedCamera")

local RotatedCamera = {}
RotatedCamera.ClassName = "RotatedCamera"

-- Max/Min aim up and down
RotatedCamera._maxY = math.rad(80)
RotatedCamera._minY = math.rad(-80)
RotatedCamera._angleXZ = 0
RotatedCamera._angleY = 0

function RotatedCamera.new()
	local self = setmetatable({}, RotatedCamera)

	return self
end

function RotatedCamera:__add(other)
	return SummedCamera.new(self, other)
end

---
-- @param xzrotvector Vector2, the delta rotation to apply
function RotatedCamera:RotateXY(xzrotvector)
	self.AngleX = self.AngleX + xzrotvector.x
	self.AngleY = self.AngleY + xzrotvector.y
end

function RotatedCamera:__newindex(index, value)
	if index == "CFrame" then
		local zxrot = getRotationInXZPlane(value)
		self.AngleXZ = math.atan2(zxrot.lookVector.x, zxrot.lookVector.z) + math.pi

		local yrot = zxrot:toObjectSpace(value).lookVector.y
		self.AngleY = math.asin(yrot)
	elseif index == "AngleY" then
		self._angleY = math.clamp(value, self.MinY, self.MaxY)
	elseif index == "AngleX" or index == "AngleXZ" then
		self._angleXZ = value
	elseif index == "MaxY" then
		assert(value >= self.MinY, "MaxY must be greater than MinY")
		self._maxY = value
		self.AngleY = self.AngleY -- Reclamp value
	elseif index == "MinY" then
		assert(value <= self.MaxY, "MinY must be less than MaxY")
		self._minY = value
		self.AngleY = self.AngleY -- Reclamp value
	elseif RotatedCamera[index] ~= nil then
		rawset(self, index, value)
	else
		error(index .. " is not a valid member or RotatedCamera")
	end
end

function RotatedCamera:__index(index)
	if index == "CameraState" then
		local state = CameraState.new()
		state.CFrame = self.CFrame
		return state
	elseif index == "LookVector" then
		return self.Rotation.lookVector
	elseif index == "CFrame" then
		return CFrame.Angles(0, self.AngleXZ, 0) * CFrame.Angles(self.AngleY, 0, 0)
	elseif index == "AngleY" then
		return self._angleY
	elseif index == "AngleX" or index == "AngleXZ" then
		return self._angleXZ
	elseif index == "MaxY" then
		return self._maxY
	elseif index == "MinY" then
		return self._minY
	else
		return RotatedCamera[index]
	end
end

return RotatedCamera