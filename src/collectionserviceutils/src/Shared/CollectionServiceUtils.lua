--!strict
--[=[
	Utility functions for use with collection service tags
	@class CollectionServiceUtils
]=]

local CollectionService = game:GetService("CollectionService")

local CollectionServiceUtils = {}

--[=[
	Finds the first ancestor with the given tagName.
	@param tagName string
	@param child Instance
	@return Instance?
]=]
function CollectionServiceUtils.findFirstAncestor(tagName: string, child: Instance): Instance?
	assert(type(tagName) == "string", "Bad tagName")
	assert(typeof(child) == "Instance", "Bad child")

	local current = child.Parent
	while current do
		if CollectionService:HasTag(current, tagName) then
			return current
		end
		current = current.Parent
	end
	return nil
end

--[=[
	Finds the child with the tag name, or the first ancestor with the given tagName.

	@param tagName string
	@param child Instance
	@return Instance?
]=]
function CollectionServiceUtils.findInstanceOrFirstAncestor(tagName: string, child: Instance): Instance?
	assert(type(tagName) == "string", "Bad tagName")
	assert(typeof(child) == "Instance", "Bad child")

	if CollectionService:HasTag(child, tagName) then
		return child
	end

	return CollectionServiceUtils.findFirstAncestor(tagName, child)
end

--[=[
	Removes all tags from an instance.
	@param instance Instance
]=]
function CollectionServiceUtils.removeAllTags(instance: Instance)
	assert(typeof(instance) == "Instance", "Bad instance")

	for _, tag in CollectionService:GetTags(instance) do
		CollectionService:RemoveTag(instance, tag)
	end
end

return CollectionServiceUtils
