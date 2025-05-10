--!strict
--[=[
	Debounce a existing function by timeout

	@class throttle
]=]

local require = require(script.Parent.loader).load(script)

local ThrottledFunction = require("ThrottledFunction")
local TypeUtils = require("TypeUtils")

export type ThrottleConfig = ThrottledFunction.ThrottleConfig

--[=[
	Provides a debounce function call on an operation.

	@function throttle
	@within throttle
	@param timeoutInSeconds number
	@param func function
	@param throttleConfig? { leading = true; trailing = true; }
	@return function
]=]
local function throttle<T...>(
	timeoutInSeconds: number,
	func: ThrottledFunction.Func<T...>,
	throttleConfig: ThrottledFunction.ThrottleConfig
): (T...) -> ()
	assert(type(timeoutInSeconds) == "number", "timeoutInSeconds is not a number")
	assert(type(func) == "function", "func is not a function")

	local throttled = ThrottledFunction.new(timeoutInSeconds, func, throttleConfig)

	return function(...: T...)
		throttled:Call(TypeUtils.anyValue(...))
	end
end

return throttle
