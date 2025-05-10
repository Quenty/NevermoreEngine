--!strict
--[=[
	@class CameraStack
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local BaseObject = require("BaseObject")
local CameraEffectUtils = require("CameraEffectUtils")
local CameraState = require("CameraState")
local CustomCameraEffect = require("CustomCameraEffect")
local DuckTypeUtils = require("DuckTypeUtils")

local CameraStack = setmetatable({}, BaseObject)
CameraStack.ClassName = "CameraStack"
CameraStack.__index = CameraStack

export type CameraStack = typeof(setmetatable(
	{} :: {
		_stack: { CameraEffectUtils.CameraLike },
		_disabledSet: { [string]: boolean },
	},
	{} :: typeof({ __index = CameraStack })
)) & BaseObject.BaseObject

--[=[
	Constructs a new camera stack

	@return CameraStack
]=]
function CameraStack.new(): CameraStack
	local self: CameraStack = setmetatable(BaseObject.new() :: any, CameraStack)

	self._stack = {}
	self._disabledSet = {}

	return self
end

--[=[
	@param value any
	@return boolean
]=]
function CameraStack.isCameraStack(value: any): boolean
	return DuckTypeUtils.isImplementation(CameraStack, value)
end

--[=[
	Pushes a disable state onto the camera stack
	@return function -- Function to cancel disable
]=]
function CameraStack.PushDisable(self: CameraStack): () -> ()
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
function CameraStack.PrintCameraStack(self: CameraStack): ()
	assert(self._stack, "Stack is not initialized yet")

	for _, value in self._stack do
		print(tostring(type(value) == "table" and (value :: any).ClassName or tostring(value)))
	end
end

--[=[
	Gets the camera current on the top of the stack
	@return CameraEffect
]=]
function CameraStack.GetTopCamera(self: CameraStack): CameraEffectUtils.CameraLike
	assert(self._stack, "Not initialized")

	return self._stack[#self._stack]
end

--[=[
	Retrieves the top state off the stack at this time
	@return CameraState?
]=]
function CameraStack.GetTopState(self: CameraStack): CameraState.CameraState?
	assert(self._stack, "Stack is not initialized yet")

	if next(self._disabledSet) then
		return nil
	end

	if #self._stack > 10 then
		warn(string.format("[CameraStack] - Stack is bigger than 10 in CameraStack (%d)", #self._stack))
	end
	local topState: any = self._stack[#self._stack]

	if type(topState) == "table" then
		local state = topState.CameraState or topState
		if state then
			return state
		else
			warn("[CameraStack] - No top state!")
			return nil
		end
	elseif topState ~= nil then
		warn("[CameraStack] - Bad type on top of stack")
		return nil
	end

	return nil
end

--[=[
	Returns a new camera state that retrieves the state below its set state.

	@return CustomCameraEffect -- Effect below
	@return (CameraState) -> () -- Function to set the state
]=]
function CameraStack.GetNewStateBelow(self: CameraStack)
	assert(self._stack, "Stack is not initialized yet")

	local _stateToUse = nil

	return CustomCameraEffect.new(function()
		local index = self:GetIndex(_stateToUse)
		if index then
			local below: any = self._stack[index - 1]
			if below then
				return below.CameraState or below
			else
				warn("[CameraStack] - Could not get state below, found current state. Returning default.")
				return self:_getDefaultState()
			end
		else
			warn(string.format("[CameraStack] - Could not get state from %q, returning default", tostring(_stateToUse)))
			return self:_getDefaultState()
		end
	end),
		function(newStateToUse)
			_stateToUse = newStateToUse
		end
end

function CameraStack:_getDefaultState(): CameraState.CameraState
	return self._stack[1].CameraState or self._stack[1]
end

--[=[
	Retrieves the index of a state
	@param state CameraEffect
	@return number? -- index

]=]
function CameraStack.GetIndex(self: CameraStack, state: CameraEffectUtils.CameraLike): number?
	assert(self._stack, "Stack is not initialized yet")

	for index, value in self._stack do
		if value == state then
			return index
		end
	end

	return nil
end

--[=[
	Returns the current stack.

	:::warning
	Do not modify this stack, this is the raw memory of the stack
	:::

	@return { CameraLike }
]=]
function CameraStack.GetStack(self: CameraStack): { CameraEffectUtils.CameraLike }
	assert(self._stack, "Not initialized")

	return self._stack
end

--[=[
	Removes the state from the stack
	@param state CameraLike
]=]
function CameraStack.Remove(self: CameraStack, state: CameraEffectUtils.CameraLike)
	assert(self._stack, "Stack is not initialized yet")

	local index = self:GetIndex(state)

	if index then
		table.remove(self._stack, index)
	end
end

--[=[
	Adds the state from the stack
	@param state CameraState
	@return () -> () -- Cleanup function
]=]
function CameraStack.Add(self: CameraStack, state: CameraEffectUtils.CameraLike): () -> ()
	assert(self._stack, "Stack is not initialized yet")

	table.insert(self._stack, state)

	return function()
		if self.Destroy then
			self:Remove(state)
		end
	end
end

return CameraStack
