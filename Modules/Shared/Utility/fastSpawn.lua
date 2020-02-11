--- An expensive way to spawn a function. However, unlike spawn(), it executes on the same frame, and
-- unlike coroutines, does not obscure errors
-- @module fastSpawn
local bindable = Instance.new('BindableEvent')

bindable.Event:Connect(function(func, ...) func(...) end)

return function(func, ...)
	assert(type(func) == 'function')

	bindable:Fire(func, ...)
end
