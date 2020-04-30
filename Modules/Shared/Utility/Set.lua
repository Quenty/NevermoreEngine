---
-- @module Set
-- @author Quenty

local Set = {}

function Set.fromTableValue(tab)
	local set = {}

	for _, value in pairs(tab) do
		set[value] = true
	end

	return set
end

Set.fromList = Set.fromTableValue

function Set.toList(set)
	local list = {}

	for value, _ in pairs(set) do
		table.insert(list, value)
	end

	return list
end

function Set.differenceUpdate(set, otherSet)
	for value, _ in pairs(otherSet) do
		set[value] = nil
	end
end

return Set