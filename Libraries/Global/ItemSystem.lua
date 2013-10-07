local Players           = Game:GetService('Players')
local StarterPack       = Game:GetService('StarterPack')
local StarterGui        = Game:GetService('StarterGui')
local Lighting          = Game:GetService('Lighting')
local Debris            = Game:GetService('Debris')
local Teams             = Game:GetService('Teams')
local BadgeService      = Game:GetService('BadgeService')
local InsertService     = Game:GetService('InsertService')
local Terrain           = Workspace.Terrain

while not _G.NevermoreEngine do wait(0) end

local NevermoreEngine   = _G.NevermoreEngine
local LoadCustomLibrary = NevermoreEngine.LoadLibrary;

local qSystems          = LoadCustomLibrary('qSystems')

qSystems:Import(getfenv(0));

local lib = {}

-- List of all the ROBLOXValue types...
local RobloxValueTypes = {
	["BoolValue"]              = true;
	["BrickColorValue"]        = true;
	["CFrameValue"]            = true;
	["Color3Value"]            = true;
	["DoubleConstrainedValue"] = true;
	["IntConstrainedValue"]    = true;
	["IntValue"]               = true;
	["NumberValue"]            = true;
	["ObjectValue"]            = true;
	["RayValue"]               = true;
	["StringValue"]            = true;
	["Vector3Value"]           = true;
}


local function GetValue(Class, AttributeName)
	-- Return's the attribute if it can find it, and true if it's static, false if it's not
	local ClassBase = Class.ClassBase;
	for AttributeName, Attribute in pairs(ClassBase.StaticAttributes) do
		if AttributeName:lower() == IndexName:lower() then
			return Attribute, true
		end
	end

	for _, Attribute in pairs(Class.Container:GetChildren()) do
		if Attribute.Name:lower() == IndexName:lower() then
			return Attribute, false
		end
	end

	return nil;
end

-- To be set on classes to facilitate removal/addition
local ClassMetatable = {
	__index = function(Class, IndexName)
		if IndexName:lower() == "get" or IndexName:lower() == "getvalue" then
			return GetValue
		end

		local Attribute = GetValue(Class)
		if Attribute then
			if RobloxValueTypes[Attribute.ClassName] then
				return Attribute.Value;
			else
				return Attribute -- Maybe want to clone it? Nah, they can't "hypothetically" change it...
			end
		end

		if IndexName == "ClassName" then
			return ClassBase.ClassName;
		elseif Instance == "Interfaces" then
			return ClassBase.Interfaces	
		end

		return nil;
	end;
	__newindex = function(Class, IndexName, NewValue)
		local ClassBase = Class.ClassBase;
		local DidFind;
		for _, Attribute in pairs(Class.Container:GetChildren()) do
			if Attribute.Name:lower() == IndexName:lower() then
				if RobloxValueTypes[Attribute.ClassName] then
					Attribute.Value = NewValue;
					DidFind = true;
					break;
				else
					error("[ItemSystem] - Attribute '"..Attribute.Name.."' does cannot be modified, it is not a ROBLOXValue object")
				end
			end
		end
		if not DidFind then -- Allow for more data to be stored in the Object, local data only...
			rawset(Class, IndexName, NewValue)
			print("[ItemSystem] - Set local data '"..IndexName.."'' for Class '"..Class.ClassName.."'")
		end

		error("[ItemSystem] - Attribute '"..Attribute.Name.."' could not be found, or cannot be modified (Is static)")
	end;
	__tostring = function(Class)
		return "ItemSystem Item type '"..Class.ClassName.."'";
	end;
}

