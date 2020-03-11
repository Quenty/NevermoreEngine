--- Utility methods for binders
-- @module BinderUtilss

local BinderUtilss = {}

function BinderUtilss.findFirstAncestor(binder, child)
	assert(type(binder) == "table", "Binder must be binder")
	assert(typeof(child) == "Instance", "Child parameter must be instance")

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

function BinderUtilss.findFirstChild(binder, parent)
	assert(type(binder) == "table", "Binder must be binder")
	assert(typeof(parent) == "Instance", "Parent parameter must be instance")

	for _, child in pairs(parent:GetChildren()) do
		local class = binder:Get(child)
		if class then
			return class
		end
	end

	return nil
end

function BinderUtilss.getChildren(binder, parent)
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

function BinderUtilss.getChildrenOfBinders(binders, parent)
	assert(type(binders) == "table", "binders must be binder")
	assert(typeof(parent) == "Instance", "Parent parameter must be instance")

	local objects = {}
	for _, item in pairs(parent:GetChildren()) do
		for _, binder in pairs(binders) do
			local obj = binder:Get(item)
			if obj then
				table.insert(objects, obj)
			end
		end
	end
	return objects
end

function BinderUtilss.getLinkedChildren(binder, linkName, parent)
	local seen = {}
	local objects = {}
	for _, item in pairs(parent:GetChildren()) do
		if item.Name == linkName and item:IsA("ObjectValue") and item.Value then
			local obj = binder:Get(item.Value)
			if obj then
				if not seen[obj] then
					seen[obj] = true
					table.insert(objects, obj)
				else
					warn(("[BinderUtilss.getLinkedChildren] - Double linked children at %q"):format(item:GetFullName()))
				end
			end
		end
	end
	return objects
end

function BinderUtilss.getDescendants(binder, parent)
	assert(type(binder) == "table", "Binder must be binder")
	assert(typeof(parent) == "Instance", "Parent parameter must be instance")

	local objects = {}
	for _, item in pairs(parent:GetDescendants()) do
		local obj = binder:Get(item)
		if obj then
			table.insert(objects, obj)
		end
	end
	return objects
end


return BinderUtilss