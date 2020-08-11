--- debounce a existing function by timeout
-- @module debounce

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local ThrottledFunction = require("ThrottledFunction")

--- Provides a debounce function call on an operation
-- @tparam number timeout
-- @tparam function func
-- @param throttleConfig = { leading = true; trailing = true; }
-- @treturn function
local function throttle(timeoutInSeconds, func, throttleConfig)
	assert(type(timeoutInSeconds) == "number", "timeoutInSeconds is not a number")
	assert(type(func) == "function", "func is not a function")

	local throttled = ThrottledFunction.new(timeoutInSeconds, func, throttleConfig)

	return function(...)
		throttled:Call(...)
	end
end

return throttle