--- Utility functions for use with collection service tags
-- @module CollectionServiceUtils

local CollectionService = game:GetService("CollectionService")

local CollectionServiceUtils = {}

function CollectionServiceUtils.findFirstAncestor(tagName, child)
	assert(type(tagName) == "string")
	assert(typeof(child) == "Instance")

	local current = child.Parent
	while current do
		if CollectionService:HasTag(current, tagName) then
			return current
		end
		current = current.Parent
	end
	return nil
end

function CollectionServiceUtils.removeAllTags(instance)
	for _, tag in pairs(CollectionService:GetTags(instance)) do
		CollectionService:RemoveTag(instance, tag)
	end
end

return CollectionServiceUtils