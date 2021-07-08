--- Utility methods for binders
-- @module BinderUtils

local CollectionService = game:GetService("CollectionService")

local BinderUtils = {}

function BinderUtils.findFirstAncestor(binder, child)
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

function BinderUtils.findFirstChild(binder, parent)
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

function BinderUtils.getChildren(binder, parent)
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

function BinderUtils.mapBinderListToTable(bindersList)
	assert(type(bindersList) == "table", "bindersList must be a table of binders")

	local tags = {}
	for _, binder in pairs(bindersList) do
		tags[binder:GetTag()] = binder
	end
	return tags
end

function BinderUtils.getMappedFromList(tagsMap, instanceList)
	local objects = {}

	for _, instance in pairs(instanceList) do
		for _, tag in pairs(CollectionService:GetTags(instance)) do
			local binder = tagsMap[tag]
			if binder then
				local obj = binder:Get(instance)
				if obj then
					table.insert(objects, obj)
				end
			end
		end
	end

	return objects
end

function BinderUtils.getChildrenOfBinders(bindersList, parent)
	assert(type(bindersList) == "table", "bindersList must be a table of binders")
	assert(typeof(parent) == "Instance", "Parent parameter must be instance")

	local tagsMap = BinderUtils.mapBinderListToTable(bindersList)
	return BinderUtils.getMappedFromList(tagsMap, parent:GetChildren())
end

function BinderUtils.getLinkedChildren(binder, linkName, parent)
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
					warn(("[BinderUtils.getLinkedChildren] - Double linked children at %q"):format(item:GetFullName()))
				end
			end
		end
	end
	return objects
end

function BinderUtils.getDescendants(binder, parent)
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


return BinderUtils