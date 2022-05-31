--[=[
	A version of task.delay that can be cancelled. Soon to be useless.
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

	local args = table.pack(...)

	local running
	task.spawn(function()
		running = coroutine.running()
		task.wait(timeoutInSeconds)
		local localArgs = args
		running = nil
		args = nil
		func(table.unpack(localArgs, 1, localArgs.n))
	end)

	return function()
		if running then
			coroutine.close(running)
			running = nil
			args = nil
		end
	end
end

return cancellableDelay