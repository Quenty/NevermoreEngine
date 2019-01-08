--- Like a rotated camera, except we end up pushing back to a default rotation.
-- This same behavior is seen in Roblox vehicle seats
-- @classmod PushCamera

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local CameraState = require("CameraState")
local SummedCamera = require("SummedCamera")
local qMath = require("qMath")
local qCFrame = require("qCFrame")

local GetRotationInXZPlane = qCFrame.GetRotationInXZPlane
local LerpNumber = qMath.LerpNumber

local PushCamera = {}
PushCamera.ClassName = "PushCamera"

-- Max/Min aim up and down
PushCamera._MaxY = math.rad(80)
PushCamera._MinY = math.rad(-80)
PushCamera._AngleXZ0 = 0 -- Initial
PushCamera._AngleY = 0
PushCamera.FadeBackTime = 0.5
PushCamera.DefaultAngleXZ0 = 0
PushCamera._LastUpdateTime = -1
PushCamera.PushBackAfter = 0.5

function PushCamera.new()
	local self = setmetatable({}, PushCamera)

	return self
end

function PushCamera:__add(other)
	return SummedCamera.new(self, other)
end
---
-- @param XYRotateVector Vector2, the delta rotation to apply
function PushCamera:RotateXY(XYRotateVector)
	self.AngleX = self.AngleX + XYRotateVector.x
	self.AngleY = self.AngleY + XYRotateVector.y
end

function PushCamera:StopRotateBack()
	self.CFrame = self.CFrame
end

--- Resets to default position automatically
function PushCamera:Reset()
	self.LastUpdateTime = 0
end

function PushCamera:__newindex(index, value)
	if index == "CFrame" then
		local XZRotation = GetRotationInXZPlane(value)
		self.AngleXZ = math.atan2(XZRotation.lookVector.x, XZRotation.lookVector.z) + math.pi

		local YRotation = XZRotation:toObjectSpace(value).lookVector.y
		self.AngleY = math.asin(YRotation)
	elseif index == "DefaultCFrame" then
		local XZRotation = GetRotationInXZPlane(value)
		self.DefaultAngleXZ0 = math.atan2(XZRotation.lookVector.x, XZRotation.lookVector.z) + math.pi

		local YRotation = XZRotation:toObjectSpace(value).lookVector.y
		self.AngleY = math.asin(YRotation)
	elseif index == "AngleY" then
		self._AngleY = math.clamp(value, self.MinY, self.MaxY)
	elseif index == "AngleX" or index == "AngleXZ" then
		self.LastUpdateTime = tick()
		self._AngleXZ0 = value
	elseif index == "MaxY" then
		assert(value > self.MinY, "MaxY must be greater than MinY")
		self._MaxY = value
		self.AngleY = self.AngleY -- Reclamp value
	elseif index == "MinY" then
		assert(value < self.MinY, "MinY must be less than MeeeaxY")
		self._MaxY = value
		self.AngleY = self.AngleY -- Reclamp value
	elseif index == "LastUpdateTime" then
		self._LastUpdateTime = value
	elseif PushCamera[index] ~= nil then
		rawset(self, index, value)
	else
		error(index .. " is not a valid member or PushCamera")
	end
end

function PushCamera:__index(index)
	if index == "State" or index == "CameraState" or index == "Camera" then
		local State = CameraState.new()
		State.CFrame = self.CFrame
		return State
	elseif index == "LastUpdateTime" then
		return self._LastUpdateTime
	elseif index == "LookVector" then
		return self.Rotation.lookVector
	elseif index == "CFrame" then
		return CFrame.Angles(0, self.AngleXZ, 0) * CFrame.Angles(self.AngleY, 0, 0)
	elseif index == "AngleY" then
		return self._AngleY
	elseif index == "PushBackDelta" then
		return tick() - self.LastUpdateTime - self.PushBackAfter
	elseif index == "PercentFaded" then
		-- How far in we are to the animation. Starts at 0 upon update and goes slowly to 1.
		return math.clamp(self.PushBackDelta / self.FadeBackTime, 0, 1)
	elseif index == "PercentFadedCurved" then
		-- A curved value of PercentFaded
		return self.PercentFaded ^ 2
	elseif index == "AngleX" or index == "AngleXZ" then
		return LerpNumber(self._AngleXZ0, self.DefaultAngleXZ0, self.PercentFadedCurved)
	elseif index == "MaxY" then
		return self._MaxY
	elseif index == "MinY" then
		return self._MinY
	else
		return PushCamera[index]
	end
end

return PushCamera
