---
-- @classmod Observable
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Subscription = require("Subscription")

local ENABLE_STACK_TRACING = false

local Observable = {}
Observable.ClassName = "Observable"
Observable.__index = Observable

function Observable.isObservable(item)
	return type(item) == "table" and item.ClassName == "Observable"
end

-- @param onSubscribe(subscription)
function Observable.new(onSubscribe)
	assert(type(onSubscribe) == "function")

	return setmetatable({
		_source = ENABLE_STACK_TRACING and debug.traceback() or "";
		_onSubscribe = onSubscribe;
	}, Observable)
end

function Observable:Pipe(transformers)
	assert(type(transformers) == "table", "Bad transformers")

	local current = self
	for _, transformer in pairs(transformers) do
		assert(type(transformer) == "function")
		current = transformer(current)
		assert(Observable.isObservable(current))
	end

	return current
end

--- Subscribes immediately, fireCallback may return
-- a maid to cleanup!
-- @param[opt=nil] fireCallback(value)
function Observable:Subscribe(fireCallback, failCallback, completeCallback)
	local sub = Subscription.new(fireCallback, failCallback, completeCallback)
	local cleanup = self._onSubscribe(sub)

	if cleanup then
		sub:_giveCleanup(cleanup)
	end

	return sub
end

return Observable