--- Data container for the state of a camera.
-- @classmod CameraState

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local QuaternionObject = LoadCustomLibrary("QuaternionObject")

local CameraState = {}
CameraState.ClassName = "CameraState"
CameraState.FieldOfView = 0
CameraState.Quaterion = QuaternionObject.new()
CameraState.Position = Vector3.new()

function CameraState:__index(Index)
	if Index == "CFrame" or Index == "CoordinateFrame" then
		return QuaternionObject.toCFrame(self.Quaterion, self.Position)
	else
		return CameraState[Index]
	end
end

function CameraState:__newindex(Index, Value)
	if Index == "CFrame" or Index == "CoordinateFrame" then
		rawset(self, "Position", Value.p)
		rawset(self, "Quaterion", QuaternionObject.fromCFrame(Value))
	elseif Index == "FieldOfView" or Index == "Position" or Index == "Quaterion" then
		rawset(self, Index, Value)
	else
		error(("'%s' is not a valid index of CameraState"):format(tostring(Index)))
	end
end


--- Builds a new camera stack
-- @constructor
-- @param[opt=nil] Cam
-- @treturn CameraState
function CameraState.new(Cam)
	local self = setmetatable({}, CameraState)

	if Cam then
		self.FieldOfView = Cam.FieldOfView

		self.CFrame = Cam.CFrame
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
-- @tparam CameraState Other
function CameraState:__add(Other)
	local New = CameraState.new(self)
	New.FieldOfView = self.FieldOfView + Other.FieldOfView
	New.Position = New.Position + Other.Position
	New.Quaterion = self.Quaterion*Other.Quaterion

	return New
end

--- Subtract the camera state from another
-- @tparam CameraState Other
function CameraState:__sub(Other)
	local New = CameraState.new(self)
	New.FieldOfView = self.FieldOfView - Other.FieldOfView
	New.Position = New.Position - Other.Position
	New.Quaterion = self.Quaterion/Otcamher.Quaterion

	return New
end

--- Inverts camera state
function CameraState:__unm()
	local New = CameraState.new(self)
	New.FieldOfView = -self.FieldOfView
	New.Position = -self.Position
	New.Quaterion = -self.Quaterion

	return New
end

--- Multiply camera state by percent effect
-- @tparam number Other
function CameraState:__mul(Other)
	local New = CameraState.new(self)

	if type(Other) == "number" then
		New.FieldOfView = self.FieldOfView * Other
		New.Quaterion = self.Quaterion^Other
		New.Position = self.Position * Other
	else
		error("Invalid other")
	end

	return New
end

--- Set another camera state. Typically used to set workspace.CurrentCamera's state to match this camera's state
-- @tparam Camera CameraState A CameraState to set, also accepts a Roblox Camera
-- @treturn nil
function CameraState:Set(CameraState)
	CameraState = CameraState or workspace.CurrentCamera

	CameraState.FieldOfView = self.FieldOfView
	CameraState.CFrame = self.CFrame
end

return CameraState