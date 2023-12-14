--[=[
	Stack of values that allows multiple systems to enable or disable a state.

	```lua
	local disabledStack = maid:Add(StateStack.new(false, "boolean"))
	print(disabledStack:GetState()) --> false

	maid:GiveTask(disabledStack.Changed:Connect(function()
		print("From changed event we have state: ", disabledStack:GetState())
	end))

	local cancel = disabledStack:PushState(true) --> From changed event we have state: true
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
	@param defaultValue any -- The default value to use for the statestack.
	@param checkType string | nil
	@return StateStack
]=]
function StateStack.new(defaultValue, checkType)
	local self = setmetatable(BaseObject.new(), StateStack)

	self._state = self._maid:Add(ValueObject.new(defaultValue, checkType))
	self._defaultValue = defaultValue
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
	Gets the count of the stack
	@return number
]=]
function StateStack:GetCount()
	return #self._stateStack
end

--[=[
	Gets the current state
	@return T?
]=]
function StateStack:GetState()
	return self._state.Value
end

--[=[
	Observes the current value of stack
	@return Observable<T?>
]=]
function StateStack:Observe()
	return self._state:Observe()
end

--[=[
	Observes the current value of stack
	@param predicate function
	@return Observable<T?>
]=]
function StateStack:ObserveBrio(predicate)
	return self._state:ObserveBrio(predicate)
end

--[=[
	Pushes the current state onto the stack
	@param state T?
	@return function -- Cleanup function to invoke
]=]
function StateStack:PushState(state)
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
	local dataContainer = self._stateStack[#self._stateStack]
	if dataContainer == nil then
		self._state.Value = self._defaultValue
	else
		self._state.Value = dataContainer[1]
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