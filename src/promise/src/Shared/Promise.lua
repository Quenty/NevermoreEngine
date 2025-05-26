--!nocheck
--[=[
	Promises, but without error handling as this screws with stack traces, using Roblox signals

	See: https://promisesaplus.com/

	@class Promise
]=]

local HttpService = game:GetService("HttpService")

-- Turns out debug.traceback() is slow
local ENABLE_TRACEBACK = false
local _emptyRejectedPromise = nil
local _emptyFulfilledPromise = nil
local EMPTY_PACKED_TUPLE = table.freeze({ n = 0 })

local Promise = {}
Promise.ClassName = "Promise"
Promise.__index = Promise

export type Resolve<T...> = (T...) -> ()
export type Reject = (...any) -> ()
export type ResolveReject<T...> = (Resolve<T...>, Reject) -> ()

export type Promise<T...> = typeof(setmetatable(
	{} :: {
		_fulfilled: any?,
		_rejected: any?,
		_unconsumedException: boolean,
		_pendingExecuteList: { any }?,
		_source: string,
	},
	{} :: typeof({ __index = Promise })
))

--[=[
	Determines whether a value is a promise or not.

	@param value any
	@return boolean
]=]
function Promise.isPromise(value: any): boolean
	return type(value) == "table" and value.ClassName == "Promise"
end

--[=[
	Constructs a new promise.

	::warning
	Do not yield within this func callback, as it will yield on the
	main thread. This is a performance optimization.
	::

	@param func (resolve: (...) -> (), reject: (...) -> ()) -> ()?
	@return Promise<T...>
]=]
function Promise.new<T...>(func: ResolveReject<T...>?): Promise<T...>
	local self = setmetatable({
		_pendingExecuteList = {},
		_unconsumedException = true,
		_source = ENABLE_TRACEBACK and debug.traceback("Promise.new()", 2) or "",
	}, Promise)

	if type(func) == "function" then
		func(self:_getResolveReject())
	end

	return self
end

--[=[
	Initializes a new promise with the given function in a spawn wrapper.

	@param func (resolve: (...) -> (), reject: (...) -> ()) -> ()?
	@return Promise<T...>
]=]
function Promise.spawn<T...>(func: ResolveReject<T...>): Promise<T...>
	local self = Promise.new()

	task.spawn(func, self:_getResolveReject())

	return self
end

--[=[
	Initializes a new promise with the given function in a delay wrapper.

	@param seconds number
	@param func (resolve: (...) -> (), reject: (...) -> ()) -> ()?
	@return Promise<T...>
]=]
function Promise.delay<T...>(seconds: number, func: ResolveReject<T...>): Promise<T...>
	assert(type(seconds) == "number", "Bad seconds")
	assert(type(func) == "function", "Bad func")

	local self = Promise.new()

	task.delay(seconds, func, self:_getResolveReject())

	return self
end

--[=[
	Initializes a new promise with the given function in a deferred wrapper.

	@param func (resolve: (...) -> (), reject: (...) -> ()) -> ()?
	@return Promise<T...>
]=]
function Promise.defer<T...>(func: ResolveReject<T...>): Promise<T...>
	local self = Promise.new()

	-- Just the function part of the resolve/reject protocol!
	task.defer(func, self:_getResolveReject())

	return self
end

--[=[
	Returns a resolved promise with the following values

	@param ... Values to resolve to
	@return Promise<T...>
]=]
function Promise.resolved<T...>(...: T...): Promise<T...>
	local n = select("#", ...)
	if n == 0 then
		-- Reuse promise here to save on calls to Promise.resolved()
		return _emptyFulfilledPromise
	elseif n == 1 and Promise.isPromise(...) then
		local promise = (...)

		-- Resolving to promise that is already resolved. Just return the promise!
		if not promise._pendingExecuteList then
			return promise
		end
	end

	local promise = Promise.new()
	promise:Resolve(...)
	return promise
end

--[=[
	Returns a rejected promise with the following values

	@param ... Values to reject to
	@return Promise<T...>
]=]
function Promise.rejected<T...>(...): Promise<()>
	local n = select("#", ...)
	if n == 0 then
		-- Reuse promise here to save on calls to Promise.rejected()
		return _emptyRejectedPromise
	end

	local promise = Promise.new()
	promise:_reject(table.pack(...))
	return promise
