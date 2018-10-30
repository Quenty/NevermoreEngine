--- An expensive way to spawn a function. However, unlike spawn(), it executes on the same frame, and
-- unlike coroutines, does not obscure errors
-- @module fastSpawn
local inst = Instance.new

return function(func, ...)
	local bindable = inst("BindableEvent")
	if ... ~= nil then
		local args = {...}
		bindable.Event:Connect(function()
			func(unpack(args))
		end)
	else
		bindable.Event:Connect(func)
	end
	
	bindable:Fire()
	bindable:Destroy()
end
