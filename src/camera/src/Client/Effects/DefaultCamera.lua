--[=[
	Hack to maintain default camera control by binding before and after the camera update cycle
	This allows other cameras to build off of the "default" camera while maintaining the same Roblox control scheme.

	This camera is automatically setup by the [CameraStackService](/api/CameraStackService).
	@class DefaultCamera
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local CameraState = require("CameraState")
local SummedCamera = require("SummedCamera")

local DefaultCamera = {}
DefaultCamera.ClassName = "DefaultCamera"

--[=[
	Constructs a new DefaultCamera

	@return DefaultCamera
]=]
function DefaultCamera.new()
	local self = setmetatable({}, DefaultCamera)

	self._key = HttpService:GenerateGUID(false)
	self._cameraState = CameraState.new(Workspace.CurrentCamera)

	return self
end

function DefaultCamera:__add(other)
	return SummedCamera.new(self, other)
end

--[=[
	Overrides the global field of view in the cached camera state
	@param fieldOfView number
]=]
function DefaultCamera:OverrideGlobalFieldOfView(fieldOfView)
	self._cameraState.FieldOfView = fieldOfView
end

function DefaultCamera:OverrideCameraState(cameraState)
	self._cameraState = cameraState or error("No CameraState")
end

--[=[
	Binds the camera to RunService RenderStepped event.

	:::tip
	Be sure to call UnbindFromRenderStep when using this.
	:::
]=]
function DefaultCamera:BindToRenderStep()
	RunService:BindToRenderStep("DefaultCamera_Preupdate" .. self._key, Enum.RenderPriority.Camera.Value-2, function()
		self._cameraState:Set(Workspace.CurrentCamera)
	end)

	RunService:BindToRenderStep("DefaultCamera_PostUpdate" .. self._key, Enum.RenderPriority.Camera.Value+2, function()
		self._cameraState = CameraState.new(Workspace.CurrentCamera)
	end)

	self._cameraState = CameraState.new(Workspace.CurrentCamera)
end

--[=[
	Unbinds the camera from the RunService
]=]
function DefaultCamera:UnbindFromRenderStep()
	RunService:UnbindFromRenderStep("DefaultCamera_Preupdate" .. self._key)
	RunService:UnbindFromRenderStep("DefaultCamera_PostUpdate" .. self._key)
end

--[=[
	Cleans up the binding
]=]
function DefaultCamera:Destroy()
	self:UnbindFromRenderStep()
end

--[=[
	The current state.
	@readonly
	@prop CameraState CameraState
	@within DefaultCamera
]=]
function DefaultCamera:__index(index)
	if index == "CameraState" then
		return rawget(self, "_cameraState")
	else
		return DefaultCamera[index]
	end
end

return DefaultCamera