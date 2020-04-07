--- Allow freedom of movement around a current place, much like the classic script works now.
-- Not intended to be use with the current character script. This is the rotation component.
-- Intended to be used with a SummedCamera, relative.
-- @classmod SmoothRotatedCamera

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local CameraState = require("CameraState")
local getRotationInXZPlane = require("getRotationInXZPlane")
local Spring = require("Spring")
local SummedCamera = require("SummedCamera")

local SmoothRotatedCamera = {}
SmoothRotatedCamera.ClassName = "SmoothRotatedCamera"

-- Max/Min aim up and down
SmoothRotatedCamera._maxY = math.rad(80)
SmoothRotatedCamera._minY = math.rad(-80)
SmoothRotatedCamera._zoomGiveY = math.rad(5) -- Only on th

function SmoothRotatedCamera.new()
	local self = setmetatable({}, SmoothRotatedCamera)

	self.SpringX = Spring.new(0)
	self.SpringY = Spring.new(0)
	self.Speed = 15

	return self
end

function SmoothRotatedCamera:__add(other)
	return SummedCamera.new(self, other)
end

---
-- @param xyRotateVector Vector2, the delta rotation to apply
function SmoothRotatedCamera:RotateXY(xyRotateVector)
	self.AngleX = self.AngleX + xyRotateVector.x
	self.AngleY = self.AngleY + xyRotateVector.y
	self.TargetAngleX = self.AngleX
	self.TargetAngleY = self.AngleY
end

function SmoothRotatedCamera:__newindex(index, value)
	if index == "CFrame" then
		local xzrot = getRotationInXZPlane(value)
		self.AngleXZ = math.atan2(xzrot.lookVector.x, xzrot.lookVector.z) + math.pi

		local yrot = xzrot:toObjectSpace(value).lookVector.y
		self.AngleY = math.asin(yrot)
	elseif index == "TargetCFrame" then
		local xzrot = getRotationInXZPlane(value)
		self.TargetAngleXZ = math.atan2(xzrot.lookVector.x, xzrot.lookVector.z) + math.pi

		local yrot = xzrot:toObjectSpace(value).lookVector.y
		self.TargetAngleY = math.asin(yrot)
	elseif index == "AngleY" then
		self.SpringY.Value = value
	elseif index == "AngleX" or index == "AngleXZ" then
		self.SpringX.Value = value
	elseif index == "TargetAngleY" then
		self.SpringY.Target = value
	elseif index == "TargetAngleX" or index == "TargetAngleXZ" then
		self.SpringX.Target = value
	elseif index == "MaxY" then
		assert(value >= self.MinY, "MaxY must be greater than MinY")
		self._maxY = value
	elseif index == "MinY" then
		assert(value <= self.MaxY, "MinY must be less than MaxY")
		self._minY = value
	elseif index == "SpeedAngleX" or index == "SpeedAngleXZ" then
		self.SpringX.Speed = value
	elseif index == "SpeedAngleY" then
		self.SpringY.Speed = value
	elseif index == "Speed" then
		self.SpeedAngleX = value
		self.SpeedAngleY = value
	elseif index == "ZoomGiveY" then
		self._zoomGiveY = value
	elseif SmoothRotatedCamera[index] ~= nil or index == "SpringX" or index == "SpringY" then
		rawset(self, index, value)
	else
		error(index .. " is not a valid member or SmoothRotatedCamera")
	end
end

function SmoothRotatedCamera:SnapIntoBounds()
	self.TargetAngleY = math.clamp(self.TargetAngleY, self.MinY, self.MaxY)
end

function SmoothRotatedCamera:GetPastBounds(angle)
	if angle < self.MinY then
		return angle - self.MinY
	elseif angle > self.MaxY then
		return angle - self.MaxY
	else
		return 0
	end
end

function SmoothRotatedCamera:__index(index)
	if index == "CameraState" then
		local state = CameraState.new()
		state.CFrame = self.CFrame
		return state
	elseif index == "LookVector" then
		return self.Rotation.lookVector
	elseif index == "CFrame" then
		return CFrame.Angles(0, self.RenderAngleXZ, 0) * CFrame.Angles(self.RenderAngleY, 0, 0)
	elseif index == "TargetCFrame" then
		return CFrame.Angles(0, self.TargetAngleXZ, 0) * CFrame.Angles(self.TargetAngleY, 0, 0)
	elseif index == "RenderAngleY" then
		local angle = self.AngleY
		local past = self:GetPastBounds(angle)

		local timesOverBounds = math.abs(past) / self.ZoomGiveY
		local scale = (1 - 0.25 ^ math.abs(timesOverBounds))

		if past < 0 then
			return self.MinY - self.ZoomGiveY*scale
		elseif past > 0 then
			return self.MaxY + self.ZoomGiveY*scale
		else
			return angle
		end
	elseif index == "RenderAngleX" or index == "RenderAngleXZ" then
		return self.AngleX
	elseif index == "AngleY" then
		return self.SpringY.Value
	elseif index == "AngleX" or index == "AngleXZ" then
		return self.SpringX.Value
	elseif index == "TargetAngleY" then
		return self.SpringY.Target
	elseif index == "TargetAngleX" or index == "TargetAngleXZ" then
		return self.SpringX.Target
	elseif index == "SpeedAngleY" then
		return self.SpringX.Speed
	elseif index == "MaxY" then
		return self._maxY
	elseif index == "MinY" then
		return self._minY
	elseif index == "ZoomGiveY" then
		return self._zoomGiveY
	else
		return SmoothRotatedCamera[index]
	end
end

return SmoothRotatedCamera