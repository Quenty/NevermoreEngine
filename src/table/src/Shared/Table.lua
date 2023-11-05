--[=[
	Provide a variety of utility table operations
	@class Table
]=]

local Table = {}

--[=[
	Concats `target` with `source`.

	@param target table -- Table to append to
	@param source table -- Table read from
	@return table -- parameter table
]=]
function Table.append(target, source)
	for _, value in pairs(source) do
		target[#target+1] = value
	end

	return target
end

--[=[
	Shallow merges two tables without modifying either.

	@param orig table -- Original table
	@param new table -- Result
	@return table
]=]
function Table.merge(orig, new)
	local result = table.clone(orig)
	for key, val in pairs(new) do
		result[key] = val
	end
	return result
end

--[=[
	Reverses the list and returns the reversed copy

	@param orig table -- Original table
	@return table
]=]
function Table.reverse(orig)
	local new = {}
	for i=#orig, 1, -1 do
		table.insert(new, orig[i])
	end
	return new
end

--[=[
	Returns a list of all of the values that a table has.

	@param source table -- Table source to extract values from
	@return table -- A list with all the values the table has
]=]
function Table.values(source)
	local new = {}
	for _, val in pairs(source) do
		table.insert(new, val)
	end
	return new
end

--[=[
	Returns a list of all of the keys that a table has. (In order of pairs)

	@param source table -- Table source to extract keys from
	@return table -- A list with all the keys the table has
]=]
function Table.keys(source)
	local new = {}
	for key, _ in pairs(source) do
		table.insert(new, key)
	end
	return new
end

--[=[
	Shallow merges two lists without modifying either.

	@param orig table -- Original table
	@param new table -- Result
	@return table
]=]
function Table.mergeLists(orig, new)
	local _table = {}
	for _, val in pairs(orig) do
		table.insert(_table, val)
	end
	for _, val in pairs(new) do
		table.insert(_table, val)
	end
	return _table
end

--[=[
	Swaps keys with values, overwriting additional values if duplicated.

	@param orig table -- Original table
	@return table
]=]
function Table.swapKeyValue(orig)
	local tab = {}
	for key, val in pairs(orig) do
		tab[val] = key
	end
	return tab
end

--[=[
	Converts a table to a list.

	@param _table table -- Table to convert to a list
	@return table
]=]
function Table.toList(_table)
	local list = {}
	for _, item in pairs(_table) do
		table.insert(list, item)
	end
	return list
end

--[=[
	Counts the number of items in `_table`.
	Useful since `__len` on table in Lua 5.2 returns just the array length.

	@param _table table -- Table to count
	@return number -- count
]=]
function Table.count(_table)
	local count = 0
	for _, _ in pairs(_table) do
		count = count + 1
	end
	return count
end

--[=[
	Shallow copies a table from target into a new table

	@function Table.copy
	@param target table -- Table to copy
	@return table -- Result
	@within Table
]=]
Table.copy = table.clone

--[=[
	Deep copies a table including metatables

	@param target table -- Table to deep copy
	@param _context table? -- Context to deepCopy the value in
	@return table -- Result
]=]
function Table.deepCopy(target, _context)
	_context = _context or {}
	if _context[target] then
		return _context[target]
	end

	if type(target) == "table" then
		local new = {}
		_context[target] = new
		for index, value in pairs(target) do
			new[Table.deepCopy(index, _context)] = Table.deepCopy(value, _context)
		end
		return setmetatable(new, Table.deepCopy(getmetatable(target), _context))
	else
		return target
	end
end

--[=[
	Overwrites a table's value
	@param target table -- Target table
	@param source table -- Table to read from
	@return table -- target
]=]
function Table.deepOverwrite(target, source)
	for index, value in pairs(source) do
		if type(target[index]) == "table" and type(value) == "table" then
			target[index] = Table.deepOverwrite(target[index], value)
		else
			target[index] = value
		end
	end
	return target
end

--[=[
	Gets an index by value, returning `nil` if no index is found.
	@param haystack table -- To search in
	@param needle Value to search for
	@return The index of the value, if found
	@return nil -- if not found
]=]
function Table.getIndex(haystack, needle)
	assert(needle ~= nil, "Needle cannot be nil")

	for index, item in pairs(haystack) do
		if needle == item then
			return index
		end
	end
	return nil
end

--[=[
	Recursively prints the table. Does not handle recursive tables.

	@param _table table -- Table to stringify
	@param indent number? -- Indent level
	@param output string? -- Output string, used recursively
	@return string -- The table in string form
]=]
function Table.stringify(_table, indent, output)
	output = output or tostring(_table)
	indent = indent or 0
	for key, value in pairs(_table) do
		local formattedText = "\n" .. string.rep("  ", indent) .. tostring(key) .. ": "
		if type(value) == "table" then
			output = output .. formattedText
			output = Table.stringify(value, indent + 1, output)
		else
			output = output .. formattedText .. tostring(value)
		end
	end
	return output
end

--[=[
	Returns whether `value` is within `table`

	@param _table table -- To search in for value
	@param value any -- Value to search for
	@return boolean -- `true` if within, `false` otherwise
]=]
function Table.contains(_table, value)
	for _, item in pairs(_table) do
		if item == value then
			return true
		end
	end

	return false
end

--[=[
	Overwrites an existing table with the source values.

	@param target table -- Table to overwite
	@param source table -- Source table to read from
	@return table -- target
]=]
function Table.overwrite(target, source)
	for index, item in pairs(source) do
		target[index] = item
	end

	return target
end

--[=[
	Deep equivalent comparison of a table assuming keys are indexable in the same way.

	@param target table -- Table to check
	@param source table -- Other table to check
	@return boolean
]=]
function Table.deepEquivalent(target, source)
	if target == source then
		return true
	end

	if type(target) ~= type(source) then
		return false
	end

	if type(target) == "table" then
		for key, value in pairs(target) do
			if not Table.deepEquivalent(value, source[key]) then
				return false
			end
		end

		for key, value in pairs(source) do
			if not Table.deepEquivalent(value, target[key]) then
				return false
			end
		end

		return true
	else
		-- target == source should do it.
		return false
	end
end

--[=[
	Takes `count` entries from the table. If the table does not have
	that many entries, will return up to the number the table has to
	provide.

	@param source table -- Source table to retrieve values from
	@param count number -- Number of entries to take
	@return table -- List with the entries retrieved
]=]
function Table.take(source, count)
	local newTable = {}
	for i=1, math.min(#source, count) do
		newTable[i] = source[i]
	end
	return newTable
end

local function errorOnIndex(_, index)
	error(string.format("Bad index %q", tostring(index)), 2)
end

local READ_ONLY_METATABLE = {
	__index = errorOnIndex;
	__newindex = errorOnIndex;
}

--[=[
	Sets a metatable on a table such that it errors when
	indexing a nil value

	@param target table -- Table to error on indexing
	@return table -- The same table, with the metatable set to readonly
]=]
function Table.readonly(target)
	return setmetatable(target, READ_ONLY_METATABLE)
end

--[=[
	Recursively sets the table as ReadOnly

	@param target table -- Table to error on indexing
	@return table -- The same table
]=]
function Table.deepReadonly(target)
	for _, item in pairs(target) do
		if type(item) == "table" then
			Table.deepReadonly(item)
		end
	end

	return Table.readonly(target)
end

return Table
