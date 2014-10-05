local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary
local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")
local qString           = LoadCustomLibrary("qString")

local lib               = {}

-- EnumInterpreter.lua
-- @author Quenty
-- Last Modified February 3rd, 2014

qSystems:Import(getfenv(1))

local function Scan(Table, StringName)
	for Index, Value in pairs(Table) do
		if qString.CompareStrings(Value, StringName) then
			return Index;
		end
	end
	return nil;
end

local function ScanName(Table, StringName)
	for Index, Value in pairs(Table) do
		if qString.CompareStrings(Value, StringName) then
			return Value;
		end
	end
	return nil;
end

local function GetEnum(EnumTable, EnumValue) 
--[[ Given a table structured like this:

	Foods = {
		"Pizza";
		"Pie";
		"Vanilla";
	}

	And an EnumValue, like one of the following:
		pizza
		pie
		vanilla
		0
		1
		2

	It'll return the enum ID (Number)...

		pizze --> 0
		0 --> 0

		etc. 
--]]

	if tonumber(EnumValue) and EnumTable[tonumber(EnumValue)] then
		return EnumValue;
	else
		local ScanResult = Scan(EnumTable, EnumValue)
		if ScanResult and tonumber(ScanResult) then
			return ScanResult;
		else
			error("EnumValue expected, could not interpret '"..tostring(EnumValue).."' into an Enum #")
		end
	end
end

lib.getEnum = GetEnum;
lib.GetEnum = GetEnum;
lib.get_enum = GetEnum;

local function GetEnumName(EnumTable, EnumValue)
	if tonumber(EnumValue) and EnumTable[tonumber(EnumValue)] then
		return EnumTable[tonumber(EnumValue)];
	else
		local ScanResult = ScanName(EnumTable, EnumValue)
		if ScanResult then
			return ScanResult;
		else
			error("EnumValue expected, could not interpret '"..tostring(EnumValue).."' into an Enum #")
		end
	end
end

lib.getEnumName = GetEnumName;
lib.GetEnumName = GetEnumName;
lib.get_enum_name = GetEnumName;



return lib