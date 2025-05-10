--[=[
	Holds camera states and allows for the last camera state to be retrieved. Also
	initializes an impulse and default camera as the bottom of the stack. Is a singleton.

	@class CameraStackService
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraEffectUtils = require("CameraEffectUtils")
local CameraStack = require("CameraStack")
local CameraState = require("CameraState")
local DefaultCamera = require("DefaultCamera")
local ImpulseCamera = require("ImpulseCamera")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local CameraStackService = {}
CameraStackService.ServiceName = "CameraStackService"

export type CameraStackService = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_cameraStack: CameraStack.CameraStack,
		_rawDefaultCamera: DefaultCamera.DefaultCamera,
		_impulseCamera: ImpulseCamera.ImpulseCamera,
		_defaultCamera: CameraEffectUtils.CameraEffect,
		_key: string,
		_serviceBag: ServiceBag.ServiceBag,
		_started: boolean,
		_doNotUseDefaultCamera: boolean,
	},
	{} :: typeof({ __index = CameraStackService })
))
--[=[
	Initializes a new camera stack. Should be done via the ServiceBag.
	@param serviceBag ServiceBag
]=]
function CameraStackService.Init(self: CameraStackService, serviceBag: ServiceBag.ServiceBag)
	assert(ServiceBag.isServiceBag(serviceBag), "Not a valid service bag")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._maid = Maid.new()
	self._key = HttpService:GenerateGUID(false)

	self._cameraStack = self._maid:Add(CameraStack.new())

	-- Initialize default cameras
	self._rawDefaultCamera = self._maid:Add(DefaultCamera.new())

	self._impulseCamera = ImpulseCamera.new()
	self._defaultCamera = ((self :: any)._rawDefaultCamera + (self :: any)._impulseCamera):SetMode("Relative")

	-- Add camera to stack
	self:Add(self._defaultCamera)
end

function CameraStackService.GetRenderPriority(_self: CameraStackService): number
	return Enum.RenderPriority.Camera.Value + 75
end

function CameraStackService.Start(self: CameraStackService): ()
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
function CameraStackService.SetDoNotUseDefaultCamera(self: CameraStackService, doNotUseDefaultCamera: boolean): ()
	assert(not self._started, "Already started")

	self._doNotUseDefaultCamera = doNotUseDefaultCamera
end

--[=[
	Pushes a disable state onto the camera stack
	@return function -- Function to cancel disable
]=]
function CameraStackService.PushDisable(self: CameraStackService): () -> ()
	self:_ensureInitOrError()

	return self._cameraStack:PushDisable()
end

--[=[
	Outputs the camera stack. Intended for diagnostics.
]=]
function CameraStackService.PrintCameraStack(self: CameraStackService): ()
	self:_ensureInitOrError()

	return self._cameraStack:PrintCameraStack()
end

--[=[
	Returns the default camera
	@return SummedCamera -- DefaultCamera + ImpulseCamera
]=]
function CameraStackService.GetDefaultCamera(self: CameraStackService): CameraEffectUtils.CameraEffect
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
function CameraStackService.GetImpulseCamera(self: CameraStackService): ImpulseCamera.ImpulseCamera
	assert(self._impulseCamera, "Not initialized")

	return self._impulseCamera
end

--[=[
	Returns the default camera without any impulse cameras
	@return DefaultCamera
]=]
function CameraStackService.GetRawDefaultCamera(self: CameraStackService): DefaultCamera.DefaultCamera
	assert(self._rawDefaultCamera, "Not initialized")

	return self._rawDefaultCamera
end

--[=[
	Gets the camera current on the top of the stack
	@return CameraEffect
]=]
function CameraStackService.GetTopCamera(self: CameraStackService): CameraEffectUtils.CameraLike
	self:_ensureInitOrError()

	return self._cameraStack:GetTopCamera()
end

--[=[
	Retrieves the top state off the stack at this time
	@return CameraState?
]=]
function CameraStackService.GetTopState(self: CameraStackService): CameraState.CameraState?
	self:_ensureInitOrError()

	return self._cameraStack:GetTopState()
end

--[=[
	Returns a new camera state that retrieves the state below its set state.

	@return CustomCameraEffect -- Effect below
	@return (CameraState) -> () -- Function to set the state
]=]
function CameraStackService.GetNewStateBelow(self: CameraStackService)
	self:_ensureInitOrError()

	return self._cameraStack:GetNewStateBelow()
end

--[=[
	Retrieves the index of a state
	@param state CameraEffect
	@return number? -- index

]=]
function CameraStackService.GetIndex(self: CameraStackService, state: CameraEffectUtils.CameraEffect): number?
	self:_ensureInitOrError()

	return self._cameraStack:GetIndex(state)
end

--[=[
	Returns the current stack.

	:::warning
	Do not modify this stack, this is the raw memory of the stack
	:::

	@return { CameraState<T> }
]=]
function CameraStackService.GetRawStack(self: CameraStackService): { CameraEffectUtils.CameraLike }
	self:_ensureInitOrError()

	return self._cameraStack:GetStack()
end

--[=[
	Gets the global camera stack for this service

	@return CameraStack
]=]
function CameraStackService.GetCameraStack(self: CameraStackService): CameraStack.CameraStack
	self:_ensureInitOrError()

	return self._cameraStack
end

--[=[
	Removes the state from the stack
	@param state CameraState
]=]
function CameraStackService.Remove(self: CameraStackService, state: CameraEffectUtils.CameraEffect)
	self:_ensureInitOrError()

	return self._cameraStack:Remove(state)
end

--[=[
	Adds the state from the stack
	@param state CameraState
	@return () -> () -- Cleanup function
]=]
function CameraStackService.Add(self: CameraStackService, state: CameraEffectUtils.CameraEffect): () -> ()
	self:_ensureInitOrError()

	return self._cameraStack:Add(state)
end

function CameraStackService._ensureInitOrError(self: CameraStackService)
	assert(self._cameraStack, "Not initialized. Initialize via ServiceBag")
end

function CameraStackService.Destroy(self: CameraStackService)
	self._maid:DoCleaning()
end

return CameraStackService
