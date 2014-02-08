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
local ModularSystem     = LoadCustomLibrary('ModularSystem')
local MenuSystem        = LoadCustomLibrary('MenuSystem')
local qString           = LoadCustomLibrary('qString')
local PenlightPretty    = LoadCustomLibrary('PenlightPretty')
local SoundPlayer       = LoadCustomLibrary('SoundPlayer')
local Table             = LoadCustomLibrary('Table')

qSystems:Import(getfenv(0));

--[[
Personal Notes:

I honestly don't think this system will be that easy for anyone else to use, or for me to even remember how it works.

However, it's fairly flexable, and probably overcomplicated... The main issue was in getting it so almost anything can
be modified, layers upon layers upon layers of data, that not only overwhelms me, but overwhelms users too.  In this case,
it was designed to allow the modification of a class, where you select your primary and secondary gun, and then where you
may also modify your gun in question. This is, to put it simply, a pain.

--]]

-- Command line code to help modify catagories with Header Tags.
--local Name = "Hi" local S = game:GetService("Selection") for _, SItem in pairs(S:Get()) do for _, I in pairs(SItem:GetChildren()) do IN = I.Name _, _, x = string.find(IN, "[%w%s]+:([%w%s]+)")  if x then I.Name = Name..":"..x else I.Name = Name..":"..IN end end end

local lib = {}

local function ExtractNames(Name)
	-- Give a name like 'Catagory:Primary Weapons', it'll return `Catagory`, and `Primary Weapons`

	local Position = string.find(Name, ":")
	if Position then
		local HandlerType = string.sub(Name, 0, Position-1)
		local ItemName = string.sub(Name, Position+1, #Name)
		return HandlerType, ItemName
	else
		--error("[CharacterClassSystem] - Could not exstract name for '" .. Name .. "'"))
		return nil, nil
	end
end
lib.ExtractNames = ExtractNames

local GetCCCatagoryModel
function GetCCCatagoryModel(Asset)
	-- Return's the first CCCatagory it finds, or returns nil.. (Recurses up the tree structure....)

	if not Asset.Parent then
		return nil
	elseif qString.CompareCutFirst(Asset.Parent.Name, "CCCatagory") then
		return Asset.Parent
	else
		return GetCCCatagoryModel(Asset.Parent)
	end
end

local GetFirstSelector
function GetFirstSelector(Model)
	-- Goes until it finds a selector, or errors, recurses through datastructure.  Would find Selector:RifleA

	for _, Item in pairs(Model:GetChildren()) do
		local HandlerName, ItemName = ExtractNames(Item.Name)

		if HandlerName == "Selector" then
			return Item
		elseif HandlerName then
			return GetFirstSelector(Item)
		end
	end
end
lib.GetFirstSelector = GetFirstSelector

local function ExtractNamesFromCatagoryListWithDefaults(CustomCatagories, Defaults)
	-- Returns a properly formatted name list from CustomCatagories, setting the default as either the provided one, or the first child. 
	Defaults = Defaults or {}

	local Names = {}
	for _, Item in pairs(CustomCatagories:GetChildren()) do
		local HandlerType, ItemName = ExtractNames(Item.Name)

		if Defaults[ItemName] then
			Names[ItemName] = Defaults[ItemName]
		else
			--print("[CharacterClass] - Defaults = "..PenlightPretty.TableToString(Defaults))
			local FirstChild = GetFirstSelector(Item)
			if FirstChild then
				local _, FirstChildName = ExtractNames(FirstChild.Name)
				if ItemName and FirstChild and FirstChildName then
					Names[ItemName] = FirstChildName
				else
					error("[CharacterClassSystem] - Invalid ItemName or FirstChild")
				end
			else
				error("[CharacterClassSystem] - Could not get first `selector` in "..Item:GetFullName())
			end
		end
	end
	return Names
end
lib.ExtractNamesFromCatagoryListWithDefaults = ExtractNamesFromCatagoryListWithDefaults

