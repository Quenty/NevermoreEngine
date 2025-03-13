--!strict
--[=[
	Fixes an issue where you can't destroy already destroyed objects.
	@class safeDestroy
]=]

local PARENT_PROPERTY_LOCKED = "The Parent property of "

return function(instance: Instance)
	assert(typeof(instance) == "Instance", "Bad instance")

	xpcall(function()
		instance:Destroy()
	end, function(err)
		err = tostring(err)
		-- rip
		if string.sub(err, 1, #PARENT_PROPERTY_LOCKED) ~= PARENT_PROPERTY_LOCKED then
			warn(string.format("[safeDestroy] - %q", err))
		end
	end)
end