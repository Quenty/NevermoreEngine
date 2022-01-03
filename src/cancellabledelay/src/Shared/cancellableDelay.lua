--[=[
	cancellableDelay a delay that can be cancelled
	@class cancellableDelay
]=]

--[=[
	@function cancellableDelay
	@param timeoutInSeconds number
	@param func function
	@param ... any -- Args to pass into the function
	@return function? -- Can be used to cancel
	@within cancellableDelay
]=]
local function cancellableDelay(timeoutInSeconds, func, ...)
	assert(type(timeoutInSeconds) == "number", "Bad timeoutInSeconds")
	assert(type(func) == "function", "Bad func")

	local n = select("#", ...)
	local args = {...}

	local cancelled = false
	task.delay(timeoutInSeconds, function()
		if not cancelled then
			func(unpack(args, 1, n))
		end
	end)

	return function()
		cancelled = true
	end
end

return cancellableDelay