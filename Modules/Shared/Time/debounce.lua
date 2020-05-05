--- debounce a existing function by timeout
-- @function debounce

--- Provides a debounce function call on an operation
-- @tparam number timeout
-- @tparam function func
-- @treturn function
local function debounce(timeoutInSeconds, func)
	assert(type(timeoutInSeconds) == "number")
	assert(type(func) == "function")

	local key = 1
	return function(...)
		key = key + 1
		local localKey = key
		local n = select("#", ...)
		local args = {...}

		delay(timeoutInSeconds, function()
			if key == localKey then
				func(unpack(args, 1, n))
			end
		end)
	end
end

return debounce