-- To extend your table library, use: local table = require(this_script)
-- @author Quenty, Narrev

lib = {
	help = function(...)
	-- Please add your documentation here, Quenty
		return [[
	There are 6 additional functions that have been added; contains, copy, getIndexByValue, random, sum, and overflow
	table.contains(table, value)
		returns whether @param value is in @param table

	table.copy(table)
		returns a new table that is a copy of @param table

	table.getIndexByValue(table, value)
		Return's the index of a Value in a table.
		@param tab table to search through 
		@value the Value to search for
		@return The key of the value. Returns nil if it can't find it.

	table.random(table)
		returns a random value (with an integer key) from @param table
		newMap = table.random{map1, map2, map3}

	table.sum(table)
		adds up all the values in @param table via ipairs

	table.overflow(table, seed)
		continually subtracts the values (with ipairs) in @param table from @param seed until seed cannot be subtracted from further
		It then returns index at which the iterated value is greater than the remaining seed, and leftover seed (before subtracting final value)

		This can be used for relative probability :D
		
		The following example chooses a random value from the Options table, with some options being more likely than others:
		
		local Options	= {"opt1","opt2","opt3","opt4","opt5","opt6"}
		local tab		= {2,4,5,6,1,2} -- Each number is likelihood relative to the rest
		local seed		= math.random(1, table.sum(tab))
		
		local chosenKey, LeftoverSeed = table.overflow(tab, seed)
		local randomChoiceFromOptions = Options[chosenKey] ]]
	end;

	concat			= function(...) return table.concat	(...) end;
	foreach			= function(...) return table.foreach	(...) end;
	foreachi		= function(...) return table.foreachi	(...) end;
	getn			= function(...) return table.getn	(...) end;
	insert			= function(...) return table.insert	(...) end;
	remove			= function(...) return table.remove	(...) end;
	sort			= function(...) return table.sort	(...) end;
}

local function Count(Table)
	local Count = 0;
	for _, _ in pairs(Table) do
		Count = Count + 1
	end
	return Count
end
lib.Count = Count
lib.count = Count


local function CopyAndAppendTable(OriginalTable, Appendees)
	-- Copies a table, and appends the values in appendees.

	local NewTable = {}

	for Index, Value in pairs(OriginalTable) do
		NewTable[Index] = Value;
	end

	for Index, Value in pairs(Appendees) do
        NewTable[Index] = Value;
    end

	return NewTable;
end
lib.CopyAndAppend = CopyAndAppendTable
lib.copyAndAppend = CopyAndAppendTable
lib.copy_and_append = CopyAndAppendTable


local GetStringTable
function GetStringTable(Array, Indent, PrintValue)
	-- Print's `Array` recursively with `Indent` as the initial indent
	-- Cheap method, but not optimal either... Used for debugging. :D

	PrintValue = PrintValue or tostring(Array);
	Indent = Indent or 0
	for Index, Value in pairs(Array) do
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
lib.getStringTable = GetStringTable
lib.get_string_table = GetStringTable


local function Append(Table, NewTable, Callback)
	-- Addes all of NewTable's values to Table..

	if Callback then
		for _, Item in pairs(NewTable) do
			if Callback(Item) then
				table.insert(Table, Item)
			end
		end
	else
		for _, Item in pairs(NewTable) do
			table.insert(Table, Item)
		end
	end

	return Table
end
lib.Append = Append
lib.append = Append


local function DirectAppend(Table, NewTable, Callback)
-- Addes al of NewTable's values to Table..
	if Callback then
		for Index, Item in pairs(NewTable) do
			if Callback(Item) then
				Table[Index] = Item
			end
		end
	else
		for Index, Item in pairs(NewTable) do
			Table[Index] = Item
		end
	end

	return Table
end
lib.DirectAppend = DirectAppend
lib.directAppend = DirectAppend


local function CopyTable(OriginalTable)
	local Copy
	if type(OriginalTable) == 'table' then
		Copy = {}
		for Index, Value in pairs(OriginalTable) do
			Copy[Index] = Value
		end
	else
		Copy = OriginalTable
	end
	return Copy
end
lib.Copy = CopyTable
lib.copy = CopyTable


local DeepCopy
function DeepCopyTable(OriginalTable)
	local Copy
	if type(OriginalTable) == 'table' then
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
lib.DeepCopy = DeepCopyTable
lib.deepCopy = DeepCopyTable
lib.deep_copy = DeepCopyTable


local function ShellSort(Table, GetValue)
	-- Shell Sort -- Pretty efficient... GetValue should return a number of some sort. Will sort from Least to Greatest.

	local function Swap(Table, A, B)
		local Copy = Table[A]
		Table[A] = Table[B]
		Table[B] = Copy
	end

	local TableSize = #Table
	local Gap = #Table
	repeat
		local Switched
		repeat
			Switched = false;
			local Index = 1
			while Index + Gap <= TableSize do
				if GetValue(Table[Index]) > GetValue(Table[Index+Gap]) then
					Swap(Table, Index, Index + Gap)
					Switched = true;
				end
				Index = Index + 1;
			end
		until not Switched
		Gap = math.floor(Gap / 2)
	until Gap == 0
end
lib.ShellSort = ShellSort
lib.shellSort = ShellSort
lib.shell_sort = ShellSort


local function random(tab)
	-- This should be rewritten to support tables with string keys
	return tab[math.random(1, #tab)]
end;
lib.random = random
lib.Random = random


local function contains(tab, value)
	for _, Value in pairs(tab) do
		if Value == value then
			return true
		end
	end
	return false
end
lib.contains = contains
lib.Contains = contains


local function overflow(tab, seed)
	for i, value in ipairs(tab) do
		if seed - value <= 0 then
			return i, seed
		end
		seed = seed - value
	end
end
lib.overflow = overflow
lib.Overflow = overflow


local function sum(tab)
	local sum = 0
		for _, value in pairs(tab) do
			sum = sum + value
		end
	return sum
end
lib.sum = sum
lib.Sum = sum


local function GetIndexByValue(tab, Value)
	for Index, TableValue in next, tab do
		if Value == TableValue then
			return Index
		end
	end
	return nil
end
lib.GetIndexByValue = GetIndexByValue
lib.getIndexByValue = GetIndexByValue
lib.indexByValue = GetIndexByValue
lib.IndexByValue = GetIndexByValue
lib.index_by_value = GetIndexByValue


return lib
