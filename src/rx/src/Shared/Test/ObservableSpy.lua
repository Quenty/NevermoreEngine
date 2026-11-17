--!strict
--[=[
	Records an observable's emissions, completion and failure, and reads like a list including `nil` emissions.

	```lua
	local versions = maid:Add(ObservableSpy.new(attributeValue:Observe()))

	expect(#versions).toEqual(1)
	expect(versions[1]).toEqual(nil)
	```

	@class ObservableSpy
]=]

local require = require(script.Parent.loader).load(script)

local Observable = require("Observable")
local Promise = require("Promise")
local Subscription = require("Subscription")

local ObservableSpy = {}
ObservableSpy.ClassName = "ObservableSpy"

--[=[
	`"destroyed"` only applies to a spy destroyed while still pending.

	@type ObservableSpyState "pending" | "complete" | "failed" | "destroyed"
	@within ObservableSpy
]=]
export type ObservableSpyState = "pending" | "complete" | "failed" | "destroyed"

export type ObservableSpyStates = {
	PENDING: "pending",
	COMPLETE: "complete",
	FAILED: "failed",
	DESTROYED: "destroyed",
}

local ObservableSpyStates: ObservableSpyStates = table.freeze({
	PENDING = "pending",
	COMPLETE = "complete",
	FAILED = "failed",
	DESTROYED = "destroyed",
} :: ObservableSpyStates)

export type ObservableSpy<T> = typeof(setmetatable(
	{} :: {
		--[=[
			Every value emitted, in order. Same as [ObservableSpy.GetValues].
			@prop Values { T }
			@within ObservableSpy
		]=]
		Values: { T },

		_subscription: Subscription.Subscription<...any>,
		_values: { [number]: T },
		_count: number,
		_state: ObservableSpyState,
		_error: any,
		_completePromise: Promise.Promise<()>?,
		_errorPromise: Promise.Promise<any>?,
	},
	{} :: typeof({
		__index = ObservableSpy,
		__iter = (nil :: any) :: (self: any) -> () -> (number?, T),
	})
))

--[=[
	Subscribes to the observable. Give the spy to a maid.

	@param observable Observable<T> -- Only the first value of each emission is recorded
	@return ObservableSpy<T>
]=]
function ObservableSpy.new<T>(observable: Observable.Observable<(T, ...any)>): ObservableSpy<T>
	assert(Observable.isObservable(observable), "Bad observable")

	local self: ObservableSpy<T> = setmetatable({} :: any, ObservableSpy)

	self._values = {}
	self._count = 0
	self._state = ObservableSpyStates.PENDING
	self._error = nil

	-- Fields are set before subscribing because the observable can emit, complete or fail synchronously
	self._subscription = observable:Subscribe(function(value: T)
		self._count += 1
		self._values[self._count] = value
	end, function(err: any)
		if self._state == ObservableSpyStates.PENDING then
			self._error = err
		end
		self:_end(ObservableSpyStates.FAILED)
	end, function()
		self:_end(ObservableSpyStates.COMPLETE)
	end)

	return self
end

--[=[
	Returns every value emitted, in order.

	@return { T }
]=]
function ObservableSpy.GetValues<T>(self: ObservableSpy<T>): { [number]: T }
	return table.clone(self._values)
end

--[=[
	Returns the value emitted at the index, starting at 1.

	@param index number
	@return T
]=]
function ObservableSpy.GetValueAt<T>(self: ObservableSpy<T>, index: number): T
	assert(type(index) == "number", "Bad index")

	return self._values[index]
end

--[=[
	Returns the first value emitted.

	@return T
]=]
function ObservableSpy.GetFirstValue<T>(self: ObservableSpy<T>): T
	return self._values[1]
end

--[=[
	Returns the most recent value emitted.

	@return T
]=]
function ObservableSpy.GetLastValue<T>(self: ObservableSpy<T>): T
	return self._values[self._count]
end

--[=[
	Returns how many values have been emitted, including `nil` emissions.

	@return number
]=]
function ObservableSpy.GetCount<T>(self: ObservableSpy<T>): number
	return self._count
end

--[=[
	Returns the spy's current state.

	@return ObservableSpyState
]=]
function ObservableSpy.GetState<T>(self: ObservableSpy<T>): ObservableSpyState
	return self._state
