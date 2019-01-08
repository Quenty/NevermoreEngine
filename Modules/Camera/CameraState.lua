--- Data container for the state of a camera.
-- @classmod CameraState

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local QuaternionObject = require("QuaternionObject")

local CameraState = {}
CameraState.ClassName = "CameraState"
CameraState.FieldOfView = 0
CameraState.Quaterion = QuaternionObject.new()
CameraState.Position = Vector3.new()

function CameraState:__index(index)
	if index == "CFrame" then
		return QuaternionObject.toCFrame(self.Quaterion, self.Position)
	else
		return CameraState[index]
	end
end

function CameraState:__newindex(index, Value)
	if index == "CFrame" then
		rawset(self, "Position", Value.p)
		rawset(self, "Quaterion", QuaternionObject.fromCFrame(Value))
	elseif index == "FieldOfView" or index == "Position" or index == "Quaterion" then
		rawset(self, index, Value)
	else
		error(("'%s' is not a valid index of CameraState"):format(tostring(index)))
	end
end

--- Builds a new camera stack
-- @constructor
-- @param[opt=nil] camera
-- @treturn CameraState
function CameraState.new(camera)
	local self = setmetatable({}, CameraState)

	if camera then
		self.FieldOfView = camera.FieldOfView
		self.CFrame = camera.CFrame
	end

	return self
end

--- Current FieldOfView
-- @tfield number FieldOfView

--- Current CFrame
-- @tfield CFrame CFrame

--- Current Position
-- @tfield Vector3 Position

--- Quaternion representation of the rotation of the CameraState
-- @tfield Quaterion Quaternion


--- Adds two camera states together
-- @tparam CameraState other
function CameraState:__add(other)
	local cameraState = CameraState.new(self)
	cameraState.FieldOfView = self.FieldOfView + other.FieldOfView
	cameraState.Position = cameraState.Position + other.Position
	cameraState.Quaterion = self.Quaterion*other.Quaterion

	return cameraState
end

--- Subtract the camera state from another
-- @tparam CameraState other
function CameraState:__sub(other)
	local cameraState = CameraState.new(self)
	cameraState.FieldOfView = self.FieldOfView - other.FieldOfView
	cameraState.Position = cameraState.Position - other.Position
	cameraState.Quaterion = self.Quaterion/other.Quaterion
	return cameraState
end

--- Inverts camera state
function CameraState:__unm()
	local cameraState = CameraState.new(self)
	cameraState.FieldOfView = -self.FieldOfView
	cameraState.Position = -self.Position
	cameraState.Quaterion = -self.Quaterion
	return cameraState
end

--- Multiply camera state by percent effect
-- @tparam number other
function CameraState:__mul(other)
	local cameraState = CameraState.new(self)

	if type(other) == "number" then
		cameraState.FieldOfView = self.FieldOfView * other
		cameraState.Quaterion = self.Quaterion^other
		cameraState.Position = self.Position * other
	else
		error("Invalid other")
	end

	return cameraState
end

--- Set another camera state. Typically used to set Workspace.CurrentCamera's state to match this camera's state
-- @tparam Camera camera A CameraState to set, also accepts a Roblox Camera
-- @treturn nil
function CameraState:Set(camera)
	camera.FieldOfView = self.FieldOfView
	camera.CFrame = self.CFrame
end

return CameraState