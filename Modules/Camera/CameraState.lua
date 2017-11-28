local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local QuaternionObject = LoadCustomLibrary("QuaternionObject")

-- Intent: Data container for the state of a camera

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


-- Constructors
function CameraState.new(Cam)
	local self = setmetatable({}, CameraState)

	if Cam then
		self.FieldOfView = Cam.FieldOfView
		self.CFrame = Cam.CFrame
	end

	return self
end

-- Operators
function CameraState:__add(Other)
	local New = CameraState.new(self)
	New.FieldOfView = self.FieldOfView + Other.FieldOfView
	New.Position = New.Position + Other.Position
	New.Quaterion = self.Quaterion*Other.Quaterion

	return New
end

function CameraState:__sub(Other)
	local New = CameraState.new(self)
	New.FieldOfView = self.FieldOfView - Other.FieldOfView
	New.Position = New.Position - Other.Position
	New.Quaterion = self.Quaterion/Other.Quaterion

	return New
end

function CameraState:__unm()
	local New = CameraState.new(self)
	New.FieldOfView = -self.FieldOfView
	New.Position = -self.Position
	New.Quaterion = -self.Quaterion

	return New
end

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
-- @param CameraState A CameraState to set, also accepts a Roblox Camera
function CameraState:Set(CameraState)
	CameraState = CameraState or workspace.CurrentCamera

	CameraState.FieldOfView = self.FieldOfView
	CameraState.CFrame = self.CFrame
end

return CameraState