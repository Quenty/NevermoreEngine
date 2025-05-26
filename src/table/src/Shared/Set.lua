--!strict
--[=[
	Utility functions involving sets, which are tables with the key as an index, and the value as a
	truthy value.
	@class Set
]=]

export type Set<Key> = { [Key]: true }
export type Array<Value> = { [number]: Value }
export type Map<Key, Value> = { [Key]: Value }

local Set = {}

--[=[
	Unions the set with the other set, making a copy.
	@param set table
	@param otherSet table
	@return table
]=]
function Set.union<T, U>(set: Set<T>, otherSet: Set<U>): Set<T | U>
	local newSet: Set<T | U> = {}
	for key, _ in set do
		newSet[key] = true
	end
	for key, _ in otherSet do
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
function Set.unionUpdate<T>(set: Set<T>, otherSet: Set<T>)
	for key, _ in otherSet do
		set[key] = true
	end
end

--[=[
	Finds the set intersection betwen the two sets
	@param set table
	@param otherSet table
	@return table
]=]
function Set.intersection<T>(set: Set<T>, otherSet: Set<T>): Set<T>
	local newSet: Set<T> = {}
	for key, _ in set do
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
function Set.copy<T>(set: Set<T>): Set<T>
	local newSet: Set<T> = {}
	for key, _ in set do
		newSet[key] = true
	end
	return newSet
end

--[=[
	Counts the number of entries in the set (linear)
]=]
function Set.count<T>(set: Set<T>): number
	local count = 0
	for _, _ in set do
		count += 1
	end
	return count
end

--[=[
	Makes a new set from the given keys of a table
	@param tab table
	@return table
]=]
function Set.fromKeys<T>(tab: Map<T, any>): Set<T>
	local newSet: Set<T> = {}
	for key, _ in tab do
		newSet[key] = true
	end
	return newSet
end

--[=[
	Converts a set from table values.
	@param tab table
	@return table
]=]
function Set.fromTableValue<T>(tab: Map<any, T>): Set<T>
	local set: Set<T> = {}

	for _, value in tab do
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
function Set.toList<T>(set: { [T]: any }): Array<T>
	local list = {}

	for value, _ in set do
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
function Set.differenceUpdate<T>(set: Set<T>, otherSet: Set<T>)
	for value, _ in otherSet do
		set[value] = nil
	end
end

--[=[
	Computes the set difference between the two sets
	@param set table
	@param otherSet table
	@return table
]=]
function Set.difference<T>(set: Set<T>, otherSet: Set<T>): Set<T>
	local newSet: Set<T> = {}
	for key, _ in set do
		newSet[key] = true
	end
	for key, _ in otherSet do
		newSet[key] = nil
	end
	return newSet
end

return Set