end

--[=[
	Returns whether the observable has completed.

	@return boolean
]=]
function ObservableSpy.IsComplete<T>(self: ObservableSpy<T>): boolean
	return self._state == ObservableSpyStates.COMPLETE
end

--[=[
	Returns whether the observable has failed.

	@return boolean
]=]
function ObservableSpy.HasFailed<T>(self: ObservableSpy<T>): boolean
	return self._state == ObservableSpyStates.FAILED
end

--[=[
	Returns what the observable failed with.

	@return any
]=]
function ObservableSpy.GetError<T>(self: ObservableSpy<T>): any
	return self._error
end

--[=[
	Resolves when the observable completes. Rejects if it fails instead or the spy is destroyed.

	@return Promise<()>
]=]
function ObservableSpy.PromiseOnComplete<T>(self: ObservableSpy<T>): Promise.Promise<()>
	local promise = self._completePromise
	if promise then
		return promise
	end

	local newPromise: Promise.Promise<()> = Promise.new()
	self._completePromise = newPromise
	self:_settlePromises()

	return newPromise
end

--[=[
	Resolves with the observable's error. Rejects if it completes instead or the spy is destroyed.

	@return Promise<any>
]=]
function ObservableSpy.PromiseOnError<T>(self: ObservableSpy<T>): Promise.Promise<any>
	local promise = self._errorPromise
	if promise then
		return promise
	end

	local newPromise: Promise.Promise<any> = Promise.new()
	self._errorPromise = newPromise
	self:_settlePromises()

	return newPromise
end

function ObservableSpy._end<T>(self: ObservableSpy<T>, state: ObservableSpyState)
	if self._state ~= ObservableSpyStates.PENDING then
		return
	end

	self._state = state
	self:_settlePromises()
end

function ObservableSpy._settlePromises<T>(self: ObservableSpy<T>)
	local completePromise = self._completePromise
	local errorPromise = self._errorPromise

	if self._state == ObservableSpyStates.COMPLETE then
		if completePromise then
			completePromise:Resolve()
		end
		if errorPromise then
			errorPromise:Reject("Observable completed instead of failing")
		end
	elseif self._state == ObservableSpyStates.FAILED then
		if completePromise then
			completePromise:Reject(string.format("Observable failed instead of completing: %s", tostring(self._error)))
		end
		if errorPromise then
			errorPromise:Resolve(self._error)
		end
	elseif self._state == ObservableSpyStates.DESTROYED then
		-- Rejecting with no value is a cancellation, which is not reported as an uncaught rejection
		if completePromise then
			completePromise:Reject()
		end
		if errorPromise then
			errorPromise:Reject()
		end
	end
end

-- Metamethods take an untyped self, as ValueObject's do: typing them as ObservableSpy<T> makes the
-- type checker resolve the class type before its private methods exist.
function ObservableSpy.__index(self: any, index: any): any
	if ObservableSpy[index] ~= nil then
		return ObservableSpy[index]
	elseif type(index) == "number" then
		return (rawget(self, "_values") :: any)[index]
	elseif index == "Values" then
		return table.clone(rawget(self, "_values") :: any)
	elseif type(index) == "string" and string.sub(index, 1, 1) == "_" then
		-- Private fields that are currently nil (an error, a promise not yet requested)
		return nil
	else
		error(string.format("%q is not a member of ObservableSpy", tostring(index)), 2)
	end
end

function ObservableSpy.__len(self: any): number
	return rawget(self, "_count") :: any
end

function ObservableSpy.__iter(self: any): () -> (number?, any)
	-- Walks 1..count so nil emissions are visited in order, where next() would skip them
	local values = rawget(self, "_values") :: any
	local index = 0

	return function()
		index += 1
		if index > (rawget(self, "_count") :: any) then
			return nil, nil
		end

		return index, values[index]
	end
end

--[=[
	Unsubscribes. What was recorded stays readable.
]=]
function ObservableSpy.Destroy<T>(self: ObservableSpy<T>)
	self:_end(ObservableSpyStates.DESTROYED)
	self._subscription:Destroy()
end

return ObservableSpy
