--- Track a current part, whether it be a model or part
-- @classmod TrackCamera

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local CameraState = require("CameraState")
local SummedCamera = require("SummedCamera")

local TrackCamera = {}
TrackCamera.ClassName = "TrackCamera"
TrackCamera.FieldOfView = 0

--- Make new track camera
-- @constructor
-- @param[opt] cameraSubject The CameraSubject to look at. A Roblox part of Roblox model
function TrackCamera.new(cameraSubject)
	local self = setmetatable({}, TrackCamera)

	self.CameraSubject = cameraSubject

	return self
end

function TrackCamera:__add(other)
	return SummedCamera.new(self, other)
end

function TrackCamera:__newindex(index, value)
	if index == "CameraSubject" then
		assert(type(value) == "userdata" or type(value) == "nil",
			"CameraSubject must be a Roblox Model or Roblox Part or nil")

		if type(value) == "userdata" then
			assert(value:IsA("Model") or value:IsA("BasePart"), "CameraSubject must be a Model or BasePart")
		end

		rawset(self, index, value)
	elseif index == "FieldOfView" then
		rawset(self, index, value)
	else
		error(index .. " is not a valid member of TrackCamera")
	end
end

function TrackCamera:__index(index)
	if index == "State" or index == "CameraState" or index == "Camera" then
		local cameraSubject = self.CameraSubject
		local state = CameraState.new()
		state.FieldOfView = self.FieldOfView

		if cameraSubject then
			if cameraSubject:IsA("Model") then
				state.CFrame = cameraSubject:GetPrimaryPartCFrame()
			elseif cameraSubject:IsA("BasePart") then
				state.CFrame = cameraSubject.CFrame
			end
		end

		return state
	else
		return TrackCamera[index]
	end
end

return TrackCamera