local function ExtractObjects(Objects, PremadeTable, DoNotAllowObject)
	-- Set's up tables like this: 
	--[[

	{
		[1] = Configuration `Custom Class I`
		[2] = Configuration `Sniper`
		...
	}

	--]]

	DoNotAllowObject = DoNotAllowObject or function(Item) return false end

	local Table = PremadeTable or {}
	for _, Item in pairs(Objects) do
		if (DoNotAllowObject and not DoNotAllowObject(Item)) then
			Table[#Table+1] = Item
		end
	end
	return Table
end
lib.ExtractObjects = ExtractObjects



local DeserializeWorldAssetsRecurse
function DeserializeWorldAssetsRecurse(CCCatagoryTable, RecursionModel, AcceptableHandlers)
	-- Used by DeserializeWorldAssets to recurse through Catagory's to just get selector's

	for _, Item in pairs(RecursionModel:GetChildren()) do
		local HandlerType, ItemName = ExtractNames(Item.Name)
		assert(not CCCatagoryTable[ItemName], "[CharacterClassSystem] - Item '"..ItemName.."' already exists, found @ "..Item:GetFullName())

		if HandlerType == "Selector" then
			--print("[CharacterClassSystem] - Adding Assets[CCCatagoryName]["..ItemName.."]")
			CCCatagoryTable[ItemName] = Item
		elseif HandlerType == "Catagory" then
			DeserializeWorldAssetsRecurse(CCCatagoryTable, Item, AcceptableHandlers)
		elseif AcceptableHandlers[HandlerType] then
			print("[CharacterClassSystem] - Acceptable Handler Type `"..HandlerType.."`")
			CCCatagoryTable[ItemName] = Item
		else
			print("[CharacterClass] - AcceptableHandlers = "..PenlightPretty.TableToString(AcceptableHandlers))
			error("[CharacterClassSystem] - Invalid Formatted @ "..Item:GetFullName()..", handler '"..HandlerType.."' isn't in the handler list.")
		end
	end
end

local function AppendModularSelectionsAsAsset(ModularSelections, Assets, AssetType)
	-- So we can add add customizable modulars as assets. Really, this whole system is screwed.
	Assets[AssetType] = Assets[AssetType] or {}
	local CCCatagoryTable = Assets[AssetType]

	for _, Item in pairs(ModularSelections) do
		local HandlerType, ItemName = ExtractNames(Item.Name)
		CCCatagoryTable[ItemName] = Item;
	end
end
lib.AppendModularSelectionsAsAsset = AppendModularSelectionsAsAsset

local function DeserializeWorldAssets(AssetsModel, Assets, AcceptableHandlers)
	-- Takes in a AssetsModel (setup as shown below) and spews it out in a table.
	--[[

	Lighting
		| Classes
			| CustomCatagories <--- This one! 
				| CCCatagory:Auxiliary Weapon
					| Selector:AuxiTestTool
					| Selector:AuxiTestTool2
				| CCCatagory:Body Armour
					| Selector:RandomNameHere
					| Selector:RandomNameHere
				| CCCatagory:Perk I
					| Selector:RandomNameHere
					| Selector:RandomNameHere
				| CCCatagory:Perk II
					| Selector:RandomNameHere
					| Selector:RandomNameHere
				| CCCatagory:Perk III
					| Selector:RandomNameHere
					| Selector:RandomNameHere
				| CCCatagory:Primary Grenade
					| Selector:RandomNameHere
					| Selector:RandomNameHere
				| CCCatagory:Primary Weapon
					| Selector:RandomNameHere
					| Selector:RandomNameHere

	And returns something like this:

	{
		["Perk I"] = {
			["PerkAkljdf"] = Model `PerkAkljdf`;
			["PerkAkljdf2"] = Model `PerkAkljdf2`;
			["PerkAkljdf3"] = Model `PerkAkljdf3`;
			...
		};
		["Perk II"] = {
			["PerkAkljdf"] = Model `PerkAkljdf`;
			["PerkAkljdf2"] = Model `PerkAkljdf2`;
			["PerkAkljdf3"] = Model `PerkAkljdf3`;
			...
		};
		...
	}

	--]]

	--print("[CharacterClassSystem] - Deserializing Assets")

	-- Generate's the asset table...
	local Assets = Assets or {}
	for _, Item in pairs(AssetsModel:GetChildren()) do
		local HandlerType, ItemName = ExtractNames(Item.Name)
		if HandlerType and ItemName then
			--print("Deserializing/Added Assets["..ItemName.."]")
			Assets[ItemName] = Assets[ItemName] or {}
			if (not AcceptableHandlers[HandlerType]) and HandlerType ~= "CCCatagory" then
				print("[CharacterClass] - AcceptableHandlers = "..PenlightPretty.TableToString(AcceptableHandlers))
				print("[CharacterClass] - (not AcceptableHandlers[ItemName]) = ".. tostring(not AcceptableHandlers[ItemName]))
				print("[CharacterClass] - HandlerType ~= CCCatagory = "..tostring(HandlerType ~= "CCCatagory"))

				error("[CharacterClassSystem] - Invalid Formatted @ "..Item:GetFullName().." got '"..HandlerType.."' expected CCCatagory")
			end
			DeserializeWorldAssetsRecurse(Assets[ItemName], Item, AcceptableHandlers)
		else
			error("[CharacterClassSystem] - HandlerType or ItemName is nil, malformed asset @ "..Item:GetFullName())
		end
	end
	return Assets
end
lib.DeserializeWorldAssets = DeserializeWorldAssets

local function GenerateCustomClassData(ItemTag, ItemName, Container, NumberToGenerate, CustomizationTypes)
	-- Generate's a CustomClasse's data container...
	--[[
		CustomizationType's setup like this:

		["Perk I"] = "PerkA.1Test"; where the index is the name, and the default is the second value...
	--]]
	local CustomClasses = {}

	for ClassNumber=1, NumberToGenerate do
		local Name = ItemTag..":"..ItemName..qString.GetRomanNumeral(ClassNumber)
		local ClassContainer = Container:FindFirstChild(Name) or Make 'Configuration' {
			Name = Name;
			Parent = Container;
			Archivable = false;
		}
		for CustomizationName, CustomizationDefault in pairs(CustomizationTypes) do
			local CustomizationValue = ClassContainer:FindFirstChild(CustomizationName) or Make 'StringValue' {
				Name = CustomizationName;
				Parent = ClassContainer;
				Value = CustomizationDefault;
				Archivable = false;
			}
		end
		CustomClasses[Name] = ClassContainer
	end

	return CustomClasses;
end
lib.GenerateCustomClassData = GenerateCustomClassData
lib.generateCustomClassData = GenerateCustomClassData

local function GetClassAsset(Assets, AssetCatagory, AssetName)
	return Assets[AssetCatagory][AssetName]
end
lib.GetClassAsset = GetClassAsset
lib.getClassAsset = GetClassAsset

local function GenerateModular(ModularContainer, CustomizationContainer, CustomizablesAvailable, CustomModularName, ModularName, Defaults)
	-- Modulars can be generated by "hand" for more customization/configurability, but this whole system is bonk, so...

	--[[
		Model `ModularContainer` - Container with 2 models, Templates and Options. Templates contains premade options, and Options contains a list of CCCatagories.
		CustomizationAssets
		
		Configuratin `CustomizationContainer` - object that Contains the customization data for a player. Probably should be parented to the player.
	
		Int `CustomizablesAvailable` -  How many customizable objects to generate...

		String `CustomModularName` - The header of the CustomModularName, such as "Custom Class ".."I" where "I" is the roman numeral (Needs to be irmpoved, bt)

		String `ModularName` - Name of the whole modular...

		Table `Defaults` - Default items selected per a customization...
		{
			["Primary Grenade"] = "TestGrenadeOfHippo";
			["Primary Weapon II"] = "Modular Gun I";
		}
	--]]

	local Options = ModularContainer:FindFirstChild("Options")
	local Templates = ModularContainer:FindFirstChild("Templates")

	if Options and Templates then
		local CustomizationTypes = ExtractNamesFromCatagoryListWithDefaults(
			Options, 
			Defaults
		)
		local CustomAssets = GenerateCustomClassData(
			ModularName,
			CustomModularName.." ",
			CustomizationContainer, 
			CustomizablesAvailable,
			CustomizationTypes
		)
		local AvailableClasses = ExtractObjects(
			Templates:GetChildren(), 
			Table.Copy(CustomAssets)
		)
		local Modular = {
			RenderName = ModularName;
			Available = AvailableClasses;
			Editable = CustomAssets;
			CustomizationContainer = CustomizationContainer;
			ModularContainer = ModularContainer;
			OptionsContainer = Options;
			TemplateContainer = Templates;
		}
		return Modular
	else
		error("[CharacterClass] - Could not generate modular because ModularContainer did not contain `Options` or `Templates`")
		return nil
	end	
end
lib.GenerateModular = GenerateModular
lib.generateModular = GenerateModular

local MakeCharacterClassSystem = Class 'CharacterClassSystem' (function(CharacterClassSystem, NewMenu, ClassSelectorList, Assets)
	-- Creates a button that will work with a class System.  Data structure is extremely important:

	local Configuration = {
		CustomClassCatagoryName = "CCCatagory";
		LevelId = LevelId;
	}
	CharacterClassSystem.Configuration = Configuration
	local SetupButton
	local BeingEditedStack = {} -- Stackish like system. 
	local SelectorBeingEditedStack = {} -- Stackish like system too..
	local Handlers
	--[[CharacterClassSystem.OnClassSelect = Make 'BindableEvent' { -- Will fire when a new class is selected. Editing a class is the same as selecting one.
		Name = "OnClassSelected";
		Archivable = false;
	}--]]

	--[[

	Arguments:
		MenuSystem `NewMenu`
			The MenuSystem the button will be added too. 

		table `Classes` 
			A table of all the classes available to the player, setup like this:
			
			{
				["Custom Class I"] = Configuration `Custom Class I`
				["Sniper"] = Configuration `Sniper`
				...
			}

			In which each `Configuration` object will have StringValues associated with every single item in
			Assets.CCCatagory (CustomClassCatagory)

		array `ClassList`
			An array filled with a specific organization for setting up a customizable class. It'll be setup like this:

			{
				["ClassName"] = {
					Editable = {
						WordldObject;
						WordldObject;
						WordldObject;
						...
					};
					Available = {
						WordldObject;
						WordldObject;
						WordldObject;
						WordldObject;
						WordldObject;
						...
					};
					RenderName = "Hello";
					Assignables = {
						["Primary Weapon"] = true;
					}
				}
				....
			}

		
		table `Assets` 
			A table of all of assets available for customizing a class, setup like this: 

			{
				["Perk I"] = {
					["PerkAkljdf"] = Model `PerkAkljdf`;
					["PerkAkljdf2"] = Model `PerkAkljdf2`;
					["PerkAkljdf3"] = Model `PerkAkljdf3`;
					...
				};
				["Perk II"] = {
					["PerkAkljdf"] = Model `PerkAkljdf`;
					["PerkAkljdf2"] = Model `PerkAkljdf2`;
					["PerkAkljdf3"] = Model `PerkAkljdf3`;
					...
				};
				...
			}

			This can be generated from the standardized catagory system using lib.GenerateCustomClassData.  Generally, 
			this system is setup so that outside systems can get resources back. 


	-----------------
	-- MENU LEVELS --
	-----------------
	This is basically written out for myself, so I can write the system correctly.  However, 
	documentation never hurt anyone, and it certainly won't hurt you.  This is a pretty complicated 
	system. 

	The first level selected is the class level, handled by the 'Class' handler.  This level allows the
	user to select the class they want.  Clearly, it wouldn't get more complicated then this unless we
	wanted to allow extreme customization, which is, of course, what we want to do.

	The next level is accessed when the user clicks on the 'edit' button on a Class.  This can only be
	clicked if the class being edited is part of a configuration. Of course At this point, fun things
	start to happen.  

	We first add a record to the Stack. 

	--]]


	local function GetAsset(AssetCatagory, AssetName)
		-- Return's the asset in Assets. 
		if not Assets[AssetCatagory] then
			print("Assets = "..PenlightPretty.TableToString(Assets))
			error("[CharacterClassSystem] - Could not find Assets[" .. AssetCatagory .. "]")
		end
		return Assets[AssetCatagory][AssetName]
	end
	CharacterClassSystem.GetAsset = GetAsset

	local function GetClassSelectorList(ClassName)
		-- return's the class with the name of `ClassName` or nil from ClassSelectorList 

		return ClassSelectorList[ClassName]
	end

	local function GetAssetCatagory(AssetCatagory)
		-- Return's the table of assets. 

		return Assets[AssetCatagory]
	end

	local function GetHandler(HandlerName)
		-- Return's a 'HandlerClass' for a specific name..

		local Handler = Handlers[HandlerName]
		if Handler then
			return Handler
		else
			error("[CharacterClassSystem] - Could not find Handler for '" .. HandlerName .. "'")
			return nil
		end
	end

	local function GetFirstItemWithoutHandler(Bin, SearchingForItemName)
		-- Return's an item from the bin with the name of 'SearchingForItemName', but ignoring handlers. So...
		-- if 'SearchingForItemName' is 'HarryPotter', and in the bin, there's an item called 'Catagory:HarryPotter', it'll
		-- return that guy. 

		for _, Item in pairs(Bin:GetChildren()) do
			local Position = string.find(Name, Configuration.Seperator)
			if Position then
				local ItemName = string.sub(Position+1, #Name)
				if ItemName == SearchingForItemName then
					return Item
				end
			else
				error("[CharacterClassSystem] - Could not extract name for '" .. Item.Name .. "'")
			end
		end
	end

	local function GenerateMenu(MenusList, WorldObject, Name)
		-- Returns a menu, DoSetupButtons

		if MenusList[WorldObject] then
			return MenusList[WorldObject], false
		else
			local CatagoryMenu = MenuSystem.MakeListMenuLevel(Name)
			CatagoryMenu.ButtonEnter:connect(function(Button)
				SoundPlayer.PlaySound("Tick", 0.5)
			end)
			MenusList[WorldObject] = CatagoryMenu
			return CatagoryMenu, true
		end
	end

	--[==[local function SelectItem(ItemName)
		-- Set's the BeingEditedStack[#BeingEditedStack].Configuration

		--[[

			Semi-Pseudo code notes:

			MenuLayers = {
				[0] = Home
				[1] = Class - Select this (Go to 0) - Can also be edited
				[2] = CCCatagory - Select this TO be edited
				[3] = Catagory
				[4] = CustomGun - Select this (Go to 2) - 
				[5] = CustomGunPart  - Select this (Go to 4)
			}

			When you select an item, the item being edited stays the same. 
			When you select something to be edited, it'll change values inside of the edit item. 
			When you finish editing, then it'll go back to the previous edited item.  

			So we can kindly disregard anything but the top 'Edited' thing, because it's considered a seperate modular. 

		--]]

		local LastEdited = BeingEditedStack[#BeingEditedStack]
		local EditValue = LastEdited.Configuration:FindFirstChild(ItemName)

		if not EditValue then
			error("[CharacterClassSystem] - Could not find '" .. ItemName .. "' in the configuration of "..LastEdited.WorldObject:GetFullName())
		elseif not EditValue:IsA("StringValue") then
			error("[CharacterClassSystem] - Malformed EditValue @ "..EditValue:GetFullName());
		else
			EditValue.Value = ItemName
		end
	end
	--]==]

	local function SetupConnectionsOnSelector(Button, ClassName, AssignValue)
		-- Set's up a selector for a button (So you might select your class, or your gun, or something.)
		-- The main different between this and a standard handler is that it's editing a external change, 
		-- versus an interal one.  

		-- ClassName - Name of what's being edited, probably `Classes` or `Guns`
		-- AssignValue - The value it'll set to whatever is selected...

		local Class = GetClassSelectorList(ClassName)

		if Class then
			local ClassSelectionMenu = MenuSystem.MakeListMenuLevel(Class.RenderName)


			for _, Item in pairs(Class.Available) do -- For each of the availible classes, such as "Sniper", "Custom I" do
				if Item and Item:IsA("Configuration") then -- Make sure it can be editable/saved in..
					local HandlerName, ItemName = ExtractNames(Item.Name) -- Find out what they're saving. :D
					if HandlerName and ItemName then 
						local Button = ClassSelectionMenu:AddMenuButton(ItemName)
						SetupButton(Button, Item, NewMenu)
					else
						error("[CharacterClassSystem] - HanderName is '" .. tostring(HandlerName) .. "' and ItemName is '" .. tostring(ItemName) .. "', one is nil/false, error for "..Item:GetFullName())
					end
				end
			end

			Button.OnClick:connect(function()
				print("[CharacterClassSystem] - Click on class button for class '"..ClassName.."'")
				BeingEditedStack[#BeingEditedStack+1] = { -- Ok. My datastructures are screwed up. :/
					ClassSelector = true;
					AssignValue = AssignValue; -- String value that'll get changed to the newly selected item.
					Level = NewMenu.CurrentLevel+1;
				}

				SelectorBeingEditedStack[#SelectorBeingEditedStack + 1] = {
					Class = Class;
					Name = ClassName;
					Level = NewMenu.CurrentLevel+1;
				}

				NewMenu:AddMenuLayer(ClassSelectionMenu)
			end)
		else
			error("[CharacterClassSystem] - Could not get selector class '" .. tostring(ClassName) .."' so could not setup connections on button...")
		end
	end
	CharacterClassSystem.SetupConnectionsOnSelector = SetupConnectionsOnSelector


	Handlers = {
		Class = {
			-- The class Handler is the first level of handlers. 
			Menus = {}; -- *Cringes*
			OnClick = function(CharacterClassSystem, Handler, Menu, WorldObject)
				-- Reset when they select a class...  Also fire off the change, so the parent class can
				-- identify the new class...

				if not BeingEditedStack[#BeingEditedStack] then
					error("BeingEditedStack[#BeingEditedStack] should not be nil, expected ClassSelector")
				elseif not BeingEditedStack[#BeingEditedStack].ClassSelector then
					error("[CharacterClassSystem] - ClassSelector expected in BeingEditedStack[" .. #BeingEditedStack .." failed to receive it.")
				end

				
				local HandlerName, ItemName = ExtractNames(WorldObject.Name)
				local SelectorClass = SelectorBeingEditedStack[#SelectorBeingEditedStack]
				local BeingEdited = BeingEditedStack[#BeingEditedStack]
				if ItemName then
					BeingEdited.AssignValue.Value = ItemName
					if SelectorBeingEditedStack[#SelectorBeingEditedStack-1] then
						Menu:SetLevel(SelectorBeingEditedStack[#SelectorBeingEditedStack-1].Level)
					else
						Menu:GoToHome()
					end
				else
					error("[CharacterClassSystem] [Class] - Could not extract the name of WorldObject,")
				end
			end;
			OnEdit = function(CharacterClassSystem, Handler, Menu, WorldObject)
				print("[CharacterClassSystem] [Class] - Editing '"..WorldObject.Name.."'")

				-- Editing a custom class. :D The WorldObject, will be organized like this:
				--[[

					Configuration `Custom Class I`
						| StringValue `Primary Weapon`    -- Pointer
						| StringValue `Secondary Weapon`  -- Pointer too... 
						| StringValue `Perk I`
						| StringValue `Perk II`
						| StringValue `Perk III`
						| StringValue `Primary Grenade`
						| StringValue `Body Armour`
				--]]

				--[[if #BeingEditedStack >= 1 then 
					error("[CharacterClassSystem] - Stack should have nothing being edited in it right now")
				end--]]
				--BeingEditedStack = {}

				local HandlerName, ItemName = ExtractNames(WorldObject.Name)
				BeingEditedStack[#BeingEditedStack+1] = {
					WorldObject = WorldObject;
					Configuration = WorldObject; -- The configuration where the next layer will dictate.  (The next selected item)
					Level = Menu.CurrentLevel+1;
					Type = Handler.Name;
					Name = ItemName;
					ClassSelector = false;
				}
				
				local CatagoryMenu, DoSetupButtons = GenerateMenu(Handler.Menus, WorldObject, ItemName)
				if DoSetupButtons then
					print("[CharacterClassSystem] - Setting up buttons for Class "..WorldObject.Name.." WorldObject:GetChildren() = "..(#WorldObject:GetChildren()))
					for _, Item in pairs(WorldObject:GetChildren()) do
						print("[CharacterClassSystem] - Adding Button for CCCatagory " .. Item:GetFullName())
						local AssetCatagoryName = Item.Name
						local AssetName = Item.Value
						local AssetsModel = GetAsset(AssetCatagoryName, AssetName) -- Get the CCCatagory:AssetName
						if AssetsModel then
							local CCCatagory = GetCCCatagoryModel(AssetsModel)
							if CCCatagory then
								local Button = MenuSystem.MakeMenuButton(Item.Name)
								SetupButton(Button, CCCatagory, Menu)

								CatagoryMenu:AddRawButton(Button)
							elseif 
							else
								error("[CharacterClassSystem] - Default Asset's doesn't seem to be a descendent of a CCCatagory, unable to setup button.")
							end
						else
							print("[CharacterClassSystem] - Assets = " .. PenlightPretty.TableToString(Assets))
							error("[CharacterClassSystem] - No asset in 'Assets["..AssetCatagoryName.."]' available, could not find '"..AssetName.."' in it")
						end
					end
				end
				Menu:AddMenuLayer(CatagoryMenu)
			end;
			CanEdit = function(CharacterClassSystem, Handler, Menu, WorldObject)
				-- Returns whether or not the class can be edited.

				for _, Class in pairs(ClassSelectorList) do
					for _, Item in pairs(Class.Editable) do
						if Item == WorldObject then
							--print("[CharacterClassSystem] - Approved "..WorldObject:GetFullName() .. " for editing.")
							return true
						end
					end
				end
				--print("[CharacterClassSystem] - Rejected "..WorldObject:GetFullName() .. " for editing.")
				return false
			end;
		};
		CCCatagory = { -- Exactly like a catagory, except it set's the LastEdited too. The configuration will be the same. 
			Menus = {};
			OnClick = function(CharacterClassSystem, Handler, Menu, WorldObject)
				-- Will be clicked after BeingEditedStack[1] or higher has been set.  

				if #BeingEditedStack <= 0 then -- Make sure there's something _to_ edit.
					error("[CharacterClassSystem] [CCCatagory] - Stack should have a 'Class' being edited in it...")
				elseif BeingEditedStack[#BeingEditedStack].ClassSelector then -- Make sure we're editing the right thing..
					error("[CharacterClassSystem] [CCCatagory] - Editing ClassSelector, which can't have Catagories, BeingEditedStack[#BeingEditedStack].ClassSelector = true")
				end

				local _, ItemName = ExtractNames(WorldObject.Name)

				print("[CharacterClassSystem] [CCCatagory] - Editing " .. ItemName .." CCCatagroy")

				BeingEditedStack[#BeingEditedStack + 1] = {
					WorldObject = WorldObject;
					Configuration = BeingEditedStack[#BeingEditedStack].Configuration;
					Level = Menu.CurrentLevel + 1;
					Type = Handler.Name;
					Name = ItemName;
				}

				local CatagoryMenu, DoSetupButtons = GenerateMenu(Handler.Menus, WorldObject, ItemName)

				print("[CharacterClassSystem] [CCCatagory] - #BeingEditedStack = " .. (#BeingEditedStack))
				if DoSetupButtons then
					for _, Item in pairs(WorldObject:GetChildren()) do -- For each item in the CCCatagory (Model) do
						print("[CharacterClassSystem] [CCCatagory] - Generating button for "..Item.Name)
						local HandlerType, LocalItemName = ExtractNames(Item.Name)
						local HandlerTypeLower = HandlerType:lower()

						print("[CharacterClassSystem] - ClassSelectorList["..HandlerType.."] = "..tostring(ClassSelectorList[HandlerType]))
						if GetClassSelectorList(HandlerType) then
							print("[CharacterClassSystem] [CCCatagory]- Generating Button for new CatagorySelector `"..LocalItemName.."`")
							local Value = BeingEditedStack[#BeingEditedStack-1].Configuration:FindFirstChild(ItemName)
							-- We can do the above line because we know that BeingEditedStack[#BeingEditedStack-1] has to be a ClassSelector

							if Value then
								local Button = MenuSystem.MakeMenuButton(LocalItemName)
								SetupConnectionsOnSelector(Button, HandlerType, Value)
								CatagoryMenu:AddRawButton(Button)
							else
								error("[CharacterClassSystem] [CCCatagory] - Could not get Value from... @ "..BeingEditedStack[#BeingEditedStack-1].Configuration:GetFullName())
							end
						elseif (HandlerTypeLower == "selector" or HandlerTypeLower == "catagory") then
							local Button = MenuSystem.MakeMenuButton(LocalItemName)
							SetupButton(Button, Item, Menu)
							CatagoryMenu:AddRawButton(Button)
						else
							error("[CharacterClassSystem] [CCCatagory] - Invalid Item/Malformatted Item @ "..Item:GetFullName())
						end
					end
				end
				Menu:AddMenuLayer(CatagoryMenu)
				print("[CharacterClassSystem] [CCCatagory] - Opened new CCCCatagory... Class '"..WorldObject.Name.."'")
			end;
		};
		Catagory = { -- Used in "Editing" only. 
			Menus = {};
			OnClick = function(CharacterClassSystem, Handler, Menu, WorldObject)
				local HandlerType, ItemName = ExtractNames(WorldObject.Name)
				local CatagoryMenu, DoSetupButtons = GenerateMenu(Handler.Menus, WorldObject, ItemName)

				if #BeingEditedStack <= 0 then -- Make sure there's something _to_ edit.
					error("[CharacterClassSystem] [Catagory] - Stack should have a 'Class' being edited in it...")
				elseif BeingEditedStack[#BeingEditedStack].ClassSelector then -- Make sure we're editing the right thing..
					error("[CharacterClassSystem] [Catagory] - Editing ClassSelector, which can't have Catagories, BeingEditedStack[#BeingEditedStack].ClassSelector = true")
				end

				if DoSetupButtons then
					for _, Item in pairs(WorldObject:GetChildren()) do
						local LocalHandlerType, LocalItemName = ExtractNames(Item.Name)
						LocalHandlerType = LocalHandlerType:lower()
						if (LocalHandlerType == "selector" or LocalHandlerType == "catagory") then -- Got to make sure it's either a Selector or another Catagory...
							local Button = MenuSystem.MakeMenuButton(LocalItemName)
							SetupButton(Button, Item, Menu)
							CatagoryMenu:AddRawButton(Button)
						elseif GetClassSelectorList(LocalHandlerType) then -- Customization time -  Rock'en roll
							local Value = BeingEditedStack[#BeingEditedStack-1].Configuration:FindFirstChild(ItemName)

							local Button = MenuSystem.MakeMenuButton(LocalItemName)
							if Value then
								local Button = MenuSystem.MakeMenuButton(LocalItemName)
								SetupConnectionsOnSelector(Button, HandlerType, Value)
								CatagoryMenu:AddRawButton(Button)
							else
								error("[CharacterClassSystem] [CCCatagory] - Could not get Value from... @ "..BeingEditedStack[#BeingEditedStack-1].Configuration:GetFullName())
							end
						else
							error("[CharacterClassSystem] [Catagory] - Invalid Item/Malformatted Item @ "..Item:GetFullName())
						end
					end
				end
				Menu:AddMenuLayer(CatagoryMenu)
				print("[CharacterClassSystem] [Catagory] - Opened new Catagory... Class '"..WorldObject.Name.."'")
			end;
		};
		Selector = {
			OnClick = function(CharacterClassSystem, Handler, Menu, WorldObject)
				-- When something is selected, go back to the last catagory / being edited stack node, of course, after changing the value inside of it. 
				
				if #BeingEditedStack <= 0 then -- Make sure there's something _to_ edit.
					error("[CharacterClassSystem] [Selector] - Stack should have a 'Class' being edited in it...")
				elseif BeingEditedStack[#BeingEditedStack].ClassSelector then -- Make sure we're editing the right thing..
					error("[CharacterClassSystem] [Selector] - Editing ClassSelector, which can't have selectors, BeingEditedStack[#BeingEditedStack].ClassSelector = true")
				end

				local BeingEdited = BeingEditedStack[#BeingEditedStack]
				local Value = BeingEdited.Configuration:FindFirstChild(BeingEdited.Name)

				local HandlerType, ItemName = ExtractNames(WorldObject.Name)

				if Value then
					Value.Value = ItemName;
					print("[CharacterClassSystem] [Selector] - Set "..Value:GetFullName())
				else
					error("[CharacterClassSystem] [Selector] - Could not get '" .. BeingEdited.Type .. "' @ "..BeingEdited.Configuration:GetFullName() .. " on selector")
				end
				print("[CharacterClassSystem] [Selector] - BeingedEdited.Level = "..tostring(BeingEdited.Level) .. " and Menu.CurrentLevel = " .. tostring(Menu.CurrentLevel))
				Menu.SetLevel(BeingEdited.Level-1) 
			end;
		};
	}
	Handlers.ModularGun = Handlers.Class 
	Handlers.PlayerClass = Handlers.Class

	for HandlerName, Handler in pairs(Handlers) do
		-- Just add the HandlerName into the item for reference.
		Handler.Name = HandlerName
	end

	function SetupButton(Button, WorldItem, Menu)
		-- Setup's a standard button to connections so it can 
		-- be hooked up to a Handler when it's clicked..

		local HandlerName, ItemName = ExtractNames(WorldItem.Name)
		if HandlerName and ItemName then
			print("[CharacterClassSystem] - Setting up "..WorldItem:GetFullName())
			local Handler = GetHandler(HandlerName)

			if not Handler then
				error("[CharacterClassSystem] - Could not find handler for '" .. tostring(HandlerName) .. "'")
			else
				local EditButton

				if Handler.OnEdit then
					if Handler.CanEdit then
						print("[CharacterClassSystem] - Rendering edit button")

						EditButton = Make 'TextButton' {
							Name = "EditButton";
							Size = UDim2.new(0.3, 0, 1, 0);
							Position = UDim2.new(0.7, 0, 0, 0);
							Text = "Edit";
							ZIndex = 5;
							FontSize = "Size8";
							TextColor3 = Color3.new(1,1,1);
							BackgroundTransparency = 1;
							Parent = Button.Gui;
							Visible = false
						}

						EditButton.MouseButton1Down:connect(function()
							Handler.OnEdit(CharacterClassSystem, Handler, Menu, WorldItem)
						end)
					end
				end

				Button.OnClick:connect(function()
					print("[CharacterClassSystem] - Click on " .. WorldItem.Name)
					if Handler.OnClick then
						Handler.OnClick(CharacterClassSystem, Handler, Menu, WorldItem)
					end
				end)

				if EditButton and Handler.CanEdit(CharacterClassSystem, Handler, Menu, WorldItem) then
					Button.OnEnter:connect(function()
						--print("[CharacterClassSystem] - Showing edit button")
						EditButton.Visible = true
						EditButton.Parent = Button.Gui;
					end)

					Button.OnLeave:connect(function()
						if EditButton then
							--print("[CharacterClassSystem] - Hiding edit button")
							EditButton.Visible = false
						end
					end)
				end
			end
		else
			error("[CharacterClassSystem] - HanderName = '" .. tostring(HandlerName) .. "' and ItemName = '" .. tostring(ItemName) .. "', one is nil/false, error for "..WorldItem:GetFullName())
		end
	end


	--[[NewMenu.GoingHome:connect(function()
		for i=1, #BeingEditedStack do
			BeingEditedStack:Pop();
		end
		print("[CharacterClassSystem] - #BeingEditedStack = "..(#BeingEditedStack)))
	end)--]]

	NewMenu.LevelUpper:connect(function(Level) -- Remove / Pop the editing items when we go backwards.
		-- Level is the new level that will be appearing shortly

		if #BeingEditedStack >= 1 then
			for Index = #BeingEditedStack, 1, -1 do
				if Level < (BeingEditedStack[Index].Level) then
					print("[CharacterClassSystem] - LevelUpper - Popping BeingEditedStack " .. Index  .. " Level ("..Level..") <= BeingEditedStack[Index].Level ("..BeingEditedStack[Index].Level..")")
					BeingEditedStack[#BeingEditedStack] = nil
				end
			end
		end

		if #SelectorBeingEditedStack >= 1 then
			for Index = #SelectorBeingEditedStack, 1, -1 do
				if Level < (SelectorBeingEditedStack[#SelectorBeingEditedStack].Level) then
					print("[CharacterClassSystem] - LevelUpper - Popping SelectorBeingEditedStack " .. Index  .. " Level ("..Level..") <= SelectorBeingEditedStack[Index].Level ("..SelectorBeingEditedStack[Index].Level..")")
					SelectorBeingEditedStack[#SelectorBeingEditedStack] = nil
				end
			end
		end

		print("[CharacterClassSystem] - LevelUpper - #BeingEditedStack = "..(#BeingEditedStack))
		print("[CharacterClassSystem] - LevelUpper - #SelectorBeingEditedStack = "..(#SelectorBeingEditedStack))
	end)

	
end)
lib.MakeCharacterClassSystem = MakeCharacterClassSystem

NevermoreEngine.RegisterLibrary('CharacterClass', lib);