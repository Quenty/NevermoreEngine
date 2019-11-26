---
-- @module SignalMiddleware

local SignalMiddleware = {}

function SignalMiddleware.fireOnDispatch(signal)
	assert(signal)

	return function(nextDispatch, store)
		return function(action)
			if signal.Destroy then
				signal:Fire(action)
			else
				warn("[SignalMiddleware.fireOnDispatch] - Signal is destroyed, but middleware is still connected")
			end

			nextDispatch(action)
		end
	end
end

return SignalMiddleware