end

--[=[
	Returns whether or not the promise is pending

	@return bool -- True if pending, false otherwise
]=]
function Promise.IsPending<T...>(self: Promise<T...>): boolean
	return self._pendingExecuteList ~= nil
end

--[=[
	Returns whether or not the promise is fulfilled

	@return bool -- True if fulfilled
]=]
function Promise.IsFulfilled<T...>(self: Promise<T...>): boolean
	return self._fulfilled ~= nil
end

--[=[
	Returns whether or not the promise is rejected

	@return bool -- True if rejected
]=]
function Promise.IsRejected<T...>(self: Promise<T...>): boolean
	return self._rejected ~= nil
end

--[=[
	Yields until the promise is complete, and errors if an error
	exists, otherwise returns the fulfilled results.

	@yields
	@return T
]=]
function Promise.Wait<T...>(self: Promise<T...>): T...
	if self._fulfilled then
		return table.unpack(self._fulfilled, 1, self._fulfilled.n)
	elseif self._rejected then
		error(tostring(self._rejected[1]), 2)
	else
		local waitingCoroutine = coroutine.running()

		self:Then(function()
			task.spawn(waitingCoroutine)
		end, function()
			task.spawn(waitingCoroutine)
		end)

		coroutine.yield()

		if self._rejected then
			error(tostring(self._rejected[1]), 2)
		elseif self._fulfilled then
			return table.unpack(self._fulfilled, 1, self._fulfilled.n)
		else
			error("Bad state")
		end
	end
end

--[=[
	Yields until the promise is complete, then returns a boolean indicating
	the result, followed by the values from the promise.

	@yields
	@return boolean, T
]=]
function Promise.Yield<T...>(self: Promise<T...>): (boolean, T...)
	if self._fulfilled then
		return true, table.unpack(self._fulfilled, 1, self._fulfilled.n)
	elseif self._rejected then
		return false, table.unpack(self._rejected, 1, self._rejected.n)
	else
		local waitingCoroutine = coroutine.running()

		self:Then(function()
			task.spawn(waitingCoroutine)
		end, function()
			task.spawn(waitingCoroutine)
		end)

		coroutine.yield()

		if self._fulfilled then
			return true, table.unpack(self._fulfilled, 1, self._fulfilled.n)
		elseif self._rejected then
			return false, table.unpack(self._rejected, 1, self._rejected.n)
		else
			error("Bad state")
		end
	end
end

--[=[
	Promise resolution procedure, resolves the given values

	@param ... T
]=]
function Promise:Resolve<T...>(...: T...)
	if not self._pendingExecuteList then
		return
	end

	local len = select("#", ...)
	if len == 0 then
		self:_fulfill(EMPTY_PACKED_TUPLE)
	elseif self == (...) then
		self:Reject("TypeError: Resolved to self")
	elseif Promise.isPromise(...) then
		if len > 1 then
			local message =
				string.format("When resolving a promise, extra arguments are discarded! See:\n\n%s", self._source)
			warn(message)
		end

		local promise2 = (...)
		if promise2._pendingExecuteList then -- pending
			promise2._unconsumedException = false
			promise2._pendingExecuteList[#promise2._pendingExecuteList + 1] = {
				function(...)
					self:Resolve(...)
				end,
				function(...)
					-- Still need to verify at this point that we're pending!
					if self._pendingExecuteList then
						self:_reject(table.pack(...))
					end
				end,
			}
		elseif promise2._rejected then -- rejected
			promise2._unconsumedException = false
			self:_reject(promise2._rejected)
		elseif promise2._fulfilled then -- fulfilled
			self:_fulfill(promise2._fulfilled)
		else
			error("[Promise.Resolve] - Bad promise2 state")
		end
	elseif type(...) == "function" then
		if len > 1 then
			local message =
				string.format("When resolving a function, extra arguments are discarded! See:\n\n%s", self._source)
			warn(message)
		end

		local func = ...
		func(self:_getResolveReject())
	else
		-- TODO: Handle thenable promises!
		-- Problem: Lua has :andThen() and also :Then() as two methods in promise
		-- implementations.
		self:_fulfill(table.pack(...))
	end
