--!strict
--[=[
	Point a current element but lag behind for a smoother experience
	@class LagPointCamera
]=]

local require = require(script.Parent.loader).load(script)

local CameraEffectUtils = require("CameraEffectUtils")
local CameraState = require("CameraState")
local Spring = require("Spring")
local SummedCamera = require("SummedCamera")

local LagPointCamera = {}
LagPointCamera.ClassName = "LagPointCamera"
LagPointCamera._FocusCamera = nil
LagPointCamera._OriginCamera = nil

export type LagPointCamera = typeof(setmetatable(
	{} :: {
		CameraState: CameraState.CameraState,
		Origin: CameraState.CameraState,
		FocusCamera: CameraEffectUtils.CameraEffect,
		OriginCamera: CameraEffectUtils.CameraEffect,
		FocusSpring: Spring.Spring<Vector3>,
		LastFocusUpdate: number,
		FocusPosition: Vector3,
		Speed: number,
	},
	{} :: typeof({ __index = LagPointCamera })
)) & CameraEffectUtils.CameraEffect

--[=[
	Camera that lags behind the actual camera.

	@param originCamera CameraEffect -- A camera to use
	@param focusCamera CameraEffect -- The Camera to look at.
	@return LagPointCamera
]=]
function LagPointCamera.new(
	originCamera: CameraEffectUtils.CameraEffect,
	focusCamera: CameraEffectUtils.CameraEffect
): LagPointCamera
	local self: LagPointCamera = setmetatable({} :: any, LagPointCamera)

	self.FocusSpring = Spring.new(Vector3.zero)
	self.OriginCamera = originCamera or error("Must have originCamera")
	self.FocusCamera = focusCamera or error("Must have focusCamera")
	self.Speed = 10

	return self
end

function LagPointCamera.__add(self: LagPointCamera, other)
	return SummedCamera.new(self, other)
end

function LagPointCamera.__newindex(self: LagPointCamera, index, value)
	if index == "FocusCamera" then
		rawset(self, "_" .. index, value)
		self.FocusSpring.Target = self.FocusCamera.CameraState.Position
		self.FocusSpring.Position = self.FocusSpring.Target
		self.FocusSpring.Velocity = Vector3.zero
	elseif index == "OriginCamera" then
		rawset(self, "_" .. index, value)
	elseif index == "LastFocusUpdate" or index == "FocusSpring" then
		rawset(self, index, value)
	elseif index == "Speed" or index == "Damper" or index == "Velocity" then
		self.FocusSpring[index] = value
	else
		error(tostring(index) .. " is not a valid member of LagPointCamera")
	end
end

function LagPointCamera.__index(self: LagPointCamera, index): any
	if index == "CameraState" then
		local origin, focusPosition = self.Origin, self.FocusPosition

		local state = CameraState.new()
		state.FieldOfView = origin.FieldOfView + self.FocusCamera.CameraState.FieldOfView
		state.CFrame = CFrame.new(origin.Position, focusPosition)

		return state
	elseif index == "FocusPosition" then
		local delta
		if self.LastFocusUpdate then
			delta = tick() - self.LastFocusUpdate
		end

		self.LastFocusUpdate = tick()
		self.FocusSpring.Target = self.FocusCamera.CameraState.Position

		if delta then
			self.FocusSpring:TimeSkip(delta)
		end

		return self.FocusSpring.Position
	elseif index == "Speed" or index == "Damper" or index == "Velocity" then
		return self.FocusSpring[index]
	elseif index == "Origin" then
		return self.OriginCamera.CameraState
	elseif index == "FocusCamera" or index == "OriginCamera" then
		return rawget(self, "_" .. index) or error("Internal error: index does not exist")
	else
		return LagPointCamera[index]
	end
end

return LagPointCamera
