--!strict
--[=[
	debounce a existing function by timeout
	@class debounce
]=]

--[=[
	Provides a debounce function call on an operation

	@param timeoutInSeconds number
	@param func function
	@return (...) -> ()
	@function debounce
	@within debounce
]=]
local function debounce<T..., U...>(timeoutInSeconds: number, func: (T...) -> (U...)): (T...) -> ()
	assert(type(timeoutInSeconds) == "number", "Bad timeoutInSeconds")
	assert(type(func) == "function", "Bad func")

	local key = 1
	return function(...)
		key = key + 1
		local localKey = key
		local n = select("#", ...)
		local args = { ... }

		task.delay(timeoutInSeconds, function()
			if key == localKey then
				func((unpack :: any)(args, 1, n))
			end
		end)
	end
end

return debounce