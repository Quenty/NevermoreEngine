--- Promises, but without error handling as this screws with stack traces, using Roblox signals
-- @classmod Promise
-- See: https://promisesaplus.com/

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local Maid = LoadCustomLibrary("Maid")

local function _isCallable(Value)
	if type(Value) == "function" then
		return true
	elseif type(Value) == "table" then
		local Metatable = getmetatable(Value)
		return Metatable and type(Metatable.__call) == "function"
	end
end

local function _isSignal(Value)
	if typeof(Value) == "RBXScriptSignal" then
		return true
	elseif type(Value) == "table" and _isCallable(Value.Connect) then
		return true
	end

	return false
end

local function _isPromise(Value)
	if type(Value) == "table" and Value.ClassName == "Promise" then
		return true
	end
	return false
end

local Promise = {}
Promise.ClassName = "Promise"
Promise.__index = Promise
Promise.catchErrors = false -- A+ compliance if true

--- Construct a new promise
-- @constructor Promise.new()
-- @param Value, default nil
-- @treturn Promise
function Promise.new(value, catchErrors)
	local self = setmetatable({}, Promise)

	self.catchErrors = catchErrors
	self._pendingMaid = Maid.new()
	self:_promisify(value)

	return self
end

--- Returns the value of the first promise resolved
-- @constructor First
-- @tparam Array(Promise) Promises
-- @treturn Promise Promise that resolves with first result
function Promise.First(promises)
	local returnPromise = Promise.new()

	local function syncronize(method)
		return function(...)
			returnPromise[method](returnPromise, ...)
		end
	end

	for _, promise in pairs(promises) do
		promise:Then(syncronize("Fulfill"), syncronize("Reject"))
	end

	return returnPromise
end

---
-- @constructor First
-- @treturn Promise
function Promise.All(promises)
	local remainingCount = #promises
	local returnPromise = Promise.new()
	local results = {}
	local allFulfilled = true

	local function Syncronize(index, isFullfilled)
		return function(Value)
			allFulfilled = allFulfilled and isFullfilled
			results[index] = Value
			remainingCount = remainingCount - 1
			if remainingCount == 0 then
				local method = allFulfilled and "Fulfill" or "Reject"
				returnPromise[method](returnPromise, unpack(results))
			end
		end
	end

	for index, promise in pairs(promises) do
		promise:Then(Syncronize(index, true), Syncronize(index, false))
	end

	return returnPromise
end

--- Returns whether or not the promise is pending
-- @treturn bool True if pending, false otherwise
function Promise:IsPending()
	return self._pendingMaid ~= nil
end

--- Yield until the promise is complete
function Promise:Await()
	if self._fulfilled then
		return unpack(self._fulfilled)
	elseif self._rejected then
		return unpack(self._rejected)
	else
		local result
		local bindable = Instance.new("BindableEvent")
		self._pendingMaid:GiveTask(bindable)

		self:Then(function(...)
			result = {...}
			bindable:Fire(true)
		end, function(...)
			result = {...}
			bindable:Fire(false)
		end)

		local ok = bindable.Event:Wait()
		bindable:Destroy()

		if not ok then
			error(tostring(result[1]), 2)
		end

		return unpack(result)
	end
end

---
-- Resolves a promise
-- @treturn nil
function Promise:Resolve(value)
	if self == value then
		self:Reject("TypeError: Resolved to self")
		return
	end

	if _isPromise(value) then
		value:Then(function(...)
			self:Fulfill(...)
		end, function(...)
			self:Reject(...)
		end)
		return
	end

	-- Thenable like objects
	if type(value) == "table" and _isCallable(value.Then) then
		value:Then(self:_getResolveReject())
		return
	end

	self:Fulfill(value)
end

--- Fulfills the promise with the value
-- @param ... Params to fulfill with
-- @treturn nil
function Promise:Fulfill(...)
	if not self:IsPending() then
		return
	end

	self._fulfilled = {...}
	self:_endPending()
end

--- Rejects the promise with the value given
-- @param ... Params to reject with
-- @treturn nil
function Promise:Reject(...)
	if not self:IsPending() then
		return
	end

	self._rejected = {...}
	self:_endPending()
end

--- Handlers when promise is fulfilled/rejected
-- @tparam[opt=nil] function onFulfilled Called when fulfilled with parameters
-- @tparam[opt=nil] function onRejected Called when rejected with parameters
-- @treturn Promise
function Promise:Then(onFulfilled, onRejected)
	local returnPromise = Promise.new()

	if self._pendingMaid then
		self._pendingMaid:GiveTask(function()
			self:_executeThen(returnPromise, onFulfilled, onRejected)
		end)
	else
		self:_executeThen(returnPromise, onFulfilled, onRejected)
	end
	
	return returnPromise
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
	self:Reject()
end

--- Modifies values into promises
-- @local
function Promise:_promisify(value)
	if _isCallable(value) then
		self:_promisfyYieldingFunction(value)
	elseif _isSignal(value) then
		self:_promisfySignal(value)
	end
end

function Promise:_promisfySignal(signal)
	if not self._pendingMaid then
		return
	end

	self._pendingMaid:GiveTask(signal:Connect(function(...)
		self:Fulfill(...)
	end))

	return
end

function Promise:_promisfyYieldingFunction(yieldingFunction)
	if not self._pendingMaid then
		return
	end

	local maid = Maid.new()

	-- Hack to spawn new thread fast
	local bindable = Instance.new("BindableEvent")
	maid:GiveTask(bindable)
	maid:GiveTask(bindable.Event:Connect(function()
		maid:DoCleaning()
		if self.catchErrors then
			local results = self:_executeFunc(self, yieldingFunction, {self:_getResolveReject()})
			if self:IsPending() then
				self:Resolve(results)
			end
		else
			self:Resolve(yieldingFunction(self:_getResolveReject()))
		end
	end))
	self._pendingMaid:GiveTask(maid)
	bindable:Fire()
end

function Promise:_getResolveReject()
	local called = false

	local function resolvePromise(...)
		if called then
			return
		end
		called = true
		self:Resolve(...)
	end

	local function rejectPromise(...)
		if called then
			return
		end
		called = true
		self:Reject(...)
	end

	return resolvePromise, rejectPromise
end

function Promise:_executeFunc(returnPromise, func, args)
	if not self.catchErrors then
		return {func(unpack(args))}
	end

	local results
	local success, err = pcall(function()
		results = {func(unpack())}
	end)
	if not success then
		returnPromise:Reject(err)
	end
	return results
end

function Promise:_executeThen(returnPromise, onFulfilled, onRejected)
	local results
	if self._fulfilled then
		if not _isCallable(onFulfilled) then
			return returnPromise:Fulfill(unpack(self._fulfilled))
		end

		results = self:_executeFunc(returnPromise, onFulfilled, self._fulfilled)
	elseif self._rejected then
		if not _isCallable(onRejected) then
			return returnPromise:Reject(unpack(self._rejected))
		end

		results = self:_executeFunc(returnPromise, onRejected, self._rejected)
	else
		error("Internal error, cannot execute while pending")
	end

	if results and #results > 0 then
		returnPromise:Resolve(results[1])
	end
end

function Promise:_endPending()
	local maid = self._pendingMaid
	self._pendingMaid = nil
	maid:DoCleaning()
end

return Promise