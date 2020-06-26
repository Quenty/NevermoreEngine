--- Holds camera states and allows for the last camera state to be retrieved. Also
-- initializes an impulse and default camera as the bottom of the stack. Is a singleton.
-- @module CameraStackService

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local CustomCameraEffect = require("CustomCameraEffect")
local DefaultCamera = require("DefaultCamera")
local ImpulseCamera = require("ImpulseCamera")

assert(RunService:IsClient(), "[CameraStackService] - Only require CameraStackService on client")

local CameraStackService = {}

function CameraStackService:Init(doNotUseDefaultCamera)
	self._stack = {}
	self._disabledSet = {}

	-- Initialize default cameras
	self._rawDefaultCamera = DefaultCamera.new()
	self._impulseCamera = ImpulseCamera.new()
	self._defaultCamera = (self._rawDefaultCamera + self._impulseCamera):SetMode("Relative")

	if doNotUseDefaultCamera then
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
		if state and state ~= self._defaultCamera then
			state:Set(Workspace.CurrentCamera)
		end

		debug.profileend()
	end)
end

function CameraStackService:PushDisable()
	local disabledKey = HttpService:GenerateGUID(false)

	self._disabledSet[disabledKey] = true

	return function()
		self._disabledSet[disabledKey] = nil
	end
end

--- Outputs the camera stack
-- @treturn nil
function CameraStackService:PrintCameraStack()
	assert(self._stack, "Stack is not initialized yet")

	for _, value in pairs(self._stack) do
		print(tostring(type(value) == "table" and value.ClassName or tostring(value)))
	end
end

--- Returns the default camera
-- @treturn SummedCamera DefaultCamera + ImpulseCamera
function CameraStackService:GetDefaultCamera()
	return self._defaultCamera or error()
end

--- Returns the impulse camera. Useful for adding camera shake
-- @treturn ImpulseCamera
function CameraStackService:GetImpulseCamera()
	return self._impulseCamera or error()
end

--- Returns the default camera without any impulse cameras
-- @treturn DefaultCamera
function CameraStackService:GetRawDefaultCamera()
	return self._rawDefaultCamera or error()
end

function CameraStackService:GetTopCamera()
	return self._stack[#self._stack]
end

--- Retrieves the top state off the stack
-- @treturn[1] CameraState
-- @treturn[2] nil
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

--- Returns a new camera state that retrieves the state below its set state
-- @treturn[1] CustomCameraEffect
-- @treturn[1] NewStateToUse
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
			warn("[CameraStackService] - Could not get state, returning default")
			return self._stack[1].CameraState
		end
	end), function(newStateToUse)
		_stateToUse = newStateToUse
	end
end

--- Retrieves the index of a state
-- @tparam CameraState state
-- @treturn number Index of state
-- @treturn nil If non on stack
function CameraStackService:GetIndex(state)
	assert(self._stack, "Stack is not initialized yet")

	for index, value in pairs(self._stack) do
		if value == state then
			return index
		end
	end
end

function CameraStackService:GetStack()
	return self._stack
end

--- Removes the state from the stack
-- @tparam CameraState state
-- @treturn nil
function CameraStackService:Remove(state)
	assert(self._stack, "Stack is not initialized yet")

	local index = self:GetIndex(state)

	if index then
		table.remove(self._stack, index)
	end
end

--- Adds a state to the stack
-- @tparam CameraState state
-- @treturn nil
function CameraStackService:Add(state)
	assert(self._stack, "Stack is not initialized yet")

	table.insert(self._stack, state)
end

return CameraStackService