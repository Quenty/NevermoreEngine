--!strict
--[=[
	@class TypeUtils
]=]

local TypeUtils = {}

--[=[
	Type checking hack to convert a typed variable argument parameter to a type of any
	@param ... any
]=]
function TypeUtils.anyValue(...): ...any
	return ...
end

return TypeUtils
