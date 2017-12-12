--- Holds camera states and allows for the last camera state to be retrieved. Also
-- initializes an impulse and default camera as the bottom of the stack. Is a singleton.
-- @module CameraStack

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local DefaultCamera = LoadCustomLibrary("DefaultCamera")
local ImpulseCamera = LoadCustomLibrary("ImpulseCamera")
local CustomCameraEffect = LoadCustomLibrary("CustomCameraEffect")

assert(RunService:IsClient(), "Only require CameraStack on client")

local CameraStack = {}
CameraStack.__index = CameraStack
CameraStack.ClassName = "CameraStack"

function CameraStack.new()
	local self = setmetatable({}, CameraStack)
	
	self.Stack = {}
	
	local Default = DefaultCamera.new()
	Default:BindToRenderStep()
	self.RawDefaultCamera = Default
	
	local ImpulseCamera = ImpulseCamera.new()
	self.ImpulseCamera = ImpulseCamera
	
	self.DefaultCamera = (Default + ImpulseCamera):SetMode("Relative")
	
	self:Add(self.DefaultCamera)
	
	
	RunService:BindToRenderStep("CameraStackUpdateInternal", Enum.RenderPriority.Camera.Value + 75, function()
		debug.profilebegin("CameraStackUpdate")
		local State = self:GetTopState()
		if State and State ~= self.DefaultCamera then
			State:Set(workspace.CurrentCamera)
		end
		debug.profileend()
	end)
	
	return self
end

--- Outputs the camera stack
-- @treturn nil
function CameraStack:PrintCameraStack()
	for Index, Value in pairs(self.Stack) do
		print(tostring(type(Value) == "table" and Value.ClassName or tostring(Value)))
	end
end

--- Returns the default camera
-- @treturn SummedCamera DefaultCamera + ImpulseCamera
function CameraStack:GetDefaultCamera()
	return self.DefaultCamera
end

--- Returns the impulse camera. Useful for adding camera shake
-- @treturn ImpulseCamera
function CameraStack:GetImpulseCamera()
	return self.ImpulseCamera
end

--- Returns the default camera without any impulse cameras
-- @treturn DefaultCamera
function CameraStack:GetRawDefaultCamera()
	return self.RawDefaultCamera
end

--- Retrieves the top state off the stack
-- @treturn[1] CameraState
-- @treturn[2] nil
function CameraStack:GetTopState()
	if #self.Stack > 10 then
		warn(("[CameraStack] - Stack is bigger than 10 in camerastack (%d)"):format(#self.Stack))
	end
	local Top = self.Stack[#self.Stack]
		
	if type(Top) == "table" then
		local State = Top.CameraState or Top
		if State then
			return State
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
	local StateToUse = nil
	
	return CustomCameraEffect.new(function(Index)
		local Index = self:GetIndex(StateToUse)
		if Index then
			local Below = self.Stack[Index-1]
			if Below then
				return Below.CameraState
			else
				warn("[CameraStack] - Could not get state below, found current state. Returning default.")
				return self.Stack[1].CameraState
			end
		else
			warn("[CameraStack] - Could not get state, returning default")
			return self.Stack[1].CameraState
		end
	end), function(NewStateToUse) 
		StateToUse = NewStateToUse
	end
end

--- Retrieves the index of a state
-- @tparam CameraState State
-- @treturn number Index of state
-- @treturn nil If non on stack
function CameraStack:GetIndex(State)
	for Index, Value in pairs(self.Stack) do
		if Value == State then
			return Index
		end
	end
end

--- Removes the state from the stack
-- @tparam CameraState State State to remove
-- @treturn nil
function CameraStack:Remove(State)
	local Index = self:GetIndex(State)
	
	if Index then
		table.remove(self.Stack, Index)
	end
end

--- Adds a state to the stack
-- @tparam CameraState State State to add
-- @treturn nil
function CameraStack:Add(State)
	table.insert(self.Stack, State)
end

return CameraStack.new()