--!strict
--[=[
	Utilities involving signals
	@class SignalUtils
]=]

local SignalUtils = {}

--[=[
	Executes on the next event connection.
	@param event RBXScriptSignal
	@param callback function
	@return RBXScriptConnection
]=]
function SignalUtils.onNext(event: RBXScriptSignal, callback: () -> ())
	assert(typeof(event) == "RBXScriptSignal", "Bad event")
	assert(type(callback) == "function", "Bad callback")

	return event:Once(callback)
end

return SignalUtils
