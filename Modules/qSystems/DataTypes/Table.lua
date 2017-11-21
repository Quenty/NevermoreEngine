--- Intent: Provide a variety of utility Table operations

local lib = {}

local function Append(Table, NewTable)
	for _, Item in pairs(NewTable) do
		table.insert(Table, Item)
	end

	return Table
end
lib.Append = Append

local function Count(Table)
	local Count = 0;
	for _, _ in pairs(Table) do
		Count = Count + 1
	end
	return Count
end
lib.Count = Count

local function DeepCopy(OriginalTable)
	local OriginalType = type(OriginalTable)
	local Copy
	if OriginalType == 'table' then
		Copy = {}
		for Index, Value in next, OriginalTable, nil do
			Copy[DeepCopy(Index)] = DeepCopy(Value)
		end
		setmetatable(Copy, DeepCopy(getmetatable(OriginalTable)))
	else
		Copy = OriginalTable
	end
	return Copy
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

local function GetIndexByValue(Table, Value)
	for Index, TableValue in pairs(Table) do
		if Value == TableValue then
			return Index
		end
	end
	return nil
end
lib.GetIndexByValue = GetIndexByValue

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

local function Overwrite(Table, NewTable)
	for Index, Item in pairs(NewTable) do
		Table[Index] = Item
	end

	return Table
end
lib.Overwrite = Overwrite

return lib
