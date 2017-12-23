return function(func, ...)
	assert(type(func) == "function")

	local args = {...}
	local bindable = Instance.new("BindableEvent")
	bindable.Event:Connect(function()
		func(unpack(args))
	end)
	
	bindable:Fire(...)
	bindable:Destroy()
end