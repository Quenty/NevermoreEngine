local function Debounce(timeout, func)
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

return Debounce