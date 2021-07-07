--- An expensive way to spawn a function. However, unlike spawn(), it executes on the same frame, and
-- unlike coroutines, does not obscure errors
-- @module deferred

return function(func, ...)
	assert(type(func) == "function")

	local args = table.pack(...)

	local bindable = Instance.new("BindableEvent")
	bindable.Event:Connect(function()
		bindable:Destroy()
		func(table.unpack(args))
	end)
	bindable:Fire()
end