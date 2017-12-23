local lib = {}

-- @author Quenty
-- Generic IsA interface for Lua classes.

local function IsA(self, ClassName)
	--- Using the .ClassName property, returns whether or not a component is
	--  a class

	assert(type(ClassName) == "string", "ClassName must be a string")
	
	local CurrentMetatable = getmetatable(self)
	while CurrentMetatable do
		if CurrentMetatable.ClassName == ClassName then
			return true
		end
		CurrentMetatable = getmetatable(CurrentMetatable)
	end
	
	return false
end

local function AddTo(Class)
	--- Adds the IsA function to a class and all descendants

	assert(not Class.IsA, "Class already has an IsA method")
	assert(not Class.CustomIsA, "Class already has an CustomIsA method")
	assert(Class.ClassName, "Class needs a ClassName")

	Class.IsA = IsA
	Class.CustomIsA = IsA
end
lib.AddTo = AddTo

return lib