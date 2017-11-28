local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local CameraState = LoadCustomLibrary("CameraState")
local SummedCamera = LoadCustomLibrary("SummedCamera")
local MakeMaid = LoadCustomLibrary("Maid").MakeMaid

-- Intent: Update on heartbeat, must GC this camera state, unlike others. This
-- allows for camera effects to run on heartbeat and cache information once instead
-- of potentially going deeep into a tree and getting invoked multiple times

local HeartbeatCamera = {}
HeartbeatCamera.ClassName = "HeartbeatCamera"
HeartbeatCamera.ProfileName = "HeartbeatCamera"

function HeartbeatCamera.new(Camera)
	local self = setmetatable({}, HeartbeatCamera)
	
	self.Camera = Camera or error("No camera")
	self.Maid = MakeMaid()
	
	self.CurrentStateCache = self.Camera.CameraState or error("Camera state returned null")
	self.Maid.Heartbeat = RunService.Heartbeat:connect(function()
		debug.profilebegin(self.ProfileName)
		self.CurrentStateCache = self.Camera.CameraState or error("Camera state returned null")
		debug.profileend()
	end)
	
	return self
end

function HeartbeatCamera:ForceUpdateCache()
	self.CurrentStateCache = self.Camera.CameraState
end

function HeartbeatCamera:__add(Other)
	return SummedCamera.new(self, Other)
end

function HeartbeatCamera:Destroy()
	self.Maid:DoCleaning()
end

function HeartbeatCamera:__index(Index)
	if Index == "State" or Index == "CameraState" or Index == "Camera" then
		return self.CurrentStateCache
	elseif Index == "Focus" then
		return self.FocusCamera.CameraState
	elseif Index == "Origin" then
		return self.OriginCamera.CameraState
	else
		return HeartbeatCamera[Index]
	end
end

return HeartbeatCamera