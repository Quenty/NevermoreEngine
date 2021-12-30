--[=[
	Fixes an issue where you can't destroy already destroyed objects.
	@class safeDestroy
]=]

local PARENT_PROPERTY_LOCKED = "The Parent property of "

return function(instance)
	assert(typeof(instance) == "Instance", "Bad instance")

	xpcall(function()
		instance:Destroy()
	end, function(err)
		err = tostring(err)
		-- rip
		if err:sub(1, #PARENT_PROPERTY_LOCKED) ~= PARENT_PROPERTY_LOCKED then
			warn(("[safeDestroy] - %q"):format(err))
		end
	end)
end