local MakeItemSystem = Class 'ItemSystem' (function(ItemSystem, Configuration, ItemClassList, Constructor, ParseConstructor)
	-- Handles items properties, new items, and whatnot.  Handles construction and properties and stuffz. :)
	-- @param Constructor function that will be called on Item construction. It will send the preconstructed class to the constructor, as well as any arguments passed into it..
	-- @param ParseConstructor will be called when parsing an old data container into a new object.

	local ItemClasses                    = {}
	local Configuration                  = Configuration or {}
	Configuration.StaticAttributeBinName = Configuration.StaticAttributeBinName or "GlobalAttributes"; -- Attributes that
	Configuration.AttributeBinName       = Configuration.AttributeBinName or "Attributes";

	Constructor = Constructor or function(NewClass) return NewClass end;

	local function ParseItem(Item)
		-- Add an item into the system.  Will check for duplicates in information. To be called, preferably, once.

		local ItemName = Item.Name;
		if not ItemClasses[ItemName] then
			local NewClass = {}
			NewClass.ClassName = ItemName;
			NewClass.Interfaces = {}
			
			-- Get bins and verify existance.
			local StaticAttributeBin = Item:FindFirstChild(Configuration.StaticAttributeBinName)
			assert(StaticAttributeBin, "[ItemSystem] - StaticAttribute in Item "..Item.Name.." could not be found. (Expect to be @ "..Item:GetFullName().."."..Configuration.StaticAttributeBinName)
			local AttributeBin = Item:FindFirstChild(Configuration.AttributeBinName)
			assert(AttributeBin, "[ItemSystem] - AttributeBin in Item "..Item.Name.." could not be found. (Expect to be @ "..Item:GetFullName().."."..Configuration.StaticAttributeBinName)

			NewClass.StaticAttributes = {}
			NewClass.AttributeBin     = {}

			-- Add Statis Attributes in
			for _, Item in pairs(StaticAttributeBin:GetChildren()) do
				if not NewClass.StaticAttributes[Item.Name] then
					NewClass.StaticAttributes[Item.Name] = Item;
				else
					error("[ItemSystem] - StaticAttribute for Item '"..Item.Name.."' already exists in '"..Item.Name.."'")
				end
			end

			-- Add local attributes in.
			for _, Item in pairs(AttributeBin:GetChildren()) do
				if NewClass.AttributeBin[Item.Name] then
					error("[ItemSystem] - Attribute for Item '"..Item.Name.."' already exists in '"..Item.Name.."' in the Attribute Bin")
				elseif NewClass.StaticAttributes[Item.Name] then
					error("[ItemSystem] - Attribute for Item '"..Item.Name.."' already exists in '"..Item.Name.."' in the StaticAttribute Bin")
				else
					NewClass.AttributeBin[Item.Name] = Item;
				end
			end

			ItemClasses[Item.Name] = NewClass;
		else
			error("[ItemSystem] - Item Class '"..Item.Name.."' already exists in ItemSystem")
		end
	end
	ItemSystem.ParseItem = ParseItem
	ItemSystem.parseItem = ParseItem

	local function GetItemClasses()
		--- Return's all ItemClasse

		return ItemClasses
	end
	ItemSystem.GetItemClasses = GetItemClasses
	ItemSystem.getItemClasses = GetItemClasses

	local function ConstructNewClass(NewClassName, ...)
		if ItemClasses[NewClassName] then
			local NewClass     = {}
			NewClass.ClassBase = ItemClasses[NewClassName]
			NewClass.ClassName = NewClassName;
			NewClass.Container = Instance.new("Configuration")
			NewClass.Container.Name = NewClassName.."LocalData";
			NewClass.Interfaces = {}

			for AttributeName, AttributeObject in pairs(ItemClasses[NewClassName].AttributeBin) do
				local Clone = AttributeObject:Clone()
				AttributeObject.Parent = NewClass.Container
			end

			local ClassNameObject = Instance.new("StringValue", NewClass.Container)
			ClassNameObject.Name = "ClassName";
			ClassNameObject.Value = NewClassName

			if Constructor then
				Constructor(ItemSystem, NewClass, ...) -- May error with the '...', may have to repack and unpack...
			end
			setmetatable(NewClass, ClassMetatable)

			return NewClass;
		else
			error("[ItemSystem] - Could not find Class data for Class '"..NewClassName.."'")
		end
	end
	ItemSystem.ConstructNewClass = ConstructNewClass;
	ItemSystem.constructNewClass = ConstructNewClass;
	ItemSystem.New = ConstructNewClass;
	ItemSystem.new = ConstructNewClass;

	local function GetNewClassFromDataBin(DataBin, ...)
		local NewClass = {}
		NewClass.ClassBase = ItemClasses[NewClassName]
		NewClass.ClassName = DataBin.ClassName.Value;
		NewClass.Container = DataBin;
		NewClass.Container.Name = NewClassName.."LocalData";
		NewClass.Interfaces = {}

		if Constructor then
			Constructor(ItemSystem, NewClass, ...) -- May error with the '...', may have to repack and unpack...
		end
		setmetatable(NewClass, ClassMetatable)

		return NewClass
	end
	ItemSystem.GetNewClassFromDataBin = GetNewClassFromDataBin;
	ItemSystem.getNewClassFromDataBin = GetNewClassFromDataBin;
	ItemSystem.ParseDatabin = GetNewClassFromDataBin;
	ItemSystem.parseDatabin = GetNewClassFromDataBin;

	if ItemClassList then
		for _, Item in pairs(ItemClassList) do
			ParseItem(Item)
		end
	end
end)
lib.MakeItemSystem = MakeItemSystem;

NevermoreEngine.RegisterLibrary('ItemSystem', lib)
