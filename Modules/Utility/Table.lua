--- Provide a variety of utility Table operations
-- @module Table

local lib = {}

--- Concats `Table` with `NewTable`
function lib.Append(Table, NewTable)
	for _, Item in pairs(NewTable) do
		Table[#Table+1] = Item
	end

	return Table
end

--- Counts the number of items in the table.
-- Useful since #table in Lua 5.2 returns just the array part
-- @tparam table Table
-- @treturn number Count
function lib.Count(Table)
	local Count = 0;
	for _, _ in pairs(Table) do
		Count = Count + 1
	end
	return Count
end

function lib.Copy(Table)
	local NewTable = {}
	for Key, Value in pairs(Table) do
		NewTable[Key] = Value
	end
	return NewTable
end

local function DeepCopy(Table)
	if type(Table) == "table" then
		local NewTable = {}
		for Index, Value in pairs(Table) do
			NewTable[DeepCopy(Index)] = DeepCopy(Value)
		end
		return setmetatable(NewTable, DeepCopy(getmetatable(Table)))
	else
		return Table
	end
end
lib.DeepCopy = DeepCopy

local function DeepOverwrite(Table, NewTable)
	for Index, Value in pairs(NewTable) do
		if type(Table[Index]) == "table" and type(Value) == "table" then
			Table[Index] = DeepOverwrite(Table[Index], Value)
		else
			Table[Index] = Value
		end
	end

	return Table
end
lib.DeepOverwrite = DeepOverwrite

function lib.GetIndexByValue(Table, Value)
	for Index, TableValue in pairs(Table) do
		if Value == TableValue then
			return Index
		end
	end
	return nil
end

--- Recursively prints the table
local function GetStringTable(Table, Indent, PrintValue)
	PrintValue = PrintValue or tostring(Table)
	Indent = Indent or 0
	for Index, Value in pairs(Table) do
		local FormattedText = "\n" .. string.rep("  ", Indent) .. tostring(Index) .. ": "
		if type(Value) == "table" then
			PrintValue = PrintValue .. FormattedText
			PrintValue = GetStringTable(Value, Index + 1, PrintValue)
		else
			PrintValue = PrintValue .. FormattedText .. tostring(Value)
		end
	end
	return PrintValue
end
lib.GetStringTable = GetStringTable

function lib.Contains(Table, Value)
	for _, Item in pairs(Table) do
		if Item == Value then
			return true
		end
	end

	return false
end

function lib.Overwrite(Table, NewTable)
	for Index, Item in pairs(NewTable) do
		Table[Index] = Item
	end

	return Table
end

function lib.ErrorOnBadIndex(Table)
	return setmetatable(Table, {
		__index = function(self, Index)
			error(("Bad index '%s'"):format(tostring(Index)))
		end;
	})
end

return lib
