--- Like a rotated camera, except we end up pushing back to a default rotation.
-- This same behavior is seen in Roblox vehicle seats
-- @classmod PushCamera

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))

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
	self.CoordinateFrame = self.CoordinateFrame
end

--- Resets to default position automatically
function PushCamera:Reset()
	self.LastUpdateTime = 0
end

function PushCamera:__newindex(Index, Value)
	if Index == "CoordinateFrame" then
		local XZRotation = GetRotationInXZPlane(Value)
		self.AngleXZ = math.atan2(XZRotation.lookVector.x, XZRotation.lookVector.z) + math.pi

		local YRotation = XZRotation:toObjectSpace(Value).lookVector.y
		self.AngleY = math.asin(YRotation)
	elseif Index == "DefaultCoordinateFrame" then
		local XZRotation = GetRotationInXZPlane(Value)
		self.DefaultAngleXZ0 = math.atan2(XZRotation.lookVector.x, XZRotation.lookVector.z) + math.pi

		local YRotation = XZRotation:toObjectSpace(Value).lookVector.y
		self.AngleY = math.asin(YRotation)
	elseif Index == "AngleY" then
		self._AngleY = math.clamp(Value, self.MinY, self.MaxY)
	elseif Index == "AngleX" or Index == "AngleXZ" then
		self.LastUpdateTime = tick()
		self._AngleXZ0 = Value
	elseif Index == "MaxY" then
		assert(Value > self.MinY, "MaxY must be greater than MinY")
		self._MaxY = Value
		self.AngleY = self.AngleY -- Reclamp value
	elseif Index == "MinY" then
		assert(Value < self.MinY, "MinY must be less than MeeeaxY")
		self._MaxY = Value
		self.AngleY = self.AngleY -- Reclamp value
	elseif Index == "LastUpdateTime" then
		self._LastUpdateTime = Value
	elseif PushCamera[Index] ~= nil then
		rawset(self, Index, Value)
	else
		error(Index .. " is not a valid member or PushCamera")
	end
end

function PushCamera:__index(Index)
	if Index == "State" or Index == "CameraState" or Index == "Camera" then
		local State = CameraState.new()
		State.CoordinateFrame = self.CoordinateFrame
		return State
	elseif Index == "LastUpdateTime" then
		return self._LastUpdateTime
	elseif Index == "LookVector" then
		return self.Rotation.lookVector
	elseif Index == "CoordinateFrame" then
		return CFrame.Angles(0, self.AngleXZ, 0) * CFrame.Angles(self.AngleY, 0, 0)
	elseif Index == "AngleY" then
		return self._AngleY
	elseif Index == "PushBackDelta" then
		return tick() - self.LastUpdateTime - self.PushBackAfter
	elseif Index == "PercentFaded" then
		-- How far in we are to the animation. Starts at 0 upon update and goes slowly to 1.
		return math.clamp(self.PushBackDelta / self.FadeBackTime, 0, 1)
	elseif Index == "PercentFadedCurved" then
		-- A curved value of PercentFaded
		return self.PercentFaded ^ 2
	elseif Index == "AngleX" or Index == "AngleXZ" then
		return LerpNumber(self._AngleXZ0, self.DefaultAngleXZ0, self.PercentFadedCurved)
	elseif Index == "MaxY" then
		return self._MaxY
	elseif Index == "MinY" then
		return self._MinY
	else
		return PushCamera[Index]
	end
end

return PushCamera
