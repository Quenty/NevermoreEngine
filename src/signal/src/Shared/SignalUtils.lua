--- Utilities involving signals
-- @module SignalUtils

local SignalUtils = {}

function SignalUtils.onNext(event, _function)
	assert(typeof(event) == "RBXScriptSignal", "Bad event")
	assert(type(_function) == "function", "Bad _function")

	local conn
	conn = event:Connect(function(...)
		if conn.Connected then
			return -- Multiple events got queued
		end

		conn:Disconnect()
		_function(...)
	end)

	return conn
end

return SignalUtils