--[=[
	Data container for the state of a camera.
	@class CameraState
]=]

local require = require(script.Parent.loader).load(script)

local QFrame = require("QFrame")
local CameraFrame = require("CameraFrame")

local CameraState = {}
CameraState.ClassName = "CameraState"

--[=[
	Returns true if the result is a camera state
	@param value any
	@return boolean
]=]
function CameraState.isCameraState(value)
	return getmetatable(value) == CameraState
end

--[=[
	Constructs a new CameraState
	@param cameraFrame CameraFrame | Camera
	@param cameraFrameDerivative CameraFrame?
	@return CameraState
]=]
function CameraState.new(cameraFrame, cameraFrameDerivative)
	local self = setmetatable({}, CameraState)

	if typeof(cameraFrame) == "Instance" then
		assert(cameraFrame:IsA("Camera"))

		cameraFrame = CameraFrame.new(QFrame.fromCFrameClosestTo(cameraFrame.CFrame, QFrame.new()), cameraFrame.FieldOfView)
	end

	assert(CameraFrame.isCameraFrame(cameraFrame) or type(cameraFrame) == "nil", "Bad cameraFrame")
	assert(CameraFrame.isCameraFrame(cameraFrameDerivative) or type(cameraFrameDerivative) == "nil",
		"Bad cameraFrameDerivative")

	self.CameraFrame = cameraFrame or CameraFrame.new()
	self.CameraFrameDerivative = cameraFrameDerivative or CameraFrame.new()

	return self
end

--[=[
	@prop cframe CFrame
	@within CameraState
]=]
function CameraState:__index(index)
	if index == "CFrame" then
		return self.CameraFrame.CFrame
	elseif index == "Position" then
		return self.CameraFrame.Position
	elseif index == "Velocity" then
		return self.CameraFrameDerivative.Position
	elseif index == "FieldOfView" then
		return self.CameraFrame.FieldOfView
	else
		return CameraState[index]
	end
end

function CameraState:__newindex(index, value)
	if index == "CFrame" then
		self.CameraFrame.CFrame = value
	elseif index == "Position" then
		self.CameraFrame.Position = value
	elseif index == "Velocity" then
		self.CameraFrameDerivative.Position = value
	elseif index == "FieldOfView" then
		self.CameraFrame.FieldOfView = value
	elseif index == "CameraFrame" or index == "CameraFrameDerivative" then
		rawset(self, index, value)
	else
		error(("'%s' is not a valid index of CameraState"):format(tostring(index)))
	end
end

--[=[
	Set another camera state. Typically used to set Workspace.CurrentCamera's state to match this camera's state
	@param camera Camera -- A CameraState to set, also accepts a Roblox Camera
]=]
function CameraState:Set(camera)
	camera.FieldOfView = self.FieldOfView
	camera.CFrame = self.CFrame
end

return CameraState