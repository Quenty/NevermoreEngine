--- Data container for the state of a camera.
-- @classmod CameraState

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local QFrame = require("QFrame")

local CameraState = {}
CameraState.ClassName = "CameraState"

function CameraState.isCameraState(value)
	return getmetatable(value) == CameraState
end
--- Builds a new camera stack
-- @constructor
-- @param[opt=nil] camera
-- @treturn CameraState
function CameraState.new(qFrame, fieldOfView)
	local self = setmetatable({}, CameraState)

	if typeof(qFrame) == "Instance" then
		assert(not fieldOfView)

		self.FieldOfView = qFrame.FieldOfView
		self.QFrame = QFrame.fromCFrameClosestTo(qFrame.CFrame, QFrame.new())
	elseif CameraState.isCameraState(qFrame) then
		assert(not fieldOfView)

		-- Assume it's a CameraState
		self.FieldOfView = assert(qFrame.FieldOfView)
		self.QFrame = assert(qFrame.QFrame)
	elseif QFrame.isQFrame(qFrame) then
		assert(type(fieldOfView) == "number")

		self.FieldOfView = fieldOfView
		self.QFrame = qFrame
	else
		assert(not qFrame)

		self.FieldOfView = 0
		self.QFrame = QFrame.new()
	end

	return self
end

function CameraState:__index(index)
	if index == "CFrame" then
		if not QFrame.toCFrame(self.QFrame) then
			print(self.QFrame)
			return CFrame.new()
		end

		return QFrame.toCFrame(self.QFrame)
	elseif index == "Position" then
		return QFrame.toPosition(self.QFrame)
	else
		return CameraState[index]
	end
end

function CameraState:__newindex(index, value)
	if index == "CFrame" then
		assert(typeof(value) == "CFrame")
		local qFrame = QFrame.fromCFrameClosestTo(value, self.QFrame)
		assert(qFrame) -- Yikes if this fails, but it occurs
		rawset(self, "QFrame", qFrame)
	elseif index == "Position" then
		assert(typeof(value) == "Vector3")

		local qFrame = self.QFrame
		rawset(self, "QFrame", QFrame.new(value.x, value.y, value.z, qFrame.W, qFrame.X, qFrame.Y, qFrame.Z))
	elseif index == "FieldOfView" or index == "QFrame" then
		rawset(self, index, value)
	else
		error(("'%s' is not a valid index of CameraState"):format(tostring(index)))
	end
end

function CameraState.__add(a, b)
	assert(CameraState.isCameraState(a) and CameraState.isCameraState(b),
		"CameraState + non-CameraState attempted")

	return CameraState.new(a.QFrame + b.QFrame, a.FieldOfView + b.FieldOfView)
end

function CameraState.__sub(a, b)
	assert(CameraState.isCameraState(a) and CameraState.isCameraState(b),
		"CameraState - non-CameraState attempted")

	return CameraState.new(a.QFrame - b.QFrame, a.FieldOfView - b.FieldOfView)
end

function CameraState.__unm(a)
	return CameraState.new(-a.QFrame, -a.FieldOfView)
end

function CameraState.__mul(a, b)
	if type(a) == "number" and CameraState.isCameraState(b) then
		return CameraState.new(a*b.QFrame, a*b.FieldOfView)
	elseif CameraState.isCameraState(b) and type(b) == "number" then
		return CameraState.new(a.QFrame*b, a.FieldOfView*b)
	elseif CameraState.isCameraState(a) and CameraState.isCameraState(b) then
		return CameraState.new(a.QFrame*b.QFrame, a.FieldOfView*b.FieldOfView)
	else
		error("CameraState * non-CameraState attempted")
	end
end

function CameraState.__div(a, b)
	if CameraState.isCameraState(a) and type(b) == "number" then
		return CameraState.new(a.QFrame/b, a.FieldOfView/b)
	else
		error("CameraState * non-CameraState attempted")
	end
end

function CameraState.__pow(a, b)
	if CameraState.isCameraState(a) and type(b) == "number" then
		return CameraState.new(a.QFrame^b, a.FieldOfView^b)
	else
		error("CameraState ^ non-CameraState attempted")
	end
end

--- Set another camera state. Typically used to set Workspace.CurrentCamera's state to match this camera's state
-- @tparam Camera camera A CameraState to set, also accepts a Roblox Camera
-- @treturn nil
function CameraState:Set(camera)
	camera.FieldOfView = self.FieldOfView
	camera.CFrame = self.CFrame
end

return CameraState