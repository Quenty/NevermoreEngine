--[=[
	To work like value objects in Roblox and track a single item,
	with `.Changed` events
	@class ValueObject
]=]

local require = require(script.Parent.loader).load(script)

local Signal = require("Signal")
local Maid = require("Maid")
local Observable = require("Observable")

local ValueObject = {}
ValueObject.ClassName = "ValueObject"

--[=[
	Constructs a new value object
	@param baseValue T
	@return ValueObject
]=]
function ValueObject.new(baseValue, checkType)
	local self = {}

	rawset(self, "_value", baseValue)

	if type(checkType) == "string" then
		rawset(self, "_checkType", function(value)
			return typeof(value) == checkType
		end)
	elseif type(checkType) == "function" then
		rawset(self, "_checkType", checkType)
	elseif checkType == true then
		checkType = typeof(checkType)
		rawset(self, "_checkType", function(value)
			return typeof(value) == checkType
		end)
	elseif checkType ~= nil then
		error("Bad type for checkType")
	end

	self._maid = Maid.new()

--[=[
	Event fires when the value's object value change
	@prop Changed Signal<T> -- fires with oldValue, newValue, ...
	@within ValueObject
]=]
	self.Changed = Signal.new() -- :Fire(newValue, oldValue, maid, ...)
	self._maid:GiveTask(self.Changed)

	return setmetatable(self, ValueObject)
end

--[=[
	Constructs a new value object
	@param observable Observable<T>
	@return ValueObject<T>
]=]
function ValueObject.fromObservable(observable)
	local result = ValueObject.new()

	result:Mount(observable)

	return result
end

--[=[
	Returns whether the object is a ValueObject class
	@param value any
	@return boolean
]=]
function ValueObject.isValueObject(value)
	return type(value) == "table" and getmetatable(value) == ValueObject
end

--[=[
	Mounts the value to the observable. Multiple objects can be mounted at once.

	@param observable Observable
]=]
function ValueObject:Mount(observable)
	assert(Observable.isObservable(observable), "No observable")

	local maid = Maid.new()

	maid:GiveTask(observable:Subscribe(function(value, ...)
		self:SetValue(value, ...)
	end))

	self._maid[maid] = maid
	maid:GiveTask(function()
		self._maid[maid] = nil
	end)

	return maid
end

--[=[
	Observes the current value of the ValueObject
	@return Observable<T>
]=]
function ValueObject:Observe()
	return Observable.new(function(sub)
		if not self.Destroy then
			warn("[ValueObject.observeValue] - Connecting to dead ValueObject")
			-- No firing, we're dead
			sub:Complete()
			return
		end

		local maid = Maid.new()

		maid:GiveTask(self.Changed:Connect(function(newValue, _, _, ...)
			sub:Fire(newValue, ...)
		end))

		local args = rawget(self, "_lastEventContext")
		if args then
			sub:Fire(self.Value, table.unpack(args, 1, args.n))
		else
			sub:Fire(self.Value)
		end

		return maid
	end)
end

--[=[
	Allows you to set a value, and provide additional event context for the actual change.
	For example, you might do.

	```lua
	self.IsVisible:SetValue(isVisible, true)

	print(self.IsVisible.Changed:Connect(function(isVisible, _, _, doNotAnimate)
		print(doNotAnimate)
	end))
	```

	@param value T
	@param ... any -- Additional args. Can be used to pass event changing state args with value
]=]
function ValueObject:SetValue(value, ...)
	local previous = rawget(self, "_value")
	local checkType = rawget(self, "_checkType")

	if checkType then
		assert(checkType(value))
	end

	if previous ~= value then
		if select("#", ...) > 0 then
			rawset(self, "_lastEventContext", table.pack(...))
		else
			rawset(self, "_lastEventContext", nil)
		end

		rawset(self, "_value", value)

		local maid = Maid.new()

		self.Changed:Fire(value, previous, maid, ...)

		self._maid._valueMaid = maid
	end
end

--[=[
	The value of the ValueObject
	@prop Value T
	@within ValueObject
]=]
function ValueObject:__index(index)
	if index == "Value" then
		return self._value
	elseif ValueObject[index] then
		return ValueObject[index]
	elseif index == "LastEventContext" then
		local args = rawget(self, "_lastEventContext")
		if args then
			return table.unpack(args, 1, args.n)
		else
			return
		end
	elseif index == "_value" then
		return nil -- Edge case
	else
		error(("%q is not a member of ValueObject"):format(tostring(index)))
	end
end

function ValueObject:__newindex(index, value)
	if index == "Value" then
		-- Avoid deoptimization
		ValueObject.SetValue(self, value)
	elseif index == "LastEventContext" or ValueObject[index] then
		error(("%q cannot be set in ValueObject"):format(tostring(index)))
	else
		error(("%q is not a member of ValueObject"):format(tostring(index)))
	end
end

--[=[
	Forces the value to be nil on cleanup, cleans up the Maid

	Does not fire the event since 3.5.0
]=]
function ValueObject:Destroy()
	rawset(self, "_value", nil)
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return ValueObject
