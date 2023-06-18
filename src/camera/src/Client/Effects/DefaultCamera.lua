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
local Maid = require("Maid")
local CFrameUtils = require("CFrameUtils")
local CameraFrame = require("CameraFrame")

local EPSILON = 0.001

local DefaultCamera = {}
DefaultCamera.ClassName = "DefaultCamera"

--[=[
	Constructs a new DefaultCamera

	@return DefaultCamera
]=]
function DefaultCamera.new()
	local self = setmetatable({}, DefaultCamera)

	self._key = HttpService:GenerateGUID(false)
	self._maid = Maid.new()
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
function DefaultCamera:SetRobloxFieldOfView(fieldOfView)
	self._cameraState.FieldOfView = fieldOfView
end

-- Back compat
DefaultCamera.OverrideGlobalFieldOfView = DefaultCamera.SetRobloxFieldOfView

--[=[
	Sets the Roblox camera state to look at things

	@param cameraState CameraState
]=]
function DefaultCamera:SetRobloxCameraState(cameraState)
	self._cameraState = cameraState or error("No CameraState")
end

-- Back compat
DefaultCamera.OverrideCameraState = DefaultCamera.SetRobloxCameraState

--[=[
	Sets the CFrame of the Roblox Camera

	@param cframe CFrame
]=]
function DefaultCamera:SetRobloxCFrame(cframe)
	self._cameraState.CFrame = cframe
end

--[=[
	Gets the current Roblox camera state, free of any influence

	@return CameraState
]=]
function DefaultCamera:GetRobloxCameraState()
	return self._cameraState
end

--[=[
	Sets the camera state different

	@param cameraFrame CameraState | nil
]=]
function DefaultCamera:SetLastSetCameraFrame(cameraFrame)
	self._lastCameraFrame = CameraFrame.new(cameraFrame.QFrame, cameraFrame.FieldOfView)
end

--[=[
	Binds the camera to RunService RenderStepped event.

	:::tip
	Be sure to call UnbindFromRenderStep when using this.
	:::
]=]
function DefaultCamera:BindToRenderStep()
	local maid = Maid.new()

	RunService:BindToRenderStep("DefaultCamera_Preupdate" .. self._key, Enum.RenderPriority.Camera.Value-2, function()
		local camera = Workspace.CurrentCamera

		if self._lastCameraFrame then
			-- Assume something wrote these values and so we should
			-- pass these through to Roblox's camera

			if not CFrameUtils.areClose(self._lastCameraFrame.CFrame, camera.CFrame, EPSILON) then
				self._cameraState.CFrame = camera.CFrame
			end

			if math.abs(self._lastCameraFrame.FieldOfView - camera.FieldOfView) > EPSILON then
				self._cameraState.FieldOfView = camera.FieldOfView
			end

			self._lastCameraFrame = nil
		end

		-- Restore our state
		self._cameraState:Set(camera)
	end)

	RunService:BindToRenderStep("DefaultCamera_PostUpdate" .. self._key, Enum.RenderPriority.Camera.Value+2, function()
		-- Capture
		self._cameraState = CameraState.new(Workspace.CurrentCamera)
	end)

	maid:GiveTask(function()
		RunService:UnbindFromRenderStep("DefaultCamera_Preupdate" .. self._key)
		RunService:UnbindFromRenderStep("DefaultCamera_PostUpdate" .. self._key)
	end)

	self._cameraState = CameraState.new(Workspace.CurrentCamera)

	self._maid._binding = maid

	return maid
end

--[=[
	Unbinds the camera from the RunService
]=]
function DefaultCamera:UnbindFromRenderStep()
	self._maid._binding = nil
end

--[=[
	Cleans up the binding
]=]
function DefaultCamera:Destroy()
	self._maid:DoCleaning()
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
	elseif index == "_maid" or index == "_lastCameraFrame" or index == "_key" then
		return rawget(self, index)
	else
		return DefaultCamera[index]
	end
end

return DefaultCamera