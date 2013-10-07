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
local qString           = LoadCustomLibrary('qString')
local lib    = {}

qSystems:import(getfenv(0));

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


NevermoreEngine.RegisterLibrary('EnumInterpreter', lib);