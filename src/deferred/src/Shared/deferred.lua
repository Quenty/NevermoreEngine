--!strict
--[=[
	An expensive way to spawn a function. However, unlike spawn(), it executes on the same frame, and
	unlike coroutines, does not obscure errors

	@deprecated 2.0.1
	@class deferred
]=]

return task.defer
