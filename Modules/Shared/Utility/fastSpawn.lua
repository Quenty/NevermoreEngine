--- An expensive way to spawn a function. However, unlike spawn(), it executes on the same frame, and
-- unlike coroutines, does not obscure errors
-- @module fastSpawn

return function(func, ...)
	assert(type(func) == "function")

	local args = {...}
	local count = select("#", ...)

	local bindable = Instance.new("BindableEvent")
	bindable.Event:Connect(function()
		func(unpack(args, 1, count))
	end)

	bindable:Fire()
	bindable:Destroy()
end