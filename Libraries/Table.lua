while not _G.NevermoreEngine do wait(0) end

local Players           = Game:GetService('Players')
local StarterPack       = Game:GetService('StarterPack')
local StarterGui        = Game:GetService('StarterGui')
local Lighting          = Game:GetService('Lighting')
local Debris            = Game:GetService('Debris')
local Teams             = Game:GetService('Teams')
local BadgeService      = Game:GetService('BadgeService')
local InsertService     = Game:GetService('InsertService')
local Terrain           = Workspace.Terrain

local NevermoreEngine   = _G.NevermoreEngine
local LoadCustomLibrary = NevermoreEngine.LoadLibrary;

local qSystems          = LoadCustomLibrary('qSystems')

qSystems:import(getfenv(0));

local lib = {}

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
-- Addes al of NewTable's values to Table..
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
	local OriginalType = type(OriginalTable)
	local Copy
	if OriginalType == 'table' then
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

lib.DeepCopy = DeepCopyTable
lib.deepCopy = DeepCopyTable
lib.deep_copy = DeepCopyTable

local function Swap(Table, A, B)
	local Copy = Table[A]
	Table[A] = Table[B]
	Table[B] = Copy
end

local function ShellSort(Table, GetValue)
	-- Shell Sort -- Pretty efficient... GetValue should return a number of some sort. Will sort from Least to Greatest.

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

NevermoreEngine.RegisterLibrary('Table', lib)
