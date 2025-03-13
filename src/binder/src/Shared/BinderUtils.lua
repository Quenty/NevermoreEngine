--[=[
	Utility methods for the binder object.
	@class BinderUtils
]=]

local CollectionService = game:GetService("CollectionService")

local BinderUtils = {}

--[=[
	Finds the first ancestor that is bound with the current child.
	Skips the child class, of course.

	@param binder Binder<T>
	@param child Instance
	@return T?
]=]
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

--[=[
	Finds the first child bound with the given binder and returns
	the bound class.

	@param binder Binder<T>
	@param parent Instance
	@return T?
]=]
function BinderUtils.findFirstChild(binder, parent)
	assert(type(binder) == "table", "Binder must be binder")
	assert(typeof(parent) == "Instance", "Parent parameter must be instance")

	for _, child in parent:GetChildren() do
		local class = binder:Get(child)
		if class then
			return class
		end
	end

	return nil
end

--[=[
	Gets all bound children of the given binder for the parent.

	@param binder Binder<T>
	@param parent Instance
	@return {T}
]=]
function BinderUtils.getChildren(binder, parent)
	assert(type(binder) == "table", "Binder must be binder")
	assert(typeof(parent) == "Instance", "Parent parameter must be instance")

	local objects = {}
	for _, item in parent:GetChildren() do
		local obj = binder:Get(item)
		if obj then
			table.insert(objects, obj)
		end
	end
	return objects
end

--[=[
	Maps a list of binders into a look up table where the keys are
	tags and the value is the binder.

	Duplicates are overwritten by the last entry.

	@param bindersList { Binder<any> }
	@return { [string]: Binder<any> }
]=]
function BinderUtils.mapBinderListToTable(bindersList)
	assert(type(bindersList) == "table", "bindersList must be a table of binders")

	local tags = {}
	for _, binder in bindersList do
		tags[binder:GetTag()] = binder
	end
	return tags
end

--[=[
	Given a mapping of tags to binders, retrieves the bound values
	from an instanceList by quering the list of :GetTags() instead
	of iterating over each binder.

	This lookup should be faster when there are potentially many
	interaction points for a given tag map, but the actual bound
	list should be low.

	@param tagsMap { [string]: Binder<T> }
	@param instanceList { Instance }
	@return { T }
]=]
function BinderUtils.getMappedFromList(tagsMap, instanceList)
	local objects = {}

	for _, instance in instanceList do
		for _, tag in CollectionService:GetTags(instance) do
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

--[=[
	Given a list of binders retrieves all children bound with the given value.

	@param bindersList { Binder<T> }
	@param parent Instance
	@return { T }
]=]
function BinderUtils.getChildrenOfBinders(bindersList, parent)
	assert(type(bindersList) == "table", "bindersList must be a table of binders")
	assert(typeof(parent) == "Instance", "Parent parameter must be instance")

	local tagsMap = BinderUtils.mapBinderListToTable(bindersList)
	return BinderUtils.getMappedFromList(tagsMap, parent:GetChildren())
end

--[=[
	Gets all the linked (via objectValues of name `linkName`) bound objects

	@param binder Binder<T>
	@param linkName string -- Name of the object values required
	@param parent Instance
	@return {T}
]=]
function BinderUtils.getLinkedChildren(binder, linkName, parent)
	local seen = {}
	local objects = {}
	for _, item in parent:GetChildren() do
		if item.Name == linkName and item:IsA("ObjectValue") and item.Value then
			local obj = binder:Get(item.Value)
			if obj then
				if not seen[obj] then
					seen[obj] = true
					table.insert(objects, obj)
				else
					warn(
						string.format(
							"[BinderUtils.getLinkedChildren] - Double linked children at %q",
							item:GetFullName()
						)
					)
				end
			end
		end
	end
	return objects
end

--[=[
	Gets all bound descendants of the given binder for the parent.

	@param binder Binder<T>
	@param parent Instance
	@return {T}
]=]
function BinderUtils.getDescendants(binder, parent)
	assert(type(binder) == "table", "Binder must be binder")
	assert(typeof(parent) == "Instance", "Parent parameter must be instance")

	local objects = {}
	for _, item in parent:GetDescendants() do
		local obj = binder:Get(item)
		if obj then
			table.insert(objects, obj)
		end
	end
	return objects
end


return BinderUtils