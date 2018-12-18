--- Utility methods for binders
-- @module BinderUtil

local BinderUtil = {}

function BinderUtil.FindFirstAncestor(binder, child)
	assert(binder)
	assert(typeof(child) == "Instance")

	local current = child.Parent
	while current do
		local class = binder:Get(current)
		if class then
			return class
		end
		current = current.Parent
	end
	return nil
end

return BinderUtil