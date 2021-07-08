--- Utility functions involving functions
-- @module FunctionUtils
-- @author Quenty

local FunctionUtils = {}

--- Binds the "self" variable to the function as the first argument
function FunctionUtils.bind(self, func)
	assert(type(self) == "table", "'self' must be a table")
	assert(type(func) == "function", "'func' must be a function")

	return function(...)
		return func(self, ...)
	end
end

return FunctionUtils