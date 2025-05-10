--!strict
--[=[
	Data container for the state of a camera.
	@class CameraState
]=]

local require = require(script.Parent.loader).load(script)

local CameraFrame = require("CameraFrame")
local DuckTypeUtils = require("DuckTypeUtils")
local QFrame = require("QFrame")

local CameraState = {}
CameraState.ClassName = "CameraState"

export type CameraState = typeof(setmetatable(
	{} :: {
		CameraFrame: CameraFrame.CameraFrame,
		CameraFrameDerivative: CameraFrame.CameraFrame,
		CFrame: CFrame,
		Position: Vector3,
		Velocity: Vector3,
		FieldOfView: number,
	},
	{} :: typeof({ __index = CameraState })
))

--[=[
	Constructs a new CameraState
	@param cameraFrame (CameraFrame | Camera)?
	@param cameraFrameDerivative CameraFrame?
	@return CameraState
]=]
function CameraState.new(
	cameraFrame: (CameraFrame.CameraFrame | Camera)?,
	cameraFrameDerivative: CameraFrame.CameraFrame?
): CameraState
	local self: CameraState = setmetatable({} :: any, CameraState)

	if typeof(cameraFrame) == "Instance" then
		assert(cameraFrame:IsA("Camera"))

		cameraFrame =
			CameraFrame.new(QFrame.fromCFrameClosestTo(cameraFrame.CFrame, QFrame.new()), cameraFrame.FieldOfView)
	end

	assert(CameraFrame.isCameraFrame(cameraFrame) or type(cameraFrame) == "nil", "Bad cameraFrame")
	assert(
		CameraFrame.isCameraFrame(cameraFrameDerivative) or type(cameraFrameDerivative) == "nil",
		"Bad cameraFrameDerivative"
	)

	self.CameraFrame = cameraFrame or CameraFrame.new()
	self.CameraFrameDerivative = cameraFrameDerivative or CameraFrame.new()

	return self
end

--[=[
	Returns true if the result is a camera state
	@param value any
	@return boolean
]=]
function CameraState.isCameraState(value: any): boolean
	return DuckTypeUtils.isImplementation(CameraState, value)
end

--[=[
	@prop cframe CFrame
	@within CameraState
]=]
function CameraState.__index(self: CameraState, index)
	if index == "CFrame" then
		return self.CameraFrame.CFrame
	elseif index == "Position" then
		return self.CameraFrame.Position
	elseif index == "CameraFrame" then
		return rawget(self :: any, "CameraFrame")
	elseif index == "CameraFrameDerivative" then
		return rawget(self :: any, "CameraFrameDerivative")
	elseif index == "Velocity" then
		return self.CameraFrameDerivative.Position
	elseif index == "FieldOfView" then
		return self.CameraFrame.FieldOfView
	else
		return CameraState[index]
	end
end

function CameraState.__newindex(self: CameraState, index, value)
	if index == "CFrame" then
		self.CameraFrame.CFrame = value
	elseif index == "Position" then
		self.CameraFrame.Position = value
	elseif index == "Velocity" then
		self.CameraFrameDerivative.Position = value
	elseif index == "FieldOfView" then
		self.CameraFrame.FieldOfView = value
	elseif index == "CameraFrame" or index == "CameraFrameDerivative" then
		rawset(self :: any, index, value)
	else
		error(string.format("'%s' is not a valid index of CameraState", tostring(index)))
	end
end

--[=[
	Set another camera state. Typically used to set Workspace.CurrentCamera's state to match this camera's state
	@param camera Camera -- A CameraState to set, also accepts a Roblox Camera
]=]
function CameraState.Set(self: CameraState, camera: Camera)
	camera.FieldOfView = self.FieldOfView
	camera.CFrame = self.CFrame
end

return CameraState
