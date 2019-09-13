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

function CollectionServiceUtils.findNearestPartWithTag(tagName, position)
	assert(type(tagName) == "string")
	assert(typeof(position) == "Vector3")

	local taggedInstances = CollectionService:GetTagged(tagName)
	local length = #taggedInstances
	if length > 0 then
		local currentDistance = math.huge
		local foundPart = nil

		for index = 1, length do
			local child = taggedInstances[index]
			if child:IsA("BasePart") then
				local magnitude = (child.Position - position).Magnitude
				if magnitude < currentDistance then
					currentDistance = magnitude
					foundPart = child
				end
			end
		end

		return foundPart
	else
		warn(("Nothing has the tag %s"):format(tagName))
		return nil
	end
end

return CollectionServiceUtils
