--- Promises, but without error handling as this screws with stack traces, using Roblox signals
-- @classmod Promise
-- See: https://promisesaplus.com/

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local fastSpawn = require("fastSpawn")

local function isPromise(value)
	return type(value) == "table" and value.ClassName == "Promise"
end

-- Turns out debug.traceback() is slow
local ENABLE_TRACEBACK = false

local Promise = {}
Promise.ClassName = "Promise"
Promise.__index = Promise
Promise.IsPromise = isPromise

--- Construct a new promise
-- @constructor Promise.new()
-- @treturn Promise
function Promise.new(func)
	local self = setmetatable({
		_pendingExecuteList = {};
		_uncaughtException = true;
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

	fastSpawn(func, self:_getResolveReject())

	return self
end

function Promise.resolved(...)
	local promise = Promise.new()
	promise:Resolve(...)
	return promise
end

function Promise.rejected(...)
	local promise = Promise.new()
	promise:Reject(...)
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
		if promise2._pendingExecuteList then
			promise2:Then(self:_getResolveReject())
		elseif promise2._rejected then
			promise2._uncaughtException = false
			self:Reject(unpack(promise2._rejected, 1, promise2._valuesLength))
		elseif promise2._fulfilled then
			promise2._uncaughtException = false
			self:_fulfill(promise2._fulfilled, promise2._valuesLength)
		else
			error("[Promise.Resolve] - Bad promise2 state")
		end
	else -- TODO: Handle thenable promises
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
	if self._uncaughtException and self._valuesLength > 0 then
		spawn(function()
			if self._uncaughtException then
				warn(("[Promise] - Uncaught exception in promise\n\n%s\n\n%s"):format(tostring(self._rejected[1]), self._source))
			end
		end)
	end
end

--- Handlers when promise is fulfilled/rejected. It takes up to two arguments, callback functions
-- for the success and failure cases of the Promise. May return the same promise if certain behavior
-- is met.
-- @tparam[opt=nil] function onFulfilled Called when fulfilled with parameters
-- @tparam[opt=nil] function onRejected Called when rejected with parameters
-- @treturn Promise
function Promise:Then(onFulfilled, onRejected)
	self._uncaughtException = false

	if self._pendingExecuteList then
		local promise = Promise.new()
		self._pendingExecuteList[#self._pendingExecuteList + 1] = { promise, onFulfilled, onRejected }
		return promise
	else
		return self:_executeThen(nil, onFulfilled, onRejected)
	end
end

function Promise:Finally(func)
	return self:Then(func, func)
end

--- Catch errors from the promise
-- @treturn Promise
function Promise:Catch(func)
	return self:Then(nil, func)
end

--- Rejects the current promise.
-- Utility left for Maid task
-- @treturn nil
function Promise:Destroy()
	self:_reject({}, 0)
end

function Promise:_getResolveReject()
	return function(...)
		self:Resolve(...)
	end, function(...)
		self:Reject(...)
	end
end

-- @param promise2 May be nil. If it is, then we have the option to return self
function Promise:_executeThen(promise2, onFulfilled, onRejected)
	if self._fulfilled then
		if type(onFulfilled) == "function" then
			if not promise2 then
				promise2 = Promise.new()
			end
			-- Technically undefined behavior from A+, but we'll resolve to nil like ES6 promises
			promise2:Resolve(onFulfilled(unpack(self._fulfilled, 1, self._valuesLength)))
			return promise2
		else
			-- Promise2 Fulfills with promise1 (self) value
			if promise2 then
				promise2:_fulfill(self._fulfilled, self._valuesLength)
				return promise2
			else
				return self
			end
		end
	elseif self._rejected then
		if type(onRejected) == "function" then
			if not promise2 then
				promise2 = Promise.new()
			end
			-- Technically undefined behavior from A+, but we'll resolve to nil like ES6 promises
			promise2:Resolve(onRejected(unpack(self._rejected, 1, self._valuesLength)))

			return promise2
		else
			-- Promise2 Rejects with promise1 (self) value
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

return Promise