--[=[
	Debounce a existing function by timeout

	@class throttle
]=]

local require = require(script.Parent.loader).load(script)

local ThrottledFunction = require("ThrottledFunction")

--[=[
	Provides a debounce function call on an operation.

	@function throttle
	@within throttle
	@param timeoutInSeconds number
	@param func function
	@param throttleConfig? { leading = true; trailing = true; }
	@return function
]=]
local function throttle(timeoutInSeconds, func, throttleConfig)
	assert(type(timeoutInSeconds) == "number", "timeoutInSeconds is not a number")
	assert(type(func) == "function", "func is not a function")

	local throttled = ThrottledFunction.new(timeoutInSeconds, func, throttleConfig)

	return function(...)
		throttled:Call(...)
	end
end

return throttle