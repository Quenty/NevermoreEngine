--- Track a current part, whether it be a model or part
-- @classmod TrackCamera

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))

local CameraState = require("CameraState")
local SummedCamera = require("SummedCamera")

local TrackCamera = {}
TrackCamera.ClassName = "TrackCamera"
TrackCamera.FieldOfView = 0

--- Make new track camera
-- @constructor
-- @param[opt] CameraSubject The CameraSubject to look at. A ROBLOX part of ROBLOX model
function TrackCamera.new(CameraSubject)
	local self = setmetatable({}, TrackCamera)

	self.CameraSubject = CameraSubject

	return self
end

function TrackCamera:__add(other)
	return SummedCamera.new(self, other)
end

function TrackCamera:__newindex(Index, Value)
	if Index == "CameraSubject" then
		assert(type(Value) == "userdata" or type(Value) == "nil",
			"CameraSubject must be a ROBLOX Model or ROBLOX Part or nil")
		
		if type(Value) == "userdata" then
			assert(Value:IsA("Model") or Value:IsA("BasePart"), "CameraSubject must be a Model or BasePart")
		end

		rawset(self, Index, Value)
	elseif Index == "FieldOfView" then
		rawset(self, Index, Value)
	else
		error(Index .. " is not a valid member of TrackCamera")
	end
end

function TrackCamera:__index(Index)
	if Index == "State" or Index == "CameraState" or Index == "Camera" then
		local CameraSubject = self.CameraSubject
		local State = CameraState.new()
		State.FieldOfView = self.FieldOfView

		if CameraSubject then
			if CameraSubject:IsA("Model") then
				State.CoordinateFrame = CameraSubject:GetPrimaryPartCFrame()
			elseif CameraSubject:IsA("BasePart") then
				State.CoordinateFrame = CameraSubject.CFrame
			end
		end

		return State
	else
		return TrackCamera[Index]
	end
end

return TrackCamera