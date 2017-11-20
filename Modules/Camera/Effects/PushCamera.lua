local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local CameraState = LoadCustomLibrary("CameraState")
local SummedCamera = LoadCustomLibrary("SummedCamera")
local qMath = LoadCustomLibrary("qMath")
local qCFrame = LoadCustomLibrary("qCFrame")

local GetRotationInXZPlane = qCFrame.GetRotationInXZPlane
local ClampNumber = qMath.ClampNumber
local LerpNumber = qMath.LerpNumber

-- Intent: Like a rotated camera, except we end up pushing back to a default rotation.
-- This same behavior is seen in Roblox vehicle seats

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

function PushCamera:RotateXY(XYRotateVector)
	-- @param XYRotateVector Vector2, the delta rotation to apply

	self.AngleX = self.AngleX + XYRotateVector.x
	self.AngleY = self.AngleY + XYRotateVector.y
end

function PushCamera:StopRotateBack()
	self.CoordinateFrame = self.CoordinateFrame
end

function PushCamera:Reset()
	-- Resets to default position automatically

	self.LastUpdateTime = 0
end

function PushCamera:__add(Other)
	return SummedCamera.new(self, Other)
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
		self._AngleY = ClampNumber(Value, self.MinY, self.MaxY)
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
		local Angles = self.Angles
		return CFrame.Angles(0, self.AngleXZ, 0) * CFrame.Angles(self.AngleY, 0, 0)
	elseif Index == "AngleY" then
		return self._AngleY
	elseif Index == "PushBackDelta" then
		return tick() - self.LastUpdateTime - self.PushBackAfter
	elseif Index == "PercentFaded" then
		-- How far in we are to the animation. Starts at 0 upon update and goes slowly to 1.
		return ClampNumber(self.PushBackDelta / self.FadeBackTime, 0, 1)
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
