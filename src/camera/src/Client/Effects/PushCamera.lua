--!strict
--[=[
	Like a rotated camera, except we end up pushing back to a default rotation.
	This same behavior is seen in Roblox vehicle seats

	@class PushCamera
]=]

local require = require(script.Parent.loader).load(script)

local CameraEffectUtils = require("CameraEffectUtils")
local CameraState = require("CameraState")
local Math = require("Math")
local SummedCamera = require("SummedCamera")
local getRotationInXZPlane = require("getRotationInXZPlane")

local PushCamera = {}
PushCamera.ClassName = "PushCamera"

-- Max/Min aim up and down
PushCamera._maxY = math.rad(80)
PushCamera._minY = math.rad(-80)
PushCamera._angleXZ0 = 0 -- Initial
PushCamera._angleY = 0
PushCamera.FadeBackTime = 0.5
PushCamera.DefaultAngleXZ0 = 0
PushCamera._lastUpdateTime = -1
PushCamera.PushBackAfter = 0.5

export type PushCamera = typeof(setmetatable(
	{} :: {
		CameraState: CameraState.CameraState,
		AngleX: number,
		AngleY: number,
		AngleXZ: number,
		LastUpdateTime: number,
		MinX: number,
		MinY: number,
		MaxY: number,
		Rotation: CFrame,
		CFrame: CFrame,
		PushBackDelta: number,
		PercentFaded: number,
		PercentFadedCurved: number,
	},
	{} :: typeof({ __index = PushCamera })
)) & CameraEffectUtils.CameraEffect

--[=[
	Constructs a new PushCamera
	@return PushCamera
]=]
function PushCamera.new(): PushCamera
	local self: PushCamera = setmetatable({} :: any, PushCamera)

	return self
end

function PushCamera.__add(self: PushCamera, other)
	return SummedCamera.new(self, other)
end

--[=[
	@param xzrotVector Vector2 -- The delta rotation to apply
]=]
function PushCamera.RotateXY(self: PushCamera, xzrotVector)
	self.AngleX = self.AngleX + xzrotVector.x
	self.AngleY = self.AngleY + xzrotVector.y
end

--[=[
	Prevents the rotation back. You need to call this
	every frame you want to prevent rotation.
]=]
function PushCamera.StopRotateBack(self: PushCamera)
	self.CFrame = self.CFrame
end

--[=[
	Resets to default position automatically
]=]
function PushCamera.Reset(self: PushCamera)
	self.LastUpdateTime = 0
end

function PushCamera.__newindex(self: PushCamera, index, value)
	if index == "CFrame" then
		local xzrot = getRotationInXZPlane(value)
		self.AngleXZ = math.atan2(xzrot.LookVector.X, xzrot.LookVector.Z) + math.pi

		local yrot = xzrot:ToObjectSpace(value).LookVector.Y
		self.AngleY = math.asin(yrot)
	elseif index == "DefaultCFrame" then
		local xzrot = getRotationInXZPlane(value)
		self.DefaultAngleXZ0 = math.atan2(xzrot.LookVector.X, xzrot.LookVector.Z) + math.pi

		local yrot = xzrot:ToObjectSpace(value).LookVector.Y
		self.AngleY = math.asin(yrot)
	elseif index == "AngleY" then
		self._angleY = math.clamp(value, self.MinY, self.MaxY)
	elseif index == "AngleX" or index == "AngleXZ" then
		self.LastUpdateTime = tick()
		self._angleXZ0 = value
	elseif index == "MaxY" then
		assert(value > self.MinY, "MaxY must be greater than MinY")
		self._maxY = value
		self.AngleY = self.AngleY -- Reclamp value
	elseif index == "MinY" then
		assert(value < self.MinY, "MinY must be less than MeeeaxY")
		self._maxY = value
		self.AngleY = self.AngleY -- Reclamp value
	elseif index == "LastUpdateTime" then
		self._lastUpdateTime = value
	elseif PushCamera[index] ~= nil then
		rawset(self, index, value)
	else
		error(index .. " is not a valid member or PushCamera")
	end
end

--[=[
	The current state.
	@readonly
	@prop CameraState CameraState
	@within PushCamera
]=]
function PushCamera.__index(self: PushCamera, index)
	if index == "CameraState" then
		local state = CameraState.new()
		state.CFrame = self.CFrame
		return state
	elseif index == "LastUpdateTime" then
		return self._lastUpdateTime
	elseif index == "LookVector" then
		return self.Rotation.LookVector
	elseif index == "CFrame" then
		return CFrame.Angles(0, self.AngleXZ, 0) * CFrame.Angles(self.AngleY, 0, 0)
	elseif index == "AngleY" then
		return self._angleY
	elseif index == "PushBackDelta" then
		return tick() - self.LastUpdateTime - self.PushBackAfter
	elseif index == "PercentFaded" then
		-- How far in we are to the animation. Starts at 0 upon update and goes slowly to 1.
		return math.clamp(self.PushBackDelta / self.FadeBackTime, 0, 1)
	elseif index == "PercentFadedCurved" then
		-- A curved value of PercentFaded
		return self.PercentFaded ^ 2
	elseif index == "AngleX" or index == "AngleXZ" then
		return Math.lerp(self._angleXZ0, self.DefaultAngleXZ0, self.PercentFadedCurved)
	elseif index == "MaxY" then
		return self._maxY
	elseif index == "MinY" then
		return self._minY
	else
		return PushCamera[index]
	end
end

return PushCamera
