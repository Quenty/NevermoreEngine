--- cancellableDelay a delay that can be cancelled
-- @module debounce

local function cancellableDelay(timeoutInSeconds, func, ...)
	assert(type(timeoutInSeconds) == "number")
	assert(type(func) == "function")

	local n = select("#", ...)
	local args = {...}

	local cancelled = false
	delay(timeoutInSeconds, function()
		if not cancelled then
			func(unpack(args, 1, n))
		end
	end)

	return function()
		cancelled = true
	end
end

return cancellableDelay