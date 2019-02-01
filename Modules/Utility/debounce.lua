--- debounce a existing function by timeout
-- @module debounce

--- Provides a debounce function call on an operation
-- @tparam number timeout
-- @tparam function func
-- @treturn function
local function debounce(timeout, func)
	assert(type(timeout) == "number")
	assert(type(func) == "function")

	local key = 1
	return function(...)
		key = key + 1
		local localKey = key
		local args = {...}

		delay(timeout, function()
			if key == localKey then
				func(unpack(args))
			end
		end)
	end
end

return debounce