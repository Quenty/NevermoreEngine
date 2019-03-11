--- Provide a variety of utility Table operations
-- @module Table

local lib = {}

--- Concats `target` with `source`
-- @tparam table target Table to append to
-- @tparam table source Table read from
-- @treturn table parameter table
function lib.Append(target, source)
	for _, value in pairs(source) do
		target[#target+1] = value
	end

	return target
end

--- Shallow merges two tables without modifying either
-- @tparam table orig original table
-- @tparam table new new table
-- @treturn table
function lib.Merge(orig, new)
	local tab = {}
	for key, val in pairs(orig) do
		tab[key] = val
	end
	for key, val in pairs(new) do
		tab[key] = val
	end
	return tab
end

--- Shallow merges two lists without modifying either
-- @tparam table orig original table
-- @tparam table new new table
-- @treturn table
function lib.MergeLists(orig, new)
	local tab = {}
	for _, val in pairs(orig) do
		table.insert(tab, val)
	end
	for _, val in pairs(new) do
		table.insert(tab, val)
	end
	return tab
end

--- Swaps keys with vvalues, overwriting additional values if duplicated
-- @tparam table orig original table
-- @treturn table
function lib.SwapKeyValue(orig)
	local tab = {}
	for key, val in pairs(orig) do
		tab[val] = key
	end
	return tab
end

--- Converts a table to a list
-- @tparam table tab Table to convert to a list
-- @treturn list
function lib.ToList(tab)
	local list = {}
	for _, item in pairs(tab) do
		table.insert(list, item)
	end
	return list
end

--- Counts the number of items in `tab`.
-- Useful since `__len` on table in Lua 5.2 returns just the array length.
-- @tparam table tab Table to count
-- @treturn number count
function lib.Count(tab)
	local count = 0
	for _, _ in pairs(tab) do
		count = count + 1
	end
	return count
end

--- Copies a table, but not deep.
-- @tparam table target Table to copy
-- @treturn table New table
function lib.Copy(target)
	local new = {}
	for key, value in pairs(target) do
		new[key] = value
	end
	return new
end

--- Deep copies a table including metatables
-- @function lib.DeepCopy
-- @tparam table table Table to deep copy
-- @treturn table New table
local function DeepCopy(target)
	if type(target) == "table" then
		local new = {}
		for index, value in pairs(target) do
			new[DeepCopy(index)] = DeepCopy(value)
		end
		return setmetatable(new, DeepCopy(getmetatable(target)))
	else
		return target
	end
end
lib.DeepCopy = DeepCopy

--- Overwrites a table's value
-- @function lib.DeepOverwrite
-- @tparam table target Target table
-- @tparam table source Table to read from
-- @treturn table target
local function DeepOverwrite(target, source)
	for index, value in pairs(source) do
		if type(target[index]) == "table" and type(value) == "table" then
			target[index] = DeepOverwrite(target[index], value)
		else
			target[index] = value
		end
	end
	return target
end
lib.DeepOverwrite = DeepOverwrite

--- Gets an index by value, returning `nil` if no index is found.
-- @tparam table haystack to search in
-- @param needle Value to search for
-- @return The index of the value, if found
-- @treturn nil if not found
function lib.GetIndex(haystack, needle)
	for index, item in pairs(haystack) do
		if needle == item then
			return index
		end
	end
	return nil
end

--- Recursively prints the table. Does not handle recursive tables.
-- @function lib.Stringify
-- @tparam table table Table to stringify
-- @tparam[opt=0] number indent Indent level
-- @tparam[opt=""] string output Output string, used recursively
-- @treturn string The table in string form
local function Stringify(table, indent, output)
	output = output or tostring(table)
	indent = indent or 0
	for Index, Value in pairs(table) do
		local FormattedText = "\n" .. string.rep("  ", indent) .. tostring(Index) .. ": "
		if type(Value) == "table" then
			output = output .. FormattedText
			output = Stringify(Value, Index + 1, output)
		else
			output = output .. FormattedText .. tostring(Value)
		end
	end
	return output
end
lib.Stringify = Stringify

--- Returns whether `value` is within `table`
-- @tparam table table to search in for value
-- @param value Value to search for
-- @treturn boolean `true` if within, `false` otherwise
function lib.Contains(table, value)
	for _, item in pairs(table) do
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
function lib.Overwrite(target, source)
	for index, item in pairs(source) do
		target[index] = item
	end

	return target
end

--- Sets a metatable on a table such that it errors when
-- indexing a nil value
-- @tparam table table Table to error on indexing
-- @treturn table table The same table
function lib.ReadOnly(table)
	return setmetatable(table, {
		__index = function(self, index)
			error(("Bad index %q"):format(tostring(index)), 2)
		end;
		__newindex = function(self, index, value)
			error(("Bad index %q"):format(tostring(index)), 2)
		end;
	})
end

--- Recursively sets the table as ReadOnly
-- @tparam table table Table to error on indexing
-- @treturn table table The same table
function lib.DeepReadOnly(table)
	for _, item in pairs(table) do
		if type(item) == "table" then
			lib.DeepReadOnly(item)
		end
	end

	return lib.ReadOnly(table)
end

return lib
