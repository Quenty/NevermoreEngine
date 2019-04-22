--- Utility methods for binders
-- @module BinderUtil

local BinderUtil = {}

function BinderUtil.findFirstAncestor(binder, child)
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

function BinderUtil.getChildren(binder, parent)
	assert(type(binder) == "table", "Binder must be binder")
	assert(typeof(parent) == "Instance", "Parent parameter must be instance")

	local objects = {}
	for _, item in pairs(parent:GetChildren()) do
		local obj = binder:Get(item)
		if obj then
			table.insert(objects, obj)
		end
	end
	return objects
end

return BinderUtil