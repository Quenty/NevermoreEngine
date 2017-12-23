-- Hack to maintain default camera control by binding before and after the camera update cycle
-- This allows other cameras to build off of the "default" camera while maintaining the same Roblox control scheme
-- @classmod DefaultCamera

local RunService = game:GetService("RunService")
local require = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))

local CameraState = require("CameraState")
local SummedCamera = require("SummedCamera")

local DefaultCamera = {}
DefaultCamera.ClassName = "DefaultCamera"

SummedCamera.addToClass(DefaultCamera)

function DefaultCamera.new()
	local self = setmetatable({}, DefaultCamera)

	return self
end

function DefaultCamera:OverrideCameraState(CameraState)
	self.CameraState = CameraState or error("No CameraState")
end

function DefaultCamera:BindToRenderStep()
	RunService:BindToRenderStep("DefaultCamera_Preupdate", Enum.RenderPriority.Camera.Value-1, function()
		self.CameraState:Set()
	end)

	RunService:BindToRenderStep("DefaultCamera_PostUpdate", Enum.RenderPriority.Camera.Value+1, function()
		self.CameraState = CameraState.new(workspace.CurrentCamera)
	end)
	
	self.CameraState = CameraState.new(workspace.CurrentCamera)
end

function DefaultCamera:UnbindFromRenderStep()
	RunService:UnbindFromRenderStep("DefaultCamera_Preupdate")
	RunService:UnbindFromRenderStep("DefaultCamera_PostUpdate")
end

function DefaultCamera:__index(Index)
	if Index == "State" or Index == "CameraState" or Index == "Camera" then
		return rawget(self, "CameraState")
	else
		return DefaultCamera[Index]
	end
end

return DefaultCamera