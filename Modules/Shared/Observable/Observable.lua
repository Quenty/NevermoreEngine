---
-- @classmod Observable
-- @author Quenty

local Observable = {}
Observable.ClassName = "Observable"
Observable.__index = Observable

-- @param onSubscribe(fire)
function Observable.new(onSubscribe)
	return setmetatable({
		_onSubscribe = assert(onSubscribe, "No onSubscribe")
	}, Observable)
end

--- Subscribes immediately, fireCallback may return
-- a maid to cleanup!
-- @param fireCallback(value) => cleanup
function Observable:Subscribe(fireCallback)
	assert(type(fireCallback) == "function")

	local cleanup = self._onSubscribe(fireCallback)

	assert(cleanup, "No cleanup from subscription!")
	return cleanup
end

-- @param lifter(fire, params) => cleanup
function Observable:Lift(lifter)
	return Observable.new(function(fire)
		return self:Subscribe(function(...)
			return assert(lifter(fire, ...), "No cleanup function from lifter")
		end)
	end)
end

function Observable:Pipe(transformers)
	assert(type(transformers) == "table")

	local current = self
	for _, transformer in pairs(transformers) do
		assert(type(transformer) == "function")
		current = transformer(current)
		assert(current.ClassName == "Observable")
	end

	return current
end

return Observable