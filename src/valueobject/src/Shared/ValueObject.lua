--[=[
	To work like value objects in Roblox and track a single item,
	with `.Changed` events
	@class ValueObject
]=]

local require = require(script.Parent.loader).load(script)

local GoodSignal = require("GoodSignal")
local Maid = require("Maid")
local Observable = require("Observable")
local ValueBaseUtils = require("ValueBaseUtils")
local RxValueBaseUtils = require("RxValueBaseUtils")
local Brio = require("Brio")

local EMPTY_FUNCTION = function() end

local ValueObject = {}
ValueObject.ClassName = "ValueObject"

--[=[
	Constructs a new value object
	@param baseValue T
	@param checkType string | nil
	@return ValueObject
]=]
function ValueObject.new(baseValue, checkType)
	local self = {
		_value = baseValue;
		_checkType = checkType;
		_maid = Maid.new();
	}

	if checkType and typeof(baseValue) ~= checkType then
		error(string.format("Expected value of type %q, got %q instead", checkType, typeof(baseValue)))
	end

--[=[
	Event fires when the value's object value change
	@prop Changed Signal<T> -- fires with oldValue, newValue, ...
	@within ValueObject
]=]
	self.Changed = GoodSignal.new() -- :Fire(newValue, oldValue, maid, ...)
	self._maid:GiveTask(self.Changed)

	return setmetatable(self, ValueObject)
end


--[=[
	Returns the current check type, if any

	@return string | nil
]=]
function ValueObject:GetCheckType()
	return rawget(self, "_checkType")
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

function ValueObject:_toMountableObservable(value)
	if Observable.isObservable(value) then
		return value
	elseif typeof(value) == "Instance" then
		-- IntValue, ObjectValue, et cetera
		if ValueBaseUtils.isValueBase(value) then
			return RxValueBaseUtils.observeValue(value)
		end
	elseif type(value) == "table" then
		if ValueObject.isValueObject(value) then
			return value:Observe()
		-- elseif Promise.isPromise(value) then
		-- 	return Rx.fromPromise(value)
		end
	end

	return nil
end
--[=[
	Mounts the value to the observable. Overrides the last mount.

	@param value Observable | T
	@return MaidTask
]=]
function ValueObject:Mount(value)
	local observable = self:_toMountableObservable(value)
	if observable then
		self._maid._mount = nil

		local maid = Maid.new()

		maid:GiveTask(observable:Subscribe(function(...)
			self:SetValue(...)
		end))

		maid:GiveTask(function()
			if self._maid._mount == maid then
				self._maid._mount = nil
			end
		end)

		self._maid._mount = maid

		return function()
			if self._maid._mount == maid then
				self._maid._mount = nil
			end
		end
	else
		self._maid._mount = nil

		self:SetValue(value)

		return EMPTY_FUNCTION
	end
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
	Observes the value as a brio. The condition defaults to truthy or nil.

	@param condition function | nil -- optional
	@return Observable<Brio<T>>
]=]
function ValueObject:ObserveBrio(condition)
	assert(type(condition) == "function" or condition == nil, "Bad condition")

	return Observable.new(function(sub)
		if not self.Destroy then
			warn("[ValueObject.observeValue] - Connecting to dead ValueObject")
			-- No firing, we're dead
			sub:Complete()
			return
		end

		local maid = Maid.new()

		local function handleNewValue(newValue, ...)
			if not condition or condition(newValue) then
				local brio = Brio.new(newValue, ...)
				maid._current = brio
				sub:Fire(brio)
			else
				maid._current = nil
			end
		end

		maid:GiveTask(self.Changed:Connect(function(newValue, _, _, ...)
			handleNewValue(newValue, ...)
		end))

		local args = rawget(self, "_lastEventContext")
		if args then
			handleNewValue(self.Value, table.unpack(args, 1, args.n))
		else
			handleNewValue(self.Value)
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

	if checkType and typeof(value) ~= checkType then
		error(string.format("Expected value of type %q, got %q instead", checkType, typeof(value)))
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
