--- Data container for the state of a camera.
-- @classmod CameraState

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local QFrame = require("QFrame")
local CameraFrame = require("CameraFrame")

local CameraState = {}
CameraState.ClassName = "CameraState"

function CameraState.isCameraState(value)
	return getmetatable(value) == CameraState
end
--- Builds a new camera stack
-- @constructor
-- @param[opt=nil] camera
-- @treturn CameraState
function CameraState.new(cameraFrame, cameraFrameDerivative)
	local self = setmetatable({}, CameraState)

	if typeof(cameraFrame) == "Instance" then
		assert(cameraFrame:IsA("Camera"))

		cameraFrame = CameraFrame.new(QFrame.fromCFrameClosestTo(cameraFrame.CFrame, QFrame.new()), cameraFrame.FieldOfView)
	end

	assert(CameraFrame.isCameraFrame(cameraFrame) or type(cameraFrame) == "nil")
	assert(CameraFrame.isCameraFrame(cameraFrameDerivative) or type(cameraFrameDerivative) == "nil")

	self.CameraFrame = cameraFrame or CameraFrame.new()
	self.CameraFrameDerivative = cameraFrameDerivative or CameraFrame.new()

	return self
end

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

-- function CameraState.__add(a, b)
-- 	assert(CameraState.isCameraState(a) and CameraState.isCameraState(b),
-- 		"CameraState + non-CameraState attempted")

-- 	return CameraState.new(a.QFrame + b.QFrame, a.FieldOfView + b.FieldOfView)
-- end

-- function CameraState.__sub(a, b)
-- 	assert(CameraState.isCameraState(a) and CameraState.isCameraState(b),
-- 		"CameraState - non-CameraState attempted")

-- 	return CameraState.new(a.QFrame - b.QFrame, a.FieldOfView - b.FieldOfView)
-- end

-- function CameraState.__unm(a)
-- 	return CameraState.new(-a.QFrame, -a.FieldOfView)
-- end

-- function CameraState.__mul(a, b)
-- 	if type(a) == "number" and CameraState.isCameraState(b) then
-- 		return CameraState.new(a*b.QFrame, a*b.FieldOfView)
-- 	elseif CameraState.isCameraState(b) and type(b) == "number" then
-- 		return CameraState.new(a.QFrame*b, a.FieldOfView*b)
-- 	elseif CameraState.isCameraState(a) and CameraState.isCameraState(b) then
-- 		return CameraState.new(a.QFrame*b.QFrame, a.FieldOfView*b.FieldOfView)
-- 	else
-- 		error("CameraState * non-CameraState attempted")
-- 	end
-- end

-- function CameraState.__div(a, b)
-- 	if CameraState.isCameraState(a) and type(b) == "number" then
-- 		return CameraState.new(a.QFrame/b, a.FieldOfView/b)
-- 	else
-- 		error("CameraState * non-CameraState attempted")
-- 	end
-- end

-- function CameraState.__pow(a, b)
-- 	if CameraState.isCameraState(a) and type(b) == "number" then
-- 		return CameraState.new(a.QFrame^b, a.FieldOfView^b)
-- 	else
-- 		error("CameraState ^ non-CameraState attempted")
-- 	end
-- end

--- Set another camera state. Typically used to set Workspace.CurrentCamera's state to match this camera's state
-- @tparam Camera camera A CameraState to set, also accepts a Roblox Camera
-- @treturn nil
function CameraState:Set(camera)
	camera.FieldOfView = self.FieldOfView
	camera.CFrame = self.CFrame
end

return CameraState