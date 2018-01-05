--- Generic IsA interface for Lua classes.
-- @module IsAMixin

local module = {}
module.__index = module
setmetatable(module, module)

--- Using the .ClassName property, returns whether or not a component is
--  a class
function module:IsA(className)

	assert(type(className) == "string", "className must be a string")

	local CurrentMetatable = getmetatable(self)
	while CurrentMetatable do
		if CurrentMetatable.ClassName == className then
			return true
		end
		CurrentMetatable = getmetatable(CurrentMetatable)
	end

	return false
end

function module:__call(class)
	self:Add(class)
end

--- Adds the IsA function to a class and all descendants
function module:Add(class)
	assert(not class.IsA, "class already has an IsA method")
	assert(not class.CustomIsA, "class already has an CustomIsA method")
	assert(class.ClassName, "class needs a ClassName")

	class.IsA = self.IsA
	class.CustomIsA = self.IsA
end

return module