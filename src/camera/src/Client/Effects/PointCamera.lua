--!strict
--[=[
	Point a current element
	@class PointCamera
]=]

local require = require(script.Parent.loader).load(script)

local CameraEffectUtils = require("CameraEffectUtils")
local CameraState = require("CameraState")
local SummedCamera = require("SummedCamera")

local PointCamera = {}
PointCamera.ClassName = "PointCamera"

export type PointCamera = typeof(setmetatable(
	{} :: {
		CameraState: CameraState.CameraState,
		OriginCamera: CameraEffectUtils.CameraEffect,
		FocusCamera: CameraEffectUtils.CameraEffect,
		Origin: CameraState.CameraState,
		Focus: CameraState.CameraState,
	},
	{} :: typeof({ __index = PointCamera })
)) & CameraEffectUtils.CameraEffect

--[=[
	Initializes a new PointCamera

	@param originCamera Camera -- A camera to use
	@param focusCamera Camera -- The Camera to look at.
]=]
function PointCamera.new(
	originCamera: CameraEffectUtils.CameraEffect,
	focusCamera: CameraEffectUtils.CameraEffect
): PointCamera
	local self: PointCamera = setmetatable({} :: any, PointCamera)

	self.OriginCamera = originCamera or error("Must have originCamera")
	self.FocusCamera = focusCamera or error("Must have focusCamera")

	return self
end

function PointCamera.__add(self: PointCamera, other: CameraEffectUtils.CameraEffect): SummedCamera.SummedCamera
	return SummedCamera.new(self, other)
end

function PointCamera.__newindex(self: PointCamera, index, value)
	if index == "OriginCamera" or index == "FocusCamera" then
		rawset(self, index, value)
	else
		error(index .. " is not a valid member of PointCamera")
	end
end

function PointCamera.__index(self: PointCamera, index)
	if index == "CameraState" then
		local origin, focus = self.Origin, self.Focus

		local state = CameraState.new()
		state.FieldOfView = origin.FieldOfView + focus.FieldOfView
		state.CFrame = CFrame.new(origin.Position, focus.Position)

		return state
	elseif index == "Focus" then
		return self.FocusCamera.CameraState
	elseif index == "Origin" then
		return self.OriginCamera.CameraState
	else
		return PointCamera[index]
	end
end

return PointCamera
