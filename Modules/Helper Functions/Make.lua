local Load = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))
local Modify = Load("Modify")

local function Make(ClassType, Properties, ...)
	--- Creates Instance(s) for you!
	-- @param ClassType The type of class to instantiate
	-- @param Properties The properties to use
	-- @returns object of ClassType with Properties
	-- @param {...} if used, @returns an object for each subsequent table that is a modification to Properties
	-- 	Used for creating a custom "default" list of properties so you don't need to rewrite the same properties over and over.
	local objects = {...}
	local numObjects = #objects
	if numObjects == 0 then
		return Modify(Instance.new(ClassType), Properties)
	else
		for a = 1, numObjects do
			objects[a] = Modify(Modify(Instance.new(ClassType), Properties), objects[a])
		end
		return unpack(objects)
	end
end

return Make
