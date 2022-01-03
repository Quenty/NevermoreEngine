--[=[
	Stack of values that allows multiple systems to enable or disable a state.

	```lua
	local disabledStack = StateStack.new()
	print(disabledStack:GetState()) --> false

	disabledStack.Changed:Connect(function()
		print("From changed event we have state: ", disabledStack:GetState())
	end)

	local cancel = disabledStack:PushState() --> From changed event we have state: true
	print(disabledStack:GetState()) --> true

	cancel()  --> From changed event we have state: true
	print(disabledStack:GetState()) --> false

	disabledStack:Destroy()
	```

	@class StateStack
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ValueObject = require("ValueObject")

local StateStack = setmetatable({}, BaseObject)
StateStack.ClassName = "StateStack"
StateStack.__index = StateStack

--[=[
	Constructs a new StateStack.
	@return StateStack
]=]
function StateStack.new()
	local self = setmetatable(BaseObject.new(), StateStack)

	self._state = ValueObject.new(false)
	self._maid:GiveTask(self._state)

	self._stateStack = {}

--[=[
	Fires with the new state
	@prop Changed Signal<T>
	@within StateStack
]=]
	self.Changed = self._state.Changed

	return self
end

--[=[
	Gets the current state
	@return T
]=]
function StateStack:GetState()
	return self._state.Value
end

--[=[
	Pushes the current state onto the stack
	@param state T?
	@return function -- Cleanup function to invoke
]=]
function StateStack:PushState(state)
	if state == nil then
		state = true
	end

	local data = { state }
	table.insert(self._stateStack, data)

	self:_updateState()

	return function()
		if self.Destroy then
			self:_popState(data)
		end
	end
end

function StateStack:_popState(data)
	local index = table.find(self._stateStack, data)
	if index then
		table.remove(self._stateStack, index)
		self:_updateState()
	else
		warn("[StateStack] - Failed to find index")
	end
end

function StateStack:_updateState()
	local _, data = next(self._stateStack)
	if data == nil then
		if type(self._state.Value) == "boolean" then
			self._state.Value = false
		else
			self._state.Value = nil
		end
	else
		self._state.Value = data[1]
	end
end

--[=[
	Cleans up the StateStack and sets the metatable to nil.

	:::tip
	Be sure to call this to clean up the state stack!
	:::
	@method Destroy
	@within StateStack
]=]

return StateStack