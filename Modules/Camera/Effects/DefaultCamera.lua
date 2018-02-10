-- Hack to maintain default camera control by binding before and after the camera update cycle
-- This allows other cameras to build off of the "default" camera while maintaining the same Roblox control scheme
-- @classmod DefaultCamera

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraState = require("CameraState")
local SummedCamera = require("SummedCamera")

local DefaultCamera = {}
DefaultCamera.ClassName = "DefaultCamera"

function DefaultCamera.new()
	local self = setmetatable({}, DefaultCamera)

	return self
end

function DefaultCamera:__add(other)
	return SummedCamera.new(self, other)
end

function DefaultCamera:OverrideCameraState(cameraState)
	self._cameraState = cameraState or error("No CameraState")
end

function DefaultCamera:BindToRenderStep()
	RunService:BindToRenderStep("DefaultCamera_Preupdate", Enum.RenderPriority.Camera.Value-1, function()
		self._cameraState:Set(Workspace.CurrentCamera)
	end)

	RunService:BindToRenderStep("DefaultCamera_PostUpdate", Enum.RenderPriority.Camera.Value+1, function()
		self._cameraState = CameraState.new(Workspace.CurrentCamera)
	end)

	self._cameraState = CameraState.new(Workspace.CurrentCamera)
end

function DefaultCamera:UnbindFromRenderStep()
	RunService:UnbindFromRenderStep("DefaultCamera_Preupdate")
	RunService:UnbindFromRenderStep("DefaultCamera_PostUpdate")
end

function DefaultCamera:__index(index)
	if index == "State" or index == "CameraState" or index == "Camera" then
		return rawget(self, "_cameraState")
	else
		return DefaultCamera[index]
	end
end

return DefaultCamera