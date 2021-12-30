--[=[
	Holds camera states and allows for the last camera state to be retrieved. Also
	initializes an impulse and default camera as the bottom of the stack. Is a singleton.

	@class CameraStackService
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local CustomCameraEffect = require("CustomCameraEffect")
local DefaultCamera = require("DefaultCamera")
local ImpulseCamera = require("ImpulseCamera")
local ServiceBag = require("ServiceBag")

assert(RunService:IsClient(), "[CameraStackService] - Only require CameraStackService on client")

local CameraStackService = {}

--[=[
	Initializes a new camera stack. Should be done via the ServiceBag.
	@param serviceBag ServiceBag
]=]
function CameraStackService:Init(serviceBag)
	assert(ServiceBag.isServiceBag(serviceBag), "Not a valid service bag")

	self._stack = {}
	self._disabledSet = {}

	-- Initialize default cameras
	self._rawDefaultCamera = DefaultCamera.new()
	self._impulseCamera = ImpulseCamera.new()
	self._defaultCamera = (self._rawDefaultCamera + self._impulseCamera):SetMode("Relative")

	if self._doNotUseDefaultCamera then
		Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable

		-- TODO: Handle camera deleted too!
		Workspace.CurrentCamera:GetPropertyChangedSignal("CameraType"):Connect(function()
			Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		end)
	else
		self._rawDefaultCamera:BindToRenderStep()
	end

	-- Add camera to stack
	self:Add(self._defaultCamera)

	RunService:BindToRenderStep("CameraStackUpdateInternal", Enum.RenderPriority.Camera.Value + 75, function()
		debug.profilebegin("CameraStackUpdate")

		if next(self._disabledSet) then
			return
		end

		local state = self:GetTopState()
		if state then
			state:Set(Workspace.CurrentCamera)
		end

		debug.profileend()
	end)
end

--[=[
	Prevents the default camera from being used
	@param doNotUseDefaultCamera boolean
]=]
function CameraStackService:SetDoNotUseDefaultCamera(doNotUseDefaultCamera)
	assert(not self._stack, "Already initialized")

	self._doNotUseDefaultCamera = doNotUseDefaultCamera
end

--[=[
	Pushes a disable state onto the camera stack
	@return function -- Function to cancel disable
]=]
function CameraStackService:PushDisable()
	assert(self._stack, "Not initialized")

	local disabledKey = HttpService:GenerateGUID(false)

	self._disabledSet[disabledKey] = true

	return function()
		self._disabledSet[disabledKey] = nil
	end
end

--[=[
	Outputs the camera stack. Intended for diagnostics.
]=]
function CameraStackService:PrintCameraStack()
	assert(self._stack, "Stack is not initialized yet")

	for _, value in pairs(self._stack) do
		print(tostring(type(value) == "table" and value.ClassName or tostring(value)))
	end
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
	assert(self._stack, "Not initialized")

	return self._stack[#self._stack]
end

--[=[
	Retrieves the top state off the stack at this time
	@return CameraState?
]=]
function CameraStackService:GetTopState()
	assert(self._stack, "Stack is not initialized yet")

	if #self._stack > 10 then
		warn(("[CameraStackService] - Stack is bigger than 10 in camerastackService (%d)"):format(#self._stack))
	end
	local topState = self._stack[#self._stack]

	if type(topState) == "table" then
		local state = topState.CameraState or topState
		if state then
			return state
		else
			warn("[CameraStackService] - No top state!")
		end
	else
		warn("[CameraStackService] - Bad type on top of stack")
	end
end

--[=[
	Returns a new camera state that retrieves the state below its set state.

	@return CustomCameraEffect -- Effect below
	@return (CameraState) -> () -- Function to set the state
]=]
function CameraStackService:GetNewStateBelow()
	assert(self._stack, "Stack is not initialized yet")

	local _stateToUse = nil

	return CustomCameraEffect.new(function()
		local index = self:GetIndex(_stateToUse)
		if index then
			local below = self._stack[index-1]
			if below then
				return below.CameraState or below
			else
				warn("[CameraStackService] - Could not get state below, found current state. Returning default.")
				return self._stack[1].CameraState
			end
		else
			warn(("[CameraStackService] - Could not get state from %q, returning default"):format(tostring(_stateToUse)))
			return self._stack[1].CameraState
		end
	end), function(newStateToUse)
		_stateToUse = newStateToUse
	end
end

--[=[
	Retrieves the index of a state
	@param state CameraEffect
	@return number? -- index

]=]
function CameraStackService:GetIndex(state)
	assert(self._stack, "Stack is not initialized yet")

	for index, value in pairs(self._stack) do
		if value == state then
			return index
		end
	end
end

--[=[
	Returns the current stack.

	:::warning
	Do not modify this stack, this is the raw memory of the stack
	:::

	@return { CameraState<T> }
]=]
function CameraStackService:GetStack()
	assert(self._stack, "Not initialized")

	return self._stack
end

--[=[
	Removes the state from the stack
	@param state CameraState
]=]
function CameraStackService:Remove(state)
	assert(self._stack, "Stack is not initialized yet")

	local index = self:GetIndex(state)

	if index then
		table.remove(self._stack, index)
	end
end

--[=[
	Adds the state from the stack
	@param state CameraState
]=]
function CameraStackService:Add(state)
	assert(self._stack, "Stack is not initialized yet")

	table.insert(self._stack, state)
end

return CameraStackService