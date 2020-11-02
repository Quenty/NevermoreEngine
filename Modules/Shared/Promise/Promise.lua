--- Promises, but without error handling as this screws with stack traces, using Roblox signals
-- @classmod Promise
-- See: https://promisesaplus.com/

local RunService = game:GetService("RunService")

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local fastSpawn = require("fastSpawn")

local function isPromise(value)
	return type(value) == "table" and value.ClassName == "Promise"
end

-- Turns out debug.traceback() is slow
local ENABLE_TRACEBACK = false
local _emptyRejectedPromise = nil
local _emptyFulfilledPromise = nil

local Promise = {}
Promise.ClassName = "Promise"
Promise.__index = Promise

--- Determines whether a value is a promise or not
-- @function isPromise
Promise.isPromise = isPromise

--- Construct a new promise
-- @constructor Promise.new()
-- @treturn Promise
function Promise.new(func)
	local self = setmetatable({
		_pendingExecuteList = {};
		_unconsumedException = true;
		_source = ENABLE_TRACEBACK and debug.traceback() or "";
	}, Promise)

	if type(func) == "function" then
		func(self:_getResolveReject())
	end

	return self
end

--- Initializes a new promise with the given function in a fastSpawn wrapper
function Promise.spawn(func)
	local self = Promise.new()

	-- Just the function part of the resolve/reject protocol!
	fastSpawn(func, self:_getResolveReject())

	return self
end

function Promise.resolved(...)
	local n = select("#", ...)
	if n == 0 then
		-- Reuse promise here to save on calls to Promise.resolved()
		return _emptyFulfilledPromise
	elseif n == 1 and isPromise(...) then
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

function Promise.rejected(...)
	local n = select("#", ...)
	if n == 0 then
		-- Reuse promise here to save on calls to Promise.rejected()
		return _emptyRejectedPromise
	end

	local promise = Promise.new()
	promise:_reject({...}, n)
	return promise
end

--- Returns whether or not the promise is pending
-- @treturn bool True if pending, false otherwise
function Promise:IsPending()
	return self._pendingExecuteList ~= nil
end

function Promise:IsFulfilled()
	return self._fulfilled ~= nil
end

function Promise:IsRejected()
	return self._rejected ~= nil
end

--- Yield until the promise is complete
function Promise:Wait()
	if self._fulfilled then
		return unpack(self._fulfilled, 1, self._valuesLength)
	elseif self._rejected then
		return error(tostring(self._rejected[1]), 2)
	else
		local bindable = Instance.new("BindableEvent")

		self:Then(function()
			bindable:Fire()
		end, function()
			bindable:Fire()
		end)

		bindable.Event:Wait()
		bindable:Destroy()

		if self._rejected then
			return error(tostring(self._rejected[1]), 2)
		else
			return unpack(self._fulfilled, 1, self._valuesLength)
		end
	end
end

function Promise:Yield()
	if self._fulfilled then
		return true, unpack(self._fulfilled, 1, self._valuesLength)
	elseif self._rejected then
		return false, unpack(self._rejected, 1, self._valuesLength)
	else
		local bindable = Instance.new("BindableEvent")

		self:Then(function()
			bindable:Fire()
		end, function()
			bindable:Fire()
		end)

		bindable.Event:Wait()
		bindable:Destroy()

		if self._fulfilled then
			return true, unpack(self._fulfilled, 1, self._valuesLength)
		elseif self._rejected then
			return false, unpack(self._rejected, 1, self._valuesLength)
		end
	end
end


--- Promise resolution procedure
-- Resolves a promise
-- @return self
function Promise:Resolve(...)
	if not self._pendingExecuteList then
		return
	end

	local len = select("#", ...)
	if len == 0 then
		self:_fulfill({}, 0)
	elseif self == (...) then
		self:Reject("TypeError: Resolved to self")
	elseif isPromise(...) then
		if len > 1 then
			local message = ("When resolving a promise, extra arguments are discarded! See:\n\n%s")
				:format(self._source)
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
						self:_reject({...}, select("#", ...))
					end
				end,
				nil
			}
		elseif promise2._rejected then -- rejected
			promise2._unconsumedException = false
			self:_reject(promise2._rejected, promise2._valuesLength)
		elseif promise2._fulfilled then -- fulfilled
			self:_fulfill(promise2._fulfilled, promise2._valuesLength)
		else
			error("[Promise.Resolve] - Bad promise2 state")
		end
	elseif type(...) == "function" then
		if len > 1 then
			local message = ("When resolving a function, extra arguments are discarded! See:\n\n%s")
				:format(self._source)
			warn(message)
		end

		local func = {...}
		func(self:_getResolveReject())
	else
		-- TODO: Handle thenable promises!
		-- Problem: Lua has :andThen() and also :Then() as two methods in promise
		-- implementations.
		self:_fulfill({...}, len)
	end