end

--[[
	Fulfills the promise with the value
	@param values { T } -- Params to fulfil with
	@private
]]
function Promise._fulfill<T...>(self: Promise<T...>, values)
	if not self._pendingExecuteList then
		return
	end

	self._fulfilled = values

	local list = self._pendingExecuteList
	self._pendingExecuteList = nil
	for _, data in list do
		self:_executeThen(unpack(data))
	end
end

--[=[
	Rejects the promise with the values given
	@param ... T -- Params to reject with
]=]
function Promise.Reject<T...>(self: Promise<T...>, ...)
	self:_reject(table.pack(...))
end

function Promise._reject<T...>(self: Promise<T...>, values)
	if not self._pendingExecuteList then
		return
	end

	self._rejected = values

	local list = self._pendingExecuteList
	self._pendingExecuteList = nil
	for _, data in list do
		self:_executeThen(unpack(data))
	end

	-- Check for uncaught exceptions
	if self._unconsumedException and self._rejected.n > 0 then
		task.defer(function()
			-- Yield to end of frame, giving control back to Roblox.
			-- This is the equivalent of giving something back to a task manager.
			if self._unconsumedException then
				local errOutput = self:_toHumanReadable(values[1])

				if ENABLE_TRACEBACK then
					warn(
						string.format("[Promise] - Uncaught exception in promise\n\n%q\n\n%s", errOutput, self._source)
					)
				else
					warn(string.format("[Promise] - Uncaught exception in promise: %q", errOutput))
				end
			end
		end)
	end
end

function Promise._toHumanReadable<T...>(_self: Promise<T...>, data: any): string
	if type(data) == "table" then
		local errOutput
		local ok = pcall(function()
			errOutput = HttpService:JSONEncode(data)
		end)
		if not ok then
			errOutput = tostring(data)
		end
		return errOutput
	else
		return tostring(data)
	end
end

