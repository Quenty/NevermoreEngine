local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local CameraState       = LoadCustomLibrary("CameraState")
local SummedCamera       = LoadCustomLibrary("SummedCamera")

local DefaultCamera = {}
DefaultCamera.ClassName = "DefaultCamera"

-- Intent: Hack to maintain default camera control 

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

function DefaultCamera:__add(Other)
	return SummedCamera.new(self, Other)
end

function DefaultCamera:__index(Index)
	if Index == "State" or Index == "CameraState" or Index == "Camera" then
		return rawget(self, "CameraState")
	else
		return DefaultCamera[Index]
	end
end

return DefaultCamera