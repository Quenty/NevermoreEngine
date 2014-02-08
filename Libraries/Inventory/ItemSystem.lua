local ReplicatedStorage       = game:GetService("ReplicatedStorage")

local NevermoreEngine         = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary       = NevermoreEngine.LoadLibrary

local qSystems                = LoadCustomLibrary("qSystems")
local OverriddenConfiguration = LoadCustomLibrary("OverriddenConfiguration")

qSystems:Import(getfenv(0))

local lib = {}

--- Handles Items in away that is persistent and parsable.
-- ItemSystem.lua
-- @author Quenty

--[[ -- Change Log
February 7th, 2014
- Updated so Data is now stored locally in a table. 
- Added change log
- Added some documentation
- Updated to use OverriddenConfiguration
- Removed ParseConstructor
- Added UID system for server-client interactions.

- Fixed Class Index Problem

February 3rd, 2014
- Updated to work with New Nevermore System

-------------------
-- DOCUMENTATION --
-------------------

The item system is used to handle "items" and construct them. This is for in-game items. Before they were stored in Configuration objects,
with items in them, but this turned out to be rather messy. 

We have now switched to using tables, as new networking and FilteringEnabled in workspace now exist, and it is more easy to do it this way.
Items contain several components to work with them. ROBLOX (or Lua) do not provide easy OOP, but we can make do with tables and metatablse.

Attributes aren't case sensitive.

`Table` [Item] Item
	This is a generic item created by this system.

	`Table` [ClassBase] ClassBase
		This points to the ClassBase 'Template' object that the object uses. This is purely for internal usage.
	`String` ClassName 
		The ClassName of the class
	`Table` Data
		Specific "Attributes" that aren't global
	`Table` Interfaces
		This is the fun part. The Interfaces table is one that can be used by other programs / codes to store specific data related to the
		item. The programs should only create a table for them to use, and it should be a specific name to prevent conflicts.

		I can't do too much to prevent conflicts. It seems messy, but maintaining a linked array is so messy. 

		An example here would be BoxInventory using an interface at 
			Item.Interfaces.BoxInventory

		This is just a table associated with the Item. I called it "Interfaces" because that's what I'd totally like it to be, an implimentable
		class "interface" over the class (IF you're familiar with OOP, this might make more sense).

The bin that is used to create these objects is stored in ROBLOX objects because it is easier to edit and modify them there, as wella s generate
them. There is an efficiency lost, I'm sure. It is suggested they are stored in a single bin, as will be shown below, but bins can be combined,
et cetera, as the ItemSystem takes in a table of them.

Backpack and Configuration are interchanable, here. 

`Backpack` ItemClassNameHere
	Your generic Item class definition here. It's in ROBLOX objects. 

	`Configuration` Attributes
		These attributes should only be ROBLOX objects with the class names noted in the RobloxValueTypes table.
		Please note that ththe name used for these binsan be changed via the Configuration.
		
		`IntValue` BurnPoints
			This is an example, you can have an attribute called 'BurnPoints' that would be different per a user.
			The value set here is the "DefaultValue" of the item.
		...
	`Configuration` GlobalAttributes
		These are static attributes, shared accross all items, and don't change. 
		Please note that ththe name used for these binsan be changed via the Configuration.
		
		`Model` Model
			This is an exmaple, for example, you could have a model that is the 3D representation of the object.

The following names cannot be used for Attributes:
	UID
	ClassName
	Interfaces
	ClassBase
	Data

--]]



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
	-- ["ObjectValue"]            = true; -- We can't send this one over the network. 
	["RayValue"]               = true;
	["StringValue"]            = true;
	["Vector3Value"]           = true;
}


local function GetValue(Class, AttributeName)
	--- Return's the attribute if it can find it, and true if it's static, false if it's not
	--- Helper function
	-- @param Class The class to check, constructed

	local ClassBase = Class.ClassBase;
	for LocalAttributeName, Attribute in pairs(ClassBase.StaticAttributes) do
		if AttributeName:lower() == LocalAttributeName:lower() then
			return Attribute, true
		end
	end

	local Data = Class.Data[AttributeName:lower()]
	if Data ~= nil then
		return Data
	end

	return nil;
end

