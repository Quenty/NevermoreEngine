--[=[
	Holds camera states and allows for the last camera state to be retrieved. Also
	initializes an impulse and default camera as the bottom of the stack. Is a singleton.

	@class CameraStackService
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local CameraStack = require("CameraStack")
local DefaultCamera = require("DefaultCamera")
local ImpulseCamera = require("ImpulseCamera")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

assert(RunService:IsClient(), "[CameraStackService] - Only require CameraStackService on client")

local CameraStackService = {}
CameraStackService.ServiceName = "CameraStackService"

--[=[
	Initializes a new camera stack. Should be done via the ServiceBag.
	@param serviceBag ServiceBag
]=]
function CameraStackService:Init(serviceBag: ServiceBag.ServiceBag)
	assert(ServiceBag.isServiceBag(serviceBag), "Not a valid service bag")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._maid = Maid.new()
	self._key = HttpService:GenerateGUID(false)

	self._cameraStack = self._maid:Add(CameraStack.new())

	-- Initialize default cameras
	self._rawDefaultCamera = self._maid:Add(DefaultCamera.new())

	self._impulseCamera = ImpulseCamera.new()
	self._defaultCamera = (self._rawDefaultCamera + self._impulseCamera):SetMode("Relative")

	-- Add camera to stack
	self:Add(self._defaultCamera)
end

function CameraStackService:GetRenderPriority()
	return Enum.RenderPriority.Camera.Value + 75
end

function CameraStackService:Start()
	RunService:BindToRenderStep("CameraStackUpdateInternal" .. self._key, self:GetRenderPriority(), function()
		debug.profilebegin("camerastackservice")

		local state = self:GetTopState()

		self._rawDefaultCamera:SetLastSetCameraFrame(state.CameraFrame)

		if state then
			state:Set(Workspace.CurrentCamera)
		end


		debug.profileend()
	end)

	self._maid:GiveTask(function()
		RunService:UnbindFromRenderStep("CameraStackUpdateInternal" .. self._key)
	end)

	self._started = true

	-- TODO: Allow rebinding
	if self._doNotUseDefaultCamera then
		Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable

		-- TODO: Handle camera deleted too!
		Workspace.CurrentCamera:GetPropertyChangedSignal("CameraType"):Connect(function()
			Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		end)
	else
		self._maid:GiveTask(self._rawDefaultCamera:BindToRenderStep())
	end
end

--[=[
	Prevents the default camera from being used
	@param doNotUseDefaultCamera boolean
]=]
function CameraStackService:SetDoNotUseDefaultCamera(doNotUseDefaultCamera)
	assert(not self._started, "Already started")

	self._doNotUseDefaultCamera = doNotUseDefaultCamera
end

--[=[
	Pushes a disable state onto the camera stack
	@return function -- Function to cancel disable
]=]
function CameraStackService:PushDisable()
	assert(self._cameraStack, "Not initialized")

	return self._cameraStack:PushDisable()
end

--[=[
	Outputs the camera stack. Intended for diagnostics.
]=]
function CameraStackService:PrintCameraStack()
	assert(self._cameraStack, "Not initialized")

	return self._cameraStack:PrintCameraStack()
end

--[=[
	Returns the default camera
	@return SummedCamera -- DefaultCamera + ImpulseCamera
]=]
function CameraStackService:GetDefaultCamera()
	assert(self._defaultCamera, "Not initialized")

	return self._defaultCamera
end

--[=[
	Returns the impulse camera. Useful for adding camera shake.

	Shaking the camera:
	```lua
	self._cameraStackService:GetImpulseCamera():Impulse(Vector3.new(0.25, 0, 0.25*(math.random()-0.5)))
	```

	You can also sum the impulse camera into another effect to layer the shake on top of the effect
	as desired.

	```lua
	-- Adding global custom camera shake to a custom camera effect
	local customCameraEffect = ...
	return (customCameraEffect + self._cameraStackService:GetImpulseCamera()):SetMode("Relative")
	```

	@return ImpulseCamera
]=]
function CameraStackService:GetImpulseCamera()
	assert(self._impulseCamera, "Not initialized")

	return self._impulseCamera
end

--[=[
	Returns the default camera without any impulse cameras
	@return DefaultCamera
]=]
function CameraStackService:GetRawDefaultCamera()
	assert(self._rawDefaultCamera, "Not initialized")

	return self._rawDefaultCamera
end

--[=[
	Gets the camera current on the top of the stack
	@return CameraEffect
]=]
function CameraStackService:GetTopCamera()
	assert(self._cameraStack, "Not initialized")

	return self._cameraStack:GetTopCamera()
end

--[=[
	Retrieves the top state off the stack at this time
	@return CameraState?
]=]
function CameraStackService:GetTopState()
	assert(self._cameraStack, "Not initialized")

	return self._cameraStack:GetTopState()
end

--[=[
	Returns a new camera state that retrieves the state below its set state.

	@return CustomCameraEffect -- Effect below
	@return (CameraState) -> () -- Function to set the state
]=]
function CameraStackService:GetNewStateBelow()
	assert(self._cameraStack, "Not initialized")

	return self._cameraStack:GetNewStateBelow()
end

--[=[
	Retrieves the index of a state
	@param state CameraEffect
	@return number? -- index

]=]
function CameraStackService:GetIndex(state)
	assert(self._cameraStack, "Not initialized")

	return self._cameraStack:GetIndex(state)
end

--[=[
	Returns the current stack.

	:::warning
	Do not modify this stack, this is the raw memory of the stack
	:::

	@return { CameraState<T> }
]=]
function CameraStackService:GetRawStack()
	assert(self._cameraStack, "Not initialized")

	return self._cameraStack:GetRawStack()
end

--[=[
	Gets the global camera stack for this service

	@return CameraStack
]=]
function CameraStackService:GetCameraStack()
	assert(self._cameraStack, "Not initialized")

	return self._cameraStack
end

--[=[
	Removes the state from the stack
	@param state CameraState
]=]
function CameraStackService:Remove(state)
	assert(self._cameraStack, "Not initialized")

	return self._cameraStack:Remove(state)
end

--[=[
	Adds the state from the stack
	@param state CameraState
]=]
function CameraStackService:Add(state)
	assert(self._cameraStack, "Not initialized")

	return self._cameraStack:Add(state)
end

function CameraStackService:Destroy()
	self._maid:DoCleaning()
end

return CameraStackService