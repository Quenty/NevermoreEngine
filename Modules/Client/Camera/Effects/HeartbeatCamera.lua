-- Update on heartbeat, must GC this camera state, unlike others. This
-- allows for camera effects to run on heartbeat and cache information once instead
-- of potentially going deeep into a tree and getting invoked multiple times
-- @classmod HeartbeatCamera

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")

local SummedCamera = require("SummedCamera")
local Maid = require("Maid")

local HeartbeatCamera = {}
HeartbeatCamera.ClassName = "HeartbeatCamera"
HeartbeatCamera.ProfileName = "HeartbeatCamera"

function HeartbeatCamera.new(Camera)
	local self = setmetatable({}, HeartbeatCamera)

	self.Camera = Camera or error("No camera")
	self.Maid = Maid.new()

	self.CurrentStateCache = self.Camera.CameraState or error("Camera state returned null")
	self.Maid.Heartbeat = RunService.Heartbeat:Connect(function()
		debug.profilebegin(self.ProfileName)
		self.CurrentStateCache = self.Camera.CameraState or error("Camera state returned null")
		debug.profileend()
	end)

	return self
end

function HeartbeatCamera:__add(other)
	return SummedCamera.new(self, other)
end

function HeartbeatCamera:ForceUpdateCache()
	self.CurrentStateCache = self.Camera.CameraState
end

function HeartbeatCamera:__index(index)
	if index == "State" or index == "CameraState" or index == "Camera" then
		return self.CurrentStateCache
	elseif index == "Focus" then
		return self.FocusCamera.CameraState
	elseif index == "Origin" then
		return self.OriginCamera.CameraState
	else
		return HeartbeatCamera[index]
	end
end

function HeartbeatCamera:Destroy()
	self.Maid:DoCleaning()
end

return HeartbeatCamera