--[=[
	Handlers if/when promise is fulfilled/rejected. It takes up to two arguments, callback functions
	for the success and failure cases of the Promise. May return the same promise if certain behavior
	is met.

	:::info
	We do not comply with 2.2.4 (onFulfilled or onRejected must not be called until the execution context stack
	contains only platform code). This means promises may stack overflow, however, it also makes promises a lot cheaper
	:::

	If/when promise is rejected, all respective onRejected callbacks must execute in the order of their
	originating calls to then.

	If/when promise is fulfilled, all respective onFulfilled callbacks must execute in the order of their
	originating calls to then.

	@param onFulfilled function -- Called if/when fulfilled with parameters
	@param onRejected function -- Called if/when rejected with parameters
	@return Promise<T...>
]=]
function Promise.Then<T...>(self: Promise<T...>, onFulfilled: ((T...) -> any...)?, onRejected: ((...any) -> any...)?)
	if type(onRejected) == "function" then
		self._unconsumedException = false
	end

	if self._pendingExecuteList then
		local promise = Promise.new()
		self._pendingExecuteList[#self._pendingExecuteList + 1] = { onFulfilled, onRejected, promise }
		return promise
	else
		return self:_executeThen(onFulfilled, onRejected, nil)
	end
end

--[=[
	Like then, but the value passed down the chain is the resolved value of the promise, not
	the value returned from onFulfilled or onRejected

	Will still yield for the result if a promise is returned, but will discard the result.

	@param onFulfilled function
	@param onRejected function
	@return Promise<T...> -- Returns self
]=]
function Promise.Tap<T...>(self: Promise<T...>, onFulfilled, onRejected)
	-- Run immediately like then, but we return something safer!
	local result = self:Then(onFulfilled, onRejected)
	if result == self then
		return result
	end

	-- Most of the time we can just return the same
	-- promise. But sometimes we need to yield
	-- for the result to finish, and then resolve that result to a new result
	if result._fulfilled then
		return self
	elseif result._rejected then
		return self
	elseif result._pendingExecuteList then
		-- Definitely the most expensive case, might be able to make this better over time
		local function returnSelf()
			return self
		end

		return result:Then(returnSelf, returnSelf)
	else
		error("Bad result state")
	end
end

--[=[
	Executes upon pending stop

	@param func function
	@return Promise<T...>
]=]
function Promise.Finally<T...>(self: Promise<T...>, func)
	return self:Then(func, func)
end

--[=[
	Catch errors from the promise

	@param onRejected function
	@return Promise<T...>
]=]
function Promise.Catch<T...>(self: Promise<T...>, onRejected)
	return self:Then(nil, onRejected)
end

--[=[
	Rejects the current promise. Utility left for Maid task
]=]
function Promise.Destroy<T...>(self: Promise<T...>)
	self:_reject(EMPTY_PACKED_TUPLE)
end

--[=[
	Returns the results from the promise.

	:::warning
	This API surface will error if the promise is still pending.
	:::

	@return boolean -- true if resolved, false otherwise.
	@return any
]=]
function Promise.GetResults<T...>(self: Promise<T...>): (boolean, T...)
	if self._rejected then
		return false, table.unpack(self._rejected, 1, self._rejected.n)
	elseif self._fulfilled then
		return true, table.unpack(self._fulfilled, 1, self._fulfilled.n)
	else
		error("Still pending")
	end
end

function Promise._getResolveReject<T...>(self: Promise<T...>): (Resolve<T...>, Reject)
	return function(...)
		self:Resolve(...)
	end, function(...)
		self:_reject(table.pack(...))
	end
end

--[=[
	@private

	@param onFulfilled function?
	@param onRejected function?
	@param promise2 Promise<T...>? -- May be nil. If it is, then we have the option to return self
	@return Promise
]=]
function Promise._executeThen<T...>(self: Promise<T...>, onFulfilled, onRejected, promise2)
	if self._fulfilled then
		if type(onFulfilled) == "function" then
			-- If either onFulfilled or onRejected returns a value x, run
			-- the Promise Resolution Procedure [[Resolve]](promise2, x).
			if promise2 then
				promise2:Resolve(onFulfilled(table.unpack(self._fulfilled, 1, self._fulfilled.n)))
				return promise2
			else
				local results = table.pack(onFulfilled(table.unpack(self._fulfilled, 1, self._fulfilled.n)))
				if results.n == 0 then
					return _emptyFulfilledPromise
				elseif results.n == 1 and Promise.isPromise(results[1]) then
					return results[1]
				else
					local promise = Promise.new()
					-- Technically undefined behavior from A+, but we'll resolve to nil like ES6 promises
					promise:Resolve(table.unpack(results, 1, results.n))
					return promise
				end
			end
		else
			-- If onFulfilled is not a function, it must be ignored.
			-- If onFulfilled is not a function and promise1 is fulfilled,
			-- promise2 must be fulfilled with the same value as promise1.
			if promise2 then
				promise2:_fulfill(self._fulfilled)
				return promise2
			else
				return self
			end
		end
	elseif self._rejected then
		if type(onRejected) == "function" then
			-- If either onFulfilled or onRejected returns a value x, run
			-- the Promise Resolution Procedure [[Resolve]](promise2, x).
			if promise2 then
				promise2:Resolve(onRejected(table.unpack(self._rejected, 1, self._rejected.n)))
				return promise2
			else
				local results = table.pack(onRejected(table.unpack(self._rejected, 1, self._rejected.n)))
				if results.n == 0 then
					return _emptyFulfilledPromise
				elseif results.n == 1 and Promise.isPromise(results[1]) then
					return results[1]
				else
					local promise = Promise.new()
					-- Technically undefined behavior from A+, but we'll resolve to nil like ES6 promises
					promise:Resolve(table.unpack(results, 1, results.n))
					return promise
				end
			end
		else
			-- If onRejected is not a function, it must be ignored.
			-- If onRejected is not a function and promise1 is rejected, promise2 must be
			-- rejected with the same reason as promise1.
			if promise2 then
				promise2:_reject(self._rejected)

				return promise2
			else
				return self
			end
		end
	else
		error("Internal error: still pending")
	end
end

-- Initialize promise values
_emptyFulfilledPromise = Promise.new()
_emptyFulfilledPromise:_fulfill(EMPTY_PACKED_TUPLE)

_emptyRejectedPromise = Promise.new()
_emptyRejectedPromise:_reject(EMPTY_PACKED_TUPLE)

return Promise
