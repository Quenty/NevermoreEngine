--[=[
	Provide a variety of utility table operations
	@class Table
]=]

local Table = {}

--[=[
	Concats `subject` with `source` in pairs order. The `subject` will be mutated.

	@param subject table -- Table to mutate / append to
	@param source table -- Table to read from
	@return table -- parameter table
]=]
function Table.append(subject: table, source: table): table
	for _, value in pairs(source) do
		subject[#subject + 1] = value
	end

	return subject
end

--[=[
	Shallow merges two tables without modifying either.

	@param tableA table -- Input table
	@param tableB table -- Input table
	@return table -- New, merged table
]=]
function Table.merge(tableA: table, tableB: table): table
	local result = {}
	for key, val in pairs(tableA) do
		result[key] = val
	end
	for key, val in pairs(tableB) do
		result[key] = val
	end
	return result
end

--[=[
	Reverses the list and returns the reversed copy

	@param orig table -- Original table
	@return table -- New, reversed table
]=]
function Table.reverse(orig: table): table
	local len = #orig
	local new = table.create(#orig)
	for i = len, 1, -1 do
		new[1 + len - i] = orig[i]
	end
	return new
end

--[=[
	Returns a list of all of the values that a table has.

	@param source table -- Table source to extract values from
	@return table -- A list with all the values the table has
]=]
function Table.values(source: table): table
	local new = {}
	for _, val in pairs(source) do
		table.insert(new, val)
	end
	return new
end

--[=[
	Returns a list of all of the keys that a table has. (In order of pairs)

	@param source table -- Table source to extract keys from
	@return table -- A list of the keys in the given table
]=]
function Table.keys(source: table): table
	local new = {}
	for key, _ in pairs(source) do
		table.insert(new, key)
	end
	return new
end

--[=[
	Shallow merges two lists without modifying either.

	@param tableA table -- Input table
	@param tableB table -- Input table
	@return table -- New, merged table
]=]
function Table.mergeLists(tableA: table, tableB: table): table
	local lenA = #tableA
	local lenB = #tableB

	local _table = table.create(lenA + lenB)
	table.move(tableA, 1, lenA, 1, _table)
	table.move(tableB, 1, lenB, lenA + 1, _table)

	return _table
end

--[=[
	Swaps keys with values, overwriting additional values if duplicated.

	@param orig table -- Original table
	@return table -- New table
]=]
function Table.swapKeyValue(orig: table): table
	local tab = table.create(#orig)
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
function Table.toList(_table: table): table
	local list = {}
	for _, item in pairs(_table) do
		table.insert(list, item)
	end
	return list
end

--[=[
	Counts the number of items in `_table`, including numeric and string keys.
	Useful since `__len` on table in Lua 5.2 returns just the array length.

	@param _table table -- Table to count
	@return number -- count
]=]
function Table.count(_table: table): number
	local count = 0
	for _, _ in pairs(_table) do
		count = count + 1
	end
	return count
end

--[=[
	Shallow copies a table from target into a new table

	@param target table -- Table to copy
	@return table -- Result
]=]
function Table.copy(target: table): table
	local new = table.create(#target)
	for key, value in pairs(target) do
		new[key] = value
	end
	return new
end

--[=[
	Deep copies a table including metatables

	@param target table -- Table to deep copy
	@param _context table? -- Cntext to deepCopy the value in
	@return table -- Result
]=]
function Table.deepCopy(target: table, _context: table): table
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
	@return table -- The 'target' table (now mutated)
]=]
function Table.deepOverwrite(target: table, source: table): table
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
	@param needle any -- Value to search for
	@return number -- The index of the value, if found
	@return nil -- if not found
]=]
function Table.getIndex(haystack: table, needle: any)
	assert(needle ~= nil, "Needle cannot be nil")

	-- Note: table.find cannot be used; currently it only works on array-style tables.

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
function Table.stringify(_table: table, indent: number?, output: string?): boolean
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
function Table.contains(_table: table, value: any): boolean
	return Table.getIndex(_table, value) ~= nil
end

--[=[
	Overwrites an existing table with the source values.

	@param target table -- Table to overwite
	@param source table -- Source table to read from
	@return table -- target
]=]
function Table.overwrite(target: table, source: table): table
	for index, item in pairs(source) do
		target[index] = item
	end

	return target
end

--[=[
	Takes `count` entries from the given array-style table. If the table does not have
	that many entries, will return up to the number the table has to
	provide.

	@param source table -- Source array-style table to retrieve values from
	@param count number -- Number of entries to take
	@return table -- List with the entries retrieved
]=]
function Table.take(source: table, count: number): table
	local newTable = table.create(math.max(0, math.min(#source, count)))
	table.move(source, 1, count, 1, newTable)
	return newTable
end

local function errorOnIndex(_, index)
	error(("Bad index %q"):format(tostring(index)), 2)
end

local READ_ONLY_METATABLE = {
	__index = errorOnIndex;
	__newindex = errorOnIndex;
}

--[=[
	Sets a metatable on a table such that it errors when
	indexing a nil value

	@ignore
	@param target table -- Table to error on indexing
	@return table -- The same table, with the metatable set to readonly
]=]
function Table.readonly(target)
	return setmetatable(target, READ_ONLY_METATABLE)
end

--[=[
	Recursively sets the table as ReadOnly

	@ignore
	@param target table -- Table to error on indexing
	@return table -- The same table
]=]
function Table.deepReadonly(target: table): table
	for _, item in pairs(target) do
		if type(item) == "table" then
			Table.deepReadonly(item)
		end
	end

	return Table.readonly(target)
end

--[=[
	Guards a table, ensuring that it has no malformed reads/writes.
	Writing a value or indexing nil will throw an error.

	@method shallowStrictAccess
	@within Table
	@param target table -- Table to guard
	@return table -- The same table, with the metatable set to readonly
]=]
Table.shallowStrictAccess = Table.readonly

--[=[
	Recursively sets the table as guarded.

	@method deepStrictAccess
	@within Table
	@param target table -- Table to guard
	@return table -- The same table, with the metatable set to readonly
]=]
Table.deepStrictAccess = Table.deepReadonly

return Table