end

--- Fulfills the promise with the value
-- @param ... Params to _fulfill with
-- @return self
function Promise:_fulfill(values, valuesLength)
	if not self._pendingExecuteList then
		return
	end

	self._fulfilled = values
	self._valuesLength = valuesLength

	local list = self._pendingExecuteList
	self._pendingExecuteList = nil
	for _, data in pairs(list) do
		self:_executeThen(unpack(data))
	end
end

--- Rejects the promise with the value given
-- @param ... Params to reject with
-- @return self
function Promise:Reject(...)
	self:_reject({...}, select("#", ...))
end

function Promise:_reject(values, valuesLength)
	if not self._pendingExecuteList then
		return
	end

	self._rejected = values
	self._valuesLength = valuesLength

	local list = self._pendingExecuteList
	self._pendingExecuteList = nil
	for _, data in pairs(list) do
		self:_executeThen(unpack(data))
	end

	-- Check for uncaught exceptions
	if self._unconsumedException and self._valuesLength > 0 then
		coroutine.resume(coroutine.create(function()
			-- Yield to end of frame, giving control back to Roblox.
			-- This is the equivalent of giving something back to a task manager.
			RunService.Heartbeat:Wait()

			if self._unconsumedException then
				if ENABLE_TRACEBACK then
					warn(("[Promise] - Uncaught exception in promise\n\n%q\n\n%s")
						:format(tostring(self._rejected[1]), self._source))
				else
					warn(("[Promise] - Uncaught exception in promise: %q")
						:format(tostring(self._rejected[1])))
				end
			end
		end))
	end
end

--- Handlers if/when promise is fulfilled/rejected. It takes up to two arguments, callback functions
-- for the success and failure cases of the Promise. May return the same promise if certain behavior
-- is met.
-- NOTE: We do not comply with 2.2.4 (onFulfilled or onRejected must not be called until the execution context stack
-- contains only platform code). This means promises may stack overflow, however, it also makes promises a lot cheaper
-- @tparam[opt=nil] function onFulfilled Called if/when fulfilled with parameters
	-- If/when promise is fulfilled, all respective onFulfilled callbacks must execute in the order of their
	-- originating calls to then.
-- @tparam[opt=nil] function onRejected Called if/when rejected with parameters
	-- If/when promise is rejected, all respective onRejected callbacks must execute in the order of their
	-- originating calls to then.
-- @treturn Promise
function Promise:Then(onFulfilled, onRejected)
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

-- Like then, but the value passed down the chain is the resolved value of the promise, not
-- the value returned from onFulfilled or onRejected
-- Will still yield for the result if a promise is returned, but will discard the result.
function Promise:Tap(onFulfilled, onRejected)
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

function Promise:Finally(func)
	return self:Then(func, func)
end

--- Catch errors from the promise
-- @treturn Promise
function Promise:Catch(onRejected)
	return self:Then(nil, onRejected)
end

--- Rejects the current promise.
-- Utility left for Maid task
-- @treturn nil
function Promise:Destroy()
	self:_reject({}, 0)
end

function Promise:GetResults()
	if self._rejected then
		return false, unpack(self._rejected, 1, self._valuesLength)
	elseif self._fulfilled then
		return true, unpack(self._fulfilled, 1, self._valuesLength)
	else
		error("Still pending")
	end
end

function Promise:_getResolveReject()
	return function(...)
		self:Resolve(...)
	end, function(...)
		self:_reject({...}, select("#", ...))
	end
end

-- @param promise2 May be nil. If it is, then we have the option to return self
function Promise:_executeThen(onFulfilled, onRejected, promise2)
	if self._fulfilled then
		if type(onFulfilled) == "function" then
			-- If either onFulfilled or onRejected returns a value x, run
			-- the Promise Resolution Procedure [[Resolve]](promise2, x).
			if promise2 then
				promise2:Resolve(onFulfilled(unpack(self._fulfilled, 1, self._valuesLength)))
				return promise2
			else
				local results = table.pack(onFulfilled(unpack(self._fulfilled, 1, self._valuesLength)))
				if results.n == 0 then
					return _emptyFulfilledPromise
				elseif results.n == 1 and isPromise(results[1]) then
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
				promise2:_fulfill(self._fulfilled, self._valuesLength)
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
				promise2:Resolve(onRejected(unpack(self._rejected, 1, self._valuesLength)))
				return promise2
			else
				local results = table.pack(onRejected(unpack(self._rejected, 1, self._valuesLength)))
				if results.n == 0 then
					return _emptyFulfilledPromise
				elseif results.n == 1 and isPromise(results[1]) then
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
				promise2:_reject(self._rejected, self._valuesLength)

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
_emptyFulfilledPromise:_fulfill({}, 0)

_emptyRejectedPromise = Promise.new()
_emptyRejectedPromise:_reject({}, 0)

return Promise