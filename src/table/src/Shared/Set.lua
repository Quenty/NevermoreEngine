---
-- @module Set
-- @author Quenty

local Set = {}

function Set.union(set, otherSet)
	local newSet = {}
	for key, _ in pairs(set) do
		newSet[key] = true
	end
	for key, _ in pairs(otherSet) do
		newSet[key] = true
	end
	return newSet
end

function Set.unionUpdate(set, otherSet)
	for key, _ in pairs(otherSet) do
		set[key] = true
	end
end

function Set.intersection(set, otherSet)
	local newSet = {}
	for key, _ in pairs(set) do
		if otherSet[key] then
			newSet[key] = true
		end
	end
	return newSet
end

function Set.copy(set)
	local newSet = {}
	for key, _ in pairs(set) do
		newSet[key] = true
	end
	return newSet
end

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