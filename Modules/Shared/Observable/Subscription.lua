---
-- @classmod Subscription
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local MaidTaskUtils = require("MaidTaskUtils")

local Subscription = {}
Subscription.ClassName = "Subscription"
Subscription.__index = Subscription

local stateTypes = {
	PENDING = "pending";
	FAILED = "failed";
	COMPLETE = "complete";
	CANCELLED = "cancelled";
}

function Subscription.new(fireCallback, failCallback, completeCallback, onSubscribe)
	assert(type(fireCallback) == "function" or fireCallback == nil)
	assert(type(failCallback) == "function" or failCallback == nil)
	assert(type(completeCallback) == "function" or completeCallback == nil)

	return setmetatable({
		_state = stateTypes.PENDING;
		_fireCallback = fireCallback;
		_failCallback = failCallback;
		_completeCallback = completeCallback;
		_onSubscribe = onSubscribe;
	}, Subscription)
end

function Subscription:Fire(...)
	if self._state == stateTypes.PENDING and self._fireCallback then
		self._fireCallback(...)
	elseif self._state == stateTypes.CANCELLED then
		warn("[Subscription.Fire] - We are cancelled, but events are still being pushed")
	end
end

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

function Subscription:GetFireFailComplete()
	return
	function(...)
		self:Fire(...)
	end, function(...)
		self:Fail(...)
	end, function(...)
		self:Complete(...)
	end
end


function Subscription:GetFailComplete()
	return function(...)
		self:Fail(...)
	end, function(...)
		self:Complete(...)
	end
end

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

function Subscription:_giveCleanup(task)
	assert(task)
	assert(not self._cleanupTask)

	if self._state ~= stateTypes.PENDING then
		MaidTaskUtils.doTask(task)
		return
	end

	self._cleanupTask = task
end

function Subscription:_doCleanup()
	if self._cleanupTask then
		MaidTaskUtils.doTask(self._cleanupTask)
		self._cleanupTask = nil
	end
end

function Subscription:Destroy()
	if self._state == stateTypes.PENDING then
		self._state = stateTypes.CANCELLED
	end

	self:_doCleanup()
end

return Subscription