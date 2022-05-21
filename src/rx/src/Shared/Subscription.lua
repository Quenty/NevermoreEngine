--[=[
	Subscriptions are used in the callback for an [Observable](/api/Observable). Standard usage
	is as follows.

	```lua
	-- Constucts an observable which will emit a, b, c via a subscription
	Observable.new(function(sub)
		sub:Fire("a")
		sub:Fire("b")
		sub:Fire("c")
		sub:Complete() -- ends stream
	end)
	```
	@class Subscription
]=]

local require = require(script.Parent.loader).load(script)

local MaidTaskUtils = require("MaidTaskUtils")

local ENABLE_STACK_TRACING = false

local Subscription = {}
Subscription.ClassName = "Subscription"
Subscription.__index = Subscription

local stateTypes = {
	PENDING = "pending";
	FAILED = "failed";
	COMPLETE = "complete";
	CANCELLED = "cancelled";
}

--[=[
	Constructs a new Subscription

	@param fireCallback function?
	@param failCallback function?
	@param completeCallback function?
	@param onSubscribe () -> MaidTask
	@return Subscription
]=]
function Subscription.new(fireCallback, failCallback, completeCallback, onSubscribe)
	assert(type(fireCallback) == "function" or fireCallback == nil, "Bad fireCallback")
	assert(type(failCallback) == "function" or failCallback == nil, "Bad failCallback")
	assert(type(completeCallback) == "function" or completeCallback == nil, "Bad completeCallback")

	return setmetatable({
		_state = stateTypes.PENDING;
		_source = ENABLE_STACK_TRACING and debug.traceback() or "";
		_fireCallback = fireCallback;
		_failCallback = failCallback;
		_completeCallback = completeCallback;
		_onSubscribe = onSubscribe;
	}, Subscription)
end

--[=[
	Fires the subscription

	@param ... any
]=]
function Subscription:Fire(...)
	if self._state == stateTypes.PENDING then
		if self._fireCallback then
			self._fireCallback(...)
		end
	elseif self._state == stateTypes.CANCELLED then
		warn("[Subscription.Fire] - We are cancelled, but events are still being pushed")

		if ENABLE_STACK_TRACING then
			print(debug.traceback())
			print(self._source)
		end
	end
end

--[=[
	Fails the subscription, preventing anything else from emitting.
]=]
function Subscription:Fail()
	if self._state ~= stateTypes.PENDING then
		return
	end

	self._state = stateTypes.FAILED

	if self._failCallback then
		self._failCallback()
	end

	self:_doCleanup()
end


--[=[
	Returns a tuple of fire, fail and complete functions which
	can be chained into the the next subscription.

	```lua
	return function(source)
		return Observable.new(function(sub)
			sub:Fire("hi")

			return source:Subscribe(sub:GetFireFailComplete())
		end)
	end
	```

	@return function
	@return function
	@return function
]=]
function Subscription:GetFireFailComplete()
	return function(...)
		self:Fire(...)
	end, function(...)
		self:Fail(...)
	end, function(...)
		self:Complete(...)
	end
end

--[=[
	Returns a tuple of fail and complete functions which
	can be chained into the the next subscription.

	```lua
	return function(source)
		return Observable.new(function(sub)
			return source:Subscribe(function(result)
				sub:Fire(tostring(result))
			end, sub:GetFailComplete()) -- Reuse is easy here!
		end)
	end
	```

	@return function
	@return function
]=]
function Subscription:GetFailComplete()
	return function(...)
		self:Fail(...)
	end, function(...)
		self:Complete(...)
	end
end

--[=[
	Completes the subscription, preventing anything else from being
	emitted.
]=]
function Subscription:Complete()
	if self._state ~= stateTypes.PENDING then
		return
	end

	self._state = stateTypes.COMPLETE
	if self._completeCallback then
		self._completeCallback()
	end

	self:_doCleanup()
end

--[=[
	Returns whether the subscription is pending.
	@return boolean
]=]
function Subscription:IsPending()
	return self._state == stateTypes.PENDING
end

function Subscription:_giveCleanup(task)
	assert(task, "Bad task")
	assert(not self._cleanupTask, "Already have _cleanupTask")

	if self._state ~= stateTypes.PENDING then
		MaidTaskUtils.doTask(task)
		return
	end

	self._cleanupTask = task
end

function Subscription:_doCleanup()
	if self._cleanupTask then
		local task = self._cleanupTask
		self._cleanupTask = nil
		MaidTaskUtils.doTask(task)
	end
end

--[=[
	Cleans up the subscription

	:::tip
	This will be invoked by the Observable automatically, and should not
	be called within the usage of a subscription.
	:::
]=]
function Subscription:Destroy()
	if self._state == stateTypes.PENDING then
		self._state = stateTypes.CANCELLED
	end

	self:_doCleanup()
end

--[=[
	Alias for [Subscription.Destroy].
]=]
function Subscription:Disconnect()
	self:Destroy()
end

return Subscription