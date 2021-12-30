--[=[
	Track a current part, whether it be a model or part
	@class TrackCamera
]=]

local require = require(script.Parent.loader).load(script)

local CameraState = require("CameraState")
local SummedCamera = require("SummedCamera")

local TrackCamera = {}
TrackCamera.ClassName = "TrackCamera"
TrackCamera.FieldOfView = 0

--[=[
	Constructs a new TrackCamera

	@param cameraSubject Instance? -- The CameraSubject to look at. A Roblox part of Roblox model
	@return TrackCamera
]=]
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
		assert(typeof(value) == "Instance" and
			(value:IsA("BasePart") or value:IsA("Model") or value:IsA("Attachment") or value:IsA("Humanoid")),
			"CameraSubject must be a Roblox Model, Roblox Part, Attachment, Humanoid, or nil")

		rawset(self, index, value)
	elseif index == "FieldOfView" then
		rawset(self, index, value)
	else
		error(index .. " is not a valid member of TrackCamera")
	end
end

--[=[
	The current state.
	@readonly
	@prop CameraState CameraState
	@within TrackCamera
]=]
--[=[
	The current field of view.
	@prop FieldOfView number
	@within TrackCamera
]=]
--[=[
	The current field of view.
	@prop CameraSubject Instance
	@within TrackCamera
]=]

function TrackCamera:__index(index)
	if index == "CameraState" then
		local state = CameraState.new()
		state.FieldOfView = self.FieldOfView

		local cameraSubject = self.CameraSubject
		if cameraSubject then
			if cameraSubject:IsA("Model") then
				state.CFrame = cameraSubject:GetPrimaryPartCFrame()
			elseif cameraSubject:IsA("BasePart") then
				state.CFrame = cameraSubject.CFrame
			elseif cameraSubject:IsA("Attachment") then
				state.CFrame = cameraSubject.WorldCFrame
			elseif cameraSubject:IsA("Humanoid") then
				if cameraSubject.RootPart then
					state.CFrame = cameraSubject.RootPart.CFrame
				elseif cameraSubject.Parent and cameraSubject.Parent:IsA("Model") then
					state.CFrame = cameraSubject:GetPrimaryPartCFrame()
				end
			else
				error("Bad cameraSubject")
			end
		end

		return state
	else
		return TrackCamera[index]
	end
end

return TrackCamera