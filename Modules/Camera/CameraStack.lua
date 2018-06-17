--- Holds camera states and allows for the last camera state to be retrieved. Also
-- initializes an impulse and default camera as the bottom of the stack. Is a singleton.
-- @module CameraStack

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CustomCameraEffect = require("CustomCameraEffect")
local DefaultCamera = require("DefaultCamera")
local ImpulseCamera = require("ImpulseCamera")

assert(RunService:IsClient(), "[CameraStack] - Only require CameraStack on client")

local CameraStack = {}
CameraStack.__index = CameraStack
CameraStack.ClassName = "CameraStack"

function CameraStack.new()
	local self = setmetatable({}, CameraStack)

	self._stack = {}

	-- Initialize default cameras
	self._rawDefaultCamera = DefaultCamera.new()
	self._impulseCamera = ImpulseCamera.new()
	self._defaultCamera = (self._rawDefaultCamera + self._impulseCamera):SetMode("Relative")
	self._rawDefaultCamera:BindToRenderStep()

	-- Add camera to stack
	self:Add(self._defaultCamera)

	RunService:BindToRenderStep("CameraStackUpdateInternal", Enum.RenderPriority.Camera.Value + 75, function()
		debug.profilebegin("CameraStackUpdate")

		local state = self:GetTopState()
		if state and state ~= self._defaultCamera then
			state:Set(Workspace.CurrentCamera)
		end

		debug.profileend()
	end)

	return self
end

--- Outputs the camera stack
-- @treturn nil
function CameraStack:PrintCameraStack()
	for _, value in pairs(self._stack) do
		print(tostring(type(value) == "table" and value.ClassName or tostring(value)))
	end
end

--- Returns the default camera
-- @treturn SummedCamera DefaultCamera + ImpulseCamera
function CameraStack:GetDefaultCamera()
	return self._defaultCamera
end

--- Returns the impulse camera. Useful for adding camera shake
-- @treturn ImpulseCamera
function CameraStack:GetImpulseCamera()
	return self._impulseCamera
end

--- Returns the default camera without any impulse cameras
-- @treturn DefaultCamera
function CameraStack:GetRawDefaultCamera()
	return self._rawDefaultCamera
end

--- Retrieves the top state off the stack
-- @treturn[1] CameraState
-- @treturn[2] nil
function CameraStack:GetTopState()
	if #self._stack > 10 then
		warn(("[CameraStack] - Stack is bigger than 10 in camerastack (%d)"):format(#self._stack))
	end
	local topState = self._stack[#self._stack]

	if type(topState) == "table" then
		local state = topState.CameraState or topState
		if state then
			return state
		else
			warn("[CameraStack] - No top state!")
		end
	else
		warn("[CameraStack] - Bad type on top of stack")
	end
end

--- Returns a new camera state that retrieves the state below its set state
-- @treturn[1] CustomCameraEffect
-- @treturn[1] NewStateToUse
function CameraStack:GetNewStateBelow()
	local _stateToUse = nil

	return CustomCameraEffect.new(function()
		local index = self:GetIndex(_stateToUse)
		if index then
			local below = self._stack[index-1]
			if below then
				return below.CameraState or below
			else
				warn("[CameraStack] - Could not get state below, found current state. Returning default.")
				return self._stack[1].CameraState
			end
		else
			warn("[CameraStack] - Could not get state, returning default")
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
function CameraStack:GetIndex(state)
	for index, value in pairs(self._stack) do
		if value == state then
			return index
		end
	end
end

--- Removes the state from the stack
-- @tparam CameraState state
-- @treturn nil
function CameraStack:Remove(state)
	local index = self:GetIndex(state)

	if index then
		table.remove(self._stack, index)
	end
end

--- Adds a state to the stack
-- @tparam CameraState state
-- @treturn nil
function CameraStack:Add(state)
	table.insert(self._stack, state)
end

return CameraStack.new()