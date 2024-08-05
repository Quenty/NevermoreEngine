--[=[
	Utilities involving signals
	@class SignalUtils
]=]

local SignalUtils = {}

--[=[
	Executes on the next event connection.
	@param event RBXScriptSignal
	@param _function function
	@return RBXScriptConnection
]=]
function SignalUtils.onNext(event, _function)
	assert(typeof(event) == "RBXScriptSignal", "Bad event")
	assert(type(_function) == "function", "Bad _function")

	return event:Once(_function)
end

return SignalUtils