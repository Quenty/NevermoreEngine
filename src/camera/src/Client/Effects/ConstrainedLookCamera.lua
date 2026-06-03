--!strict
--[=[
	Constrains pitch and yaw within a cone.

	@class ConstrainedLookCamera
]=]

local require = require(script.Parent.loader).load(script)

local CameraEffectUtils = require("CameraEffectUtils")
local CameraState = require("CameraState")
local Spring = require("Spring")
local SummedCamera = require("SummedCamera")

local ConstrainedLookCamera = {}
ConstrainedLookCamera.ClassName = "ConstrainedLookCamera"

export type ConstrainedLookCamera =
	typeof(setmetatable(
		{} :: {
			CameraState: CameraState.CameraState,
			CFrame: CFrame,
			AngleYaw: number,
			AnglePitch: number,
			TargetAngleYaw: number,
			TargetAnglePitch: number,
			MaxYawOffset: number,
			MaxPitchOffset: number,
			Speed: number,
			SpeedYaw: number,
			SpeedPitch: number,
			Damper: number,
			SpringYaw: Spring.Spring<number>,
			SpringPitch: Spring.Spring<number>,
		},
		{} :: typeof({ __index = ConstrainedLookCamera })
	))
	& CameraEffectUtils.CameraEffect

ConstrainedLookCamera._maxYawOffset = math.rad(20)
ConstrainedLookCamera._maxPitchOffset = math.rad(15)

--[=[
	Constructs a new ConstrainedLookCamera.
]=]
function ConstrainedLookCamera.new(): ConstrainedLookCamera
	local self: ConstrainedLookCamera = setmetatable({} :: any, ConstrainedLookCamera)

	self.SpringYaw = Spring.new(0)
	self.SpringPitch = Spring.new(0)
	self.Speed = 15
	self.Damper = 1

	return self
end

function ConstrainedLookCamera.__add(self: ConstrainedLookCamera, other: CameraEffectUtils.CameraEffect)
	return SummedCamera.new(self, other)
end

--[=[
	Rotates the target yaw (X) and pitch (Y) by the given delta, clamped within the max offsets.
]=]
function ConstrainedLookCamera.RotateXY(self: ConstrainedLookCamera, delta: Vector2)
	self.TargetAngleYaw += delta.X
	self.TargetAnglePitch += delta.Y
end

--[=[
	Releases input, sending spring targets back to the origin.
]=]
function ConstrainedLookCamera.Release(self: ConstrainedLookCamera)
	self.TargetAngleYaw = 0
	self.TargetAnglePitch = 0
end

--[=[
	Snaps springs to the origin without animating.
]=]
function ConstrainedLookCamera.SnapToOrigin(self: ConstrainedLookCamera)
	self.SpringYaw:SetTarget(0, true)
	self.SpringPitch:SetTarget(0, true)
end

function ConstrainedLookCamera.__newindex(self: ConstrainedLookCamera, index, value)
	if index == "AngleYaw" then
		self.SpringYaw.Position = math.clamp(value, -self.MaxYawOffset, self.MaxYawOffset)
	elseif index == "AnglePitch" then
		self.SpringPitch.Position = math.clamp(value, -self.MaxPitchOffset, self.MaxPitchOffset)
	elseif index == "TargetAngleYaw" then
		self.SpringYaw.Target = math.clamp(value, -self.MaxYawOffset, self.MaxYawOffset)
	elseif index == "TargetAnglePitch" then
		self.SpringPitch.Target = math.clamp(value, -self.MaxPitchOffset, self.MaxPitchOffset)
	elseif index == "MaxYawOffset" then
		assert(value >= 0, "MaxYawOffset must be non-negative")
		self._maxYawOffset = value
		self.TargetAngleYaw = self.SpringYaw.Target
	elseif index == "MaxPitchOffset" then
		assert(value >= 0, "MaxPitchOffset must be non-negative")
		self._maxPitchOffset = value
		self.TargetAnglePitch = self.SpringPitch.Target
	elseif index == "SpeedYaw" then
		self.SpringYaw.Speed = value
	elseif index == "SpeedPitch" then
		self.SpringPitch.Speed = value
	elseif index == "Speed" then
		self.SpringYaw.Speed = value
		self.SpringPitch.Speed = value
	elseif index == "Damper" then
		self.SpringYaw.Damper = value
		self.SpringPitch.Damper = value
	elseif ConstrainedLookCamera[index] ~= nil or index == "SpringYaw" or index == "SpringPitch" then
		rawset(self, index, value)
	else
		error(`{tostring(index)} is not a valid member of ConstrainedLookCamera`)
	end
end

function ConstrainedLookCamera.__index(self: ConstrainedLookCamera, index)
	if index == "CameraState" then
		local state = CameraState.new()
		state.CFrame = self.CFrame
		return state
	elseif index == "CFrame" then
		return CFrame.Angles(0, self.AngleYaw, 0) * CFrame.Angles(self.AnglePitch, 0, 0)
	elseif index == "AngleYaw" then
		return self.SpringYaw.Position
	elseif index == "AnglePitch" then
		return self.SpringPitch.Position
	elseif index == "TargetAngleYaw" then
		return self.SpringYaw.Target
	elseif index == "TargetAnglePitch" then
		return self.SpringPitch.Target
	elseif index == "MaxYawOffset" then
		return self._maxYawOffset
	elseif index == "MaxPitchOffset" then
		return self._maxPitchOffset
	else
		return ConstrainedLookCamera[index]
	end
end

return ConstrainedLookCamera
