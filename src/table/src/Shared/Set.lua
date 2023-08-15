--[=[
	Utility functions involving sets, which are tables with the key as an index, and the value as a
	truthy value.
	@class Set
]=]

local Set = {}

--[=[
	Unions the set with the other set, making a copy.
	@param set table
	@param otherSet table
	@return table
]=]
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

--[=[
	Unions the set with the other set, updating the `set`
	@param set table
	@param otherSet table
	@return table
]=]
function Set.unionUpdate(set, otherSet)
	for key, _ in pairs(otherSet) do
		set[key] = true
	end
end

--[=[
	Finds the set intersection betwen the two sets
	@param set table
	@param otherSet table
	@return table
]=]
function Set.intersection(set, otherSet)
	local newSet = {}
	for key, _ in pairs(set) do
		if otherSet[key] ~= nil then
			newSet[key] = true
		end
	end
	return newSet
end

--[=[
	Makes a copy of the set, making the values as true.
	@param set table
	@return table
]=]
function Set.copy(set)
	local newSet = {}
	for key, _ in pairs(set) do
		newSet[key] = true
	end
	return newSet
end

--[=[
	Makes a new set from the given keys of a table
	@param tab table
	@return table
]=]
function Set.fromKeys(tab)
	local newSet = {}
	for key, _ in pairs(tab) do
		newSet[key] = true
	end
	return newSet
end

--[=[
	Converts a set from table values.
	@param tab table
	@return table
]=]
function Set.fromTableValue(tab)
	local set = {}

	for _, value in pairs(tab) do
		set[value] = true
	end

	return set
end

--[=[
	Converts a set from a list
	@function fromList
	@param tab table
	@return table
	@within Set
]=]
Set.fromList = Set.fromTableValue

--[=[
	Converts a set to a list
	@param set table
	@return table
]=]
function Set.toList(set)
	local list = {}

	for value, _ in pairs(set) do
		table.insert(list, value)
	end

	return list
end

--[=[
	Converts a set to a list
	@param set table
	@param otherSet table
	@return table
]=]
function Set.differenceUpdate(set, otherSet)
	for value, _ in pairs(otherSet) do
		set[value] = nil
	end
end

--[=[
	Computes the set difference between the two sets
	@param set table
	@param otherSet table
	@return table
]=]
function Set.difference(set, otherSet)
	local newSet = {}
	for key, _ in pairs(set) do
		newSet[key] = true
	end
	for key, _ in pairs(otherSet) do
		newSet[key] = nil
	end
	return newSet
end


return Set