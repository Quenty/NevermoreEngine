--- Promises, but without error handling as this screws with stack traces, using Roblox signals
-- @classmod Promise
-- See: https://promisesaplus.com/

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Maid = require("Maid")

local function _isSignal(value)
	if typeof(value) == "RBXScriptSignal" then
		return true
	elseif type(value) == "table" and type(value.Connect) == "function" then
		return true
	end

	return false
end

local function isPromise(value)
	if type(value) == "table" and value.ClassName == "Promise" then
		return true
	end
	return false
end

local Promise = {}
Promise.ClassName = "Promise"
Promise.__index = Promise
Promise.CatchErrors = false -- A+ compliance if true
Promise.IsPromise = isPromise

--- Construct a new promise
-- @constructor Promise.new()
-- @param value, default nil
-- @treturn Promise
function Promise.new(value)
	local self = setmetatable({}, Promise)

	self._pendingMaid = Maid.new()
	self:_promisify(value)

	return self
end

function Promise.resolved(...)
	return Promise.new():Resolve(...)
end

function Promise.rejected(...)
	return Promise.new():Reject(...)
end

--- Returns whether or not the promise is pending
-- @treturn bool True if pending, false otherwise
function Promise:IsPending()
	return self._pendingMaid ~= nil
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
		return unpack(self._fulfilled)
	elseif self._rejected then
		return error(tostring(self._rejected[1]), 2)
	else
		local result
		local bindable = Instance.new("BindableEvent")

		self:Then(function(...)
			result = {...}
			bindable:Fire()
		end, function(...)
			result = {...}
			bindable:Fire()
		end)

		bindable.Event:Wait()
		bindable:Destroy()

		if self:IsRejected() then
			return error(tostring(result[1]), 2)
		end

		return unpack(result)
	end
end

---
-- Resolves a promise
-- @return self
function Promise:Resolve(...)
	local valueLength = select("#", ...)

	-- Treat tuples as an array under A+ compliance
	if valueLength > 1 then
		self:Fulfill(...)
		return self
	end

	local value = ...
	if self == value then
		self:Reject("TypeError: Resolved to self")
		return self
	end

	if isPromise(value) then
		value:Then(function(...)
			self:Fulfill(...)
		end, function(...)
			self:Reject(...)
		end)
		return self
	end

	-- Thenable like objects
	if type(value) == "table" and type(value.Then) == "function" then
		value:Then(self:_getResolveReject())
		return self
	end

	self:Fulfill(value)
	return self
end

--- Fulfills the promise with the value
-- @param ... Params to fulfill with
-- @return self
function Promise:Fulfill(...)
	if not self:IsPending() then
		return
	end

	self._fulfilled = {...}
	self:_endPending()
	return self
end

--- Rejects the promise with the value given
-- @param ... Params to reject with
-- @return self
function Promise:Reject(...)
	if not self:IsPending() then
		return
	end

	self._rejected = {...}
	self:_endPending()
	return self
end

--- Handlers when promise is fulfilled/rejected. It takes up to two arguments, callback functions
-- for the success and failure cases of the Promise
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
	self:Reject()
end

--- Modifies values into promises
-- @local
function Promise:_promisify(value)
	if type(value) == "function" then
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
		if self.CatchErrors then
			local resultList = self:_executeFunc(self, yieldingFunction, {self:_getResolveReject()})
			if self:IsPending() then
				self:Resolve(unpack(resultList))
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
	if not self.CatchErrors then
		return {func(unpack(args))}
	end

	local resultList
	local success, err = pcall(function()
		resultList = {func(unpack())}
	end)
	if not success then
		returnPromise:Reject(err)
	end
	return resultList
end

function Promise:_executeThen(returnPromise, onFulfilled, onRejected)
	local resultList
	if self._fulfilled then
		if type(onFulfilled) ~= "function" then
			return returnPromise:Fulfill(unpack(self._fulfilled))
		end

		resultList = self:_executeFunc(returnPromise, onFulfilled, self._fulfilled)
	elseif self._rejected then
		if type(onRejected) ~= "function" then
			return returnPromise:Reject(unpack(self._rejected))
		end

		resultList = self:_executeFunc(returnPromise, onRejected, self._rejected)
	else
		error("Internal error, cannot execute while pending")
	end

	if resultList and #resultList > 0 then
		returnPromise:Resolve(unpack(resultList))
	end
end

function Promise:_endPending()
	local maid = self._pendingMaid
	self._pendingMaid = nil
	maid:DoCleaning()
end

return Promise