-- To be set on classes to facilitate removal/addition
local ClassMetatable = {
	__index = function(Class, IndexName)
		if type(IndexName) == "string" then
			if IndexName:lower() == "get" or IndexName:lower() == "getvalue" then
				return GetValue
			elseif IndexName:lower() == "data" then
				return Class.Data
			end
		end

		local Attribute = GetValue(Class, IndexName)
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
		if NewValue ~= nil then
			IndexName = IndexName:lower()

			if Class.Data[IndexName:lower()] then
				Class.Data[IndexName:lower()] = NewValue
			else
				error("[ItemSystem] - Attribute '"..Attribute.Name.."' could not be found.")
			end
		else
			error("[ItemSystem] - Tried to set '" .. IndexName .. "' but the value was '" .. tostring(NewValue) .. "' (nil).")
		end
	end;
	__tostring = function(Class)
		return "Item@'"..Class.ClassName.."'"..Class.Data.uid;
	end;
}

local MakeItemSystem = Class(function(ItemSystem, Configuration, ItemClassList, Constructor)
	-- Handles items properties, new items, and whatnot.  Handles construction and properties and stuffz. :)
	-- @param Constructor function that will be called on Item construction. It will send the preconstructed class to the constructor, as well as any arguments passed into it..
	-- @param ItemClassList A list of items. Each item should be setup like this
	--[[
		`Backpack` ItemClassNameHere
			Your generic Item class definition here. It's in ROBLOX objects. 

			`Configuration` Attributes
				These attributes should only be ROBLOX objects with the class names noted in the RobloxValueTypes table.
				Please note that the name used for these bins can be changed via the Configuration.

				`IntValue` BurnPoints
					This is an example, you can have an attribute called 'BurnPoints' that would be different per a user.
					The value set here is the "DefaultValue" of the item.
				...
			`Configuration` GlobalAttributes
				These are static attributes, shared accross all items, and don't change. 
				Please note that the name used for these bins can be changed via the Configuration.

				`Model` Model
					This is an exmaple, for example, you could have a model that is the 3D representation of the object.
	]]


	local ItemClasses = {}
	Configuration = OverriddenConfiguration.New(Configuration, {
		-- Default Configuration

		StaticAttributeBinName = "GlobalAttributes";
		AttributeBinName       = "Attributes";
	})
	

	local function AddNewItemClass(ItemClass)
		-- Add an ItemClass into the system.  Will check for duplicates in information. To be called, preferably, once.
		-- @param ItemClass The ItemClass bin, as specified above. 
		-- @post Item is added into ItemClasses table.

		local ItemName = ItemClass.Name;
		if not ItemClasses[ItemName] then
			local NewClass = {}
			NewClass.ClassName = ItemName;
			--NewClass.Interfaces = {} -- Should be in normal instantation. 
			
			-- Get bins and verify existance.
			local StaticAttributeBin = ItemClass:FindFirstChild(Configuration.StaticAttributeBinName)
			assert(StaticAttributeBin, "[ItemSystem] - StaticAttribute in ItemClass "..ItemClass.Name.." could not be found. (Expect to be @ "..ItemClass:GetFullName().."."..Configuration.StaticAttributeBinName)
			local AttributeBin = ItemClass:FindFirstChild(Configuration.AttributeBinName)
			assert(AttributeBin, "[ItemSystem] - AttributeBin in ItemClass "..ItemClass.Name.." could not be found. (Expect to be @ "..ItemClass:GetFullName().."."..Configuration.StaticAttributeBinName)

			NewClass.StaticAttributes = {}
			NewClass.AttributeBin     = {}

			-- Add Statis Attributes in
			for _, ItemClass in pairs(StaticAttributeBin:GetChildren()) do
				if not NewClass.StaticAttributes[ItemClass.Name] then
					NewClass.StaticAttributes[ItemClass.Name] = ItemClass;
				else
					error("[ItemSystem] - StaticAttribute for ItemClass '"..ItemClass.Name.."' already exists in '"..ItemClass.Name.."'")
				end
			end

			-- Add local attributes in.
			for _, ItemClass in pairs(AttributeBin:GetChildren()) do
				if NewClass.AttributeBin[ItemClass.Name] then
					error("[ItemSystem] - Attribute for ItemClass '"..ItemClass.Name.."' already exists in '"..ItemClass.Name.."' in the Attribute Bin")
				elseif NewClass.StaticAttributes[ItemClass.Name] then
					error("[ItemSystem] - Attribute for ItemClass '"..ItemClass.Name.."' already exists in '"..ItemClass.Name.."' in the StaticAttribute Bin")
				else
					NewClass.AttributeBin[ItemClass.Name] = ItemClass;
				end
			end

			ItemClasses[ItemClass.Name] = NewClass;
		else
			error("[ItemSystem] - ItemClass Class '"..ItemClass.Name.."' already exists in ItemSystem")
		end
	end
	ItemSystem.AddNewItemClass = AddNewItemClass
	ItemSystem.addNewItemClass = AddNewItemClass

	local function GetItemClasses()
		--- Return's all ItemClasse that exist.
		-- @return A list of the ItemClasses that exist. Should not modify values inside of this without deep copy.

		return ItemClasses
	end
	ItemSystem.GetItemClasses = GetItemClasses
	ItemSystem.getItemClasses = GetItemClasses

	local UIDCounter = 1
	local function GenerateUID(ItemData)
		UIDCounter = UIDCounter + 1
		return "Class@" .. tostring(ItemData) .. "@" .. UIDCounter
	end

	local function ConstructNewItem(ClassName, ...)
		--- Constructs a new item, with the ClassName 'ClassName'
		-- @param ClassName The name of the class to construct
		-- @param ... Constructure arguments.
		-- @return The constructud class. 

		if ItemClasses[ClassName] then
			local NewClass      = {}
			NewClass.ClassBase  = ItemClasses[ClassName]
			NewClass.ClassName  = ClassName;
			NewClass.Data       = {}
			NewClass.Interfaces = {}

			local UID = GenerateUID(NewClass.Data)

			for AttributeName, AttributeObject in pairs(ItemClasses[ClassName].AttributeBin) do
				NewClass.Data[AttributeName:lower()] = AttributeObject.Value
			end
			NewClass.UID = UID

			-- Must be lower case, because everything in Data is lowe case. 
			NewClass.Data.classname = ClassName
			NewClass.Data.uid = UID

			-- Finish construction.
			if Constructor then
				Constructor(ItemSystem, NewClass, ...) -- May error with the '...', may have to repack and unpack...
			end
			setmetatable(NewClass, ClassMetatable)

			return NewClass;
		else
			error("[ItemSystem] - Could not find Class data for Class '"..ClassName.."'")
		end
	end
	ItemSystem.ConstructNewItem = ConstructNewItem;
	ItemSystem.constructNewItem = ConstructNewItem;
	ItemSystem.New              = ConstructNewItem;
	ItemSystem.new              = ConstructNewItem;

	local function ConstructClassFromData(Data, ...)
		--- Reconstructs a class from the Data given. 
		-- @param Data The data from an old class, NewClass.Data
		-- @param ... Constructer arguements. 
		-- @return The cosntructed class

		if type(Data.classname) ~= "string" then
			error("[ItemSystem] - Data.classname == '" .. tostring(Data.classname) .."', invalid Data, unable to construct new item")
		end
		if not Data.uid then
			error("[ItemSystem] - Data.uid == '" .. tostring(Data.uid) .."', invalid UID, unable to construct new item")
		end

		local ClassName = Data.classname

		if not ItemClasses[ClassName] then
			error("[ItemSystem] - Cannot find ItemClass with ClassName of '" .. ClassName .."'")
		end
		
		local NewClass = {}
		
		NewClass.ClassBase = ItemClasses[ClassName]
		NewClass.ClassName = ClassName;
		NewClass.UID = Data.uid

		NewClass.Data       = {}
		for Index, Value in pairs(Data) do
			NewClass.Data[Index:lower()] = Value
		end
		NewClass.Interfaces = {}

		if Constructor then
			Constructor(ItemSystem, NewClass, ...) -- May error with the '...', may have to repack and unpack...
		end
		setmetatable(NewClass, ClassMetatable)

		return NewClass
	end
	ItemSystem.ConstructClassFromData = ConstructClassFromData;
	ItemSystem.constructClassFromData = ConstructClassFromData;
	ItemSystem.ParseData              = ConstructClassFromData;
	ItemSystem.parseData              = ConstructClassFromData;

	--- Parse existing items in the class system.
	if ItemClassList then
		for _, Item in pairs(ItemClassList) do
			AddNewItemClass(Item)
		end
	end
end)
lib.MakeItemSystem = MakeItemSystem;
lib.makeItemSystem = MakeItemSystem;

return lib
