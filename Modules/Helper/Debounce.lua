local function Debounce(func)
	--- Debounces a function such that it will not run when called if it is already running
	-- @param func The function to debounce

	local isRunning = false
	return function(...)
		if not isRunning then
			isRunning = true
			func(...)
			isRunning = false
		end
	end
end

return Debounce
