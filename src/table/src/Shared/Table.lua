--- Provide a variety of utility Table operations
-- @module Table

local Table = {}

--- Concats `target` with `source`
-- @tparam table target Table to append to
-- @tparam table source Table read from
-- @treturn table parameter table
function Table.append(target, source)
	for _, value in pairs(source) do
		target[#target+1] = value
	end

	return target
end

--- Shallow merges two tables without modifying either
-- @tparam table orig original table
-- @tparam table new new table
-- @treturn table
function Table.merge(orig, new)
	local _table = {}
	for key, val in pairs(orig) do
		_table[key] = val
	end
	for key, val in pairs(new) do
		_table[key] = val
	end
	return _table
end

function Table.values(_table)
	local new = {}
	for _, val in pairs(_table) do
		table.insert(new, val)
	end
	return new
end

--- Shallow merges two lists without modifying either
-- @tparam table orig original table
-- @tparam table new new table
-- @treturn table
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

--- Swaps keys with values, overwriting additional values if duplicated
-- @tparam table orig original table
-- @treturn table
function Table.swapKeyValue(orig)
	local tab = {}
	for key, val in pairs(orig) do
		tab[val] = key
	end
	return tab
end

--- Converts a table to a list
-- @tparam table tab Table to convert to a list
-- @treturn list
function Table.toList(_table)
	local list = {}
	for _, item in pairs(_table) do
		table.insert(list, item)
	end
	return list
end

--- Counts the number of items in `_table`.
-- Useful since `__len` on table in Lua 5.2 returns just the array length.
-- @tparam table _table Table to count
-- @treturn number count
function Table.count(_table)
	local count = 0
	for _, _ in pairs(_table) do
		count = count + 1
	end
	return count
end

--- Copies a table, but not deep.
-- @tparam table target Table to copy
-- @treturn table New table
function Table.copy(target)
	local new = {}
	for key, value in pairs(target) do
		new[key] = value
	end
	return new
end

--- Deep copies a table including metatables
-- @function Table.deepCopy
-- @tparam table table Table to deep copy
-- @treturn table New table
local function deepCopy(target, _context)
	_context = _context or  {}
	if _context[target] then
		return _context[target]
	end

	if type(target) == "table" then
		local new = {}
		_context[target] = new
		for index, value in pairs(target) do
			new[deepCopy(index, _context)] = deepCopy(value, _context)
		end
		return setmetatable(new, deepCopy(getmetatable(target), _context))
	else
		return target
	end
end
Table.deepCopy = deepCopy

--- Overwrites a table's value
-- @function Table.deepOverwrite
-- @tparam table target Target table
-- @tparam table source Table to read from
-- @treturn table target
local function deepOverwrite(target, source)
	for index, value in pairs(source) do
		if type(target[index]) == "table" and type(value) == "table" then
			target[index] = deepOverwrite(target[index], value)
		else
			target[index] = value
		end
	end
	return target
end
Table.deepOverwrite = deepOverwrite

--- Gets an index by value, returning `nil` if no index is found.
-- @tparam table haystack to search in
-- @param needle Value to search for
-- @return The index of the value, if found
-- @treturn nil if not found
function Table.getIndex(haystack, needle)
	assert(needle ~= nil, "Needle cannot be nil")

	for index, item in pairs(haystack) do
		if needle == item then
			return index
		end
	end
	return nil
end

--- Recursively prints the table. Does not handle recursive tables.
-- @function Table.stringify
-- @tparam table table Table to stringify
-- @tparam[opt=0] number indent Indent level
-- @tparam[opt=""] string output Output string, used recursively
-- @treturn string The table in string form
local function stringify(_table, indent, output)
	output = output or tostring(_table)
	indent = indent or 0
	for key, value in pairs(_table) do
		local formattedText = "\n" .. string.rep("  ", indent) .. tostring(key) .. ": "
		if type(value) == "table" then
			output = output .. formattedText
			output = stringify(value, indent + 1, output)
		else
			output = output .. formattedText .. tostring(value)
		end
	end
	return output
end
Table.stringify = stringify

--- Returns whether `value` is within `table`
-- @tparam table table to search in for value
-- @param value Value to search for
-- @treturn boolean `true` if within, `false` otherwise
function Table.contains(_table, value)
	for _, item in pairs(_table) do
		if item == value then
			return true
		end
	end

	return false
end

--- Overwrites an existing table
-- @tparam table target Table to overwite
-- @tparam table source Source table to read from
-- @treturn table target
function Table.overwrite(target, source)
	for index, item in pairs(source) do
		target[index] = item
	end

	return target
end

function Table.take(_table, count)
	local newTable = {}
	for i=1, math.min(#_table, count) do
		newTable[i] = _table[i]
	end
	return newTable
end

local function errorOnIndex(self, index)
	error(("Bad index %q"):format(tostring(index)), 2)
end

local READ_ONLY_METATABLE = {
	__index = errorOnIndex;
	__newindex = errorOnIndex;
}

--- Sets a metatable on a table such that it errors when
-- indexing a nil value
-- @tparam table _table Table to error on indexing
-- @treturn table _table The same table
function Table.readonly(_table)
	return setmetatable(_table, READ_ONLY_METATABLE)
end

--- Recursively sets the table as ReadOnly
-- @tparam table table Table to error on indexing
-- @treturn table table The same table
function Table.deepReadonly(table)
	for _, item in pairs(table) do
		if type(item) == "table" then
			Table.deepReadonly(item)
		end
	end

	return Table.readonly(table)
end

return Table
