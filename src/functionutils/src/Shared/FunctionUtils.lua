--!strict
--[=[
	Utility functions involving functions
	@class FunctionUtils
]=]

local FunctionUtils = {}

--[=[
	Binds the "self" variable to the function as the first argument

	@param self table
	@param func function
	@return function
]=]
function FunctionUtils.bind<T, U..., V...>(self: T, func: (T, U...) -> V...): (U...) -> V...
	assert(type(self) == "table", "'self' must be a table")
	assert(type(func) == "function", "'func' must be a function")

	return function(...: U...): V...
		return (func :: any)(self, ...)
	end
end

return FunctionUtils