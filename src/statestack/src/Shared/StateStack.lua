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

local ValueObject = require("ValueObject")

local StateStack = {}
StateStack.ClassName = "StateStack"
StateStack.__index = StateStack

--[=[
	Constructs a new StateStack.
	@param defaultValue any -- The default value to use for the statestack.
	@param checkType string | nil
	@return StateStack
]=]
function StateStack.new(defaultValue, checkType)
	-- ValueObject has a built-in typecheck, but we shouldn't use it.
	-- If we assign an improper value, we'll error in __newindex.
	-- We need to update _stateStack alongside, so there's two scenarios.
		-- 1) Update _stateStack before setting. If .Value = throws, we've now got junk in the stack.
		-- 2) Update _stateStack after. Now our immediate-mode-subscribers get an oudated value from :GetCount().
	-- Therefore we need to typecheck before doing anything, and we need to update the stack first.
	if checkType and typeof(defaultValue) ~= checkType then
		error(string.format("Expected value of type %q, got %q instead", checkType, typeof(defaultValue)))
	end

	local self = {}

	self._checkType = checkType
	self._state = ValueObject.new(defaultValue)
	self._defaultValue = defaultValue
	self._stateStack = {}

--[=[
	Fires with the new state
	@prop Changed Signal<T>
	@within StateStack
]=]
	self.Changed = self._state.Changed

	return setmetatable(self, StateStack)
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
	if self._checkType and typeof(state) ~= self._checkType then
		error(string.format("Expected value of type %q, got %q instead", self._checkType, typeof(state)))
	end

	local data = { state }
	table.insert(self._stateStack, data)
	self._state.Value = state

	return function()
		if self.Destroy then
			local index = table.find(self._stateStack, data)
			table.remove(self._stateStack, index)
			if index > #self._stateStack then
				local dataContainer: {any}? = self._stateStack[#self._stateStack]
				self._state.Value = if dataContainer then dataContainer[1] else self._defaultValue
			end
		end
	end
end

--[=[
	Cleans up the StateStack and sets the metatable to nil.

	:::tip
	Be sure to call this to clean up the state stack!
	:::
]=]
function StateStack:Destroy()
	setmetatable(self, nil)
	self._state:Destroy()
	self.Changed = nil
	self._stateStack = nil
end

return StateStack