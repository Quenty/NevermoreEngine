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
local qInstance         = LoadCustomLibrary('qInstance')
local Table             = LoadCustomLibrary('Table')

qSystems:Import(getfenv(0));

local lib = {}

local MakeListInventory = Make 'ListInventory' (function(ListInventory, ItemSystem, Configuration)
	-- A ListInventory is an inventory that is a list (Like Skyrim, no?)...  It'll handle adding, removing, et. cetera.
	-- Does not handle rendering...

	Configuration = Configuration or {}
	Configuration.MaxCummulativeItemValue = Configuration.MaxCummulativeItemValue or 10;
	Configuration.GetItemValue = Configuration.GetItemValue or function(Item) return 1 end;

	local Items = {}

	ListInventory.ItemAdded = MakeSignal(); -- Fired when an Item is added. 
	ListInventory.ItemRemoved = MakeSignal(); -- Fired when an item is removed.
	ListInventory.Sorted = MakeSignal(); -- Fired when the inventory is sorted. Generally indicates a re-rendering...

	local InventoryValue = 0;

	local function Sort(Items, GetValue)
		-- Sorts the Inventory, based on GetValue...

		GetValue = GetValue or Configuration.GetItemValue;
		Table.ShellSort(Items, GetValue)
		ListInventory.Sorted:Fire()
	end
	ListInventory.Sort = Sort;
	ListInventory.sort = Sort;

	local function AddItem(Item)
		-- Checks to see ifan Item 'Can' be added. 

		local ItemValue = Configuration.GetItemValue(Item)
		if InventoryValue + ItemValue <= Configuration.MaxCummulativeItemValue then
			Items[#Items+1] = Item;
			InventoryValue = InventoryValue + ItemValue;

			ListInventory.ItemAdded:Fire(Item);
			return true;
		else
			return false;
		end
	end
	ListInventory.AddItem = AddItem;
	ListInventory.addItem = AddItem;
	ListInventory.Add = AddItem;

	local function CanAdd(Item)
		-- Return's if an Item can be added, and how much more 'Value' the inventory requires to add the item..

		local ItemValue = Configuration.GetItemValue(Item)
		if InventoryValue + ItemValue <= Configuration.MaxCummulativeItemValue then
			return true, 0;
		else
			return false, (InventoryValue + ItemValue) - Configuration.MaxCummulativeItemValue;
		end
	end
	ListInventory.CanAdd = CanAdd;
	ListInventory.canAdd = CanAdd;

	local function GetContents()
		-- Return's the inventories contents...
		return Items;
	end
	ListInventory.GetContents = GetContents;
	ListInventory.getContents = GetContents

	local function RemoveItem(ItemToRemove)
		-- Remoevs an item from the inventory....

		local RemovedIndex
		local ItemCount = #Items
		for Index, Item in pairs(Items) do
			if Item == ItemToRemove then
				table.remove(Items, Index)
				ListInventory.ItemRemoved:Fire()
				break;
			end
		end
	end
	ListInventory.RemoveItem = RemoveItem
	ListInventory.removeItem = RemoveItem

end)
lib.MakeListInventory = MakeListInventory
lib.makeListInventory = MakeListInventory

local function GenerateObjectData(Objects)
	-- Given a table of 'Objects', it'll find the most common material, average color, volume, and 
	-- the part of the most common material that is also the largest. 

	-- It is all scaled to Volume per part. 

	local VolumeListByMaterial = {};

	local PartToVolumeList = {}
	local MaterialToPartList = {};

	local WeightedColor = Vector3.new();
	local TotalVolume = Vector3.new()

	-- Go through each object and calculate results cumulatively
	for _, Child in pairs(Objects) do
		if Child:IsA("BasePart") then
			local Material = Child.Material
			local Volume = Child.Size.x * Child.Size.y * Child.Size.z
			local Color = Vector3.new(Child.BrickColor.Color.r, Child.BrickColor.Color.g, Child.BrickColor.Color.b)
			VolumeListByMaterial[Material] = (VolumeListByMaterial[Material] or 0) + Volume
			WeightedColor = WeightedColor + Color*Volume;
			TotalVolume = TotalVolume + Volume;
			PartToVolumeList[Child] = Volume;
			if MaterialToPartList[Material] and PartToVolumeList[MaterialToPartList[Material]] > Volume then
				MaterialToPartList[Material] = Child;
			end
		end
	end
	-- Average out the Color
	local Color = BrickColor.new(Color3.new(WeightedColor.x, WeightedColor.y, WeightedColor.z))

	-- Find the largest material possible
	local LargestMaterial = Enum.Material.Plastic;
	local LargestMaterialVolume = 0;
	for Material, Volume in pairs(VolumeListByMaterial) do
		if Volume > LargestMaterialVolume then
			LargestMaterial = Material;
			LargestMaterialVolume = Volume;
		end
	end

	-- Return all values.
	return LargestMaterial, Color, Volume, MaterialToPartList[LargestMaterial];
end
lib.GenerateObjectData = GenerateObjectData
lib.generateObjectData = GenerateObjectData

local MakeBoxInventory = Make 'BoxInventory' (function(BoxInventory, MainPart, GridSize)
	--[[
	This system needs to handle several things.  First of all, the inventory needs to be accessible as a 
	list.  This list needs to be sortable.  

	Secondly, this inventory, as the name impiles, will limit objects based on their physical 'box' size. That is
	all items will have a 3D model, and will a genearl Color, Volume, and Material will be 
	--]]


	local ItemGrid = {}
	local MultipleOf = 2;
	GridSize = GridSize or (MultipleOf*MultipleOf); -- Should be a MultipleOf^x, so 2, 4, 8, et cetera if MultipleOf = 2;
	do
		local Size = MainPart.Size;
		local SizeX, SizeY, SizeZ = math.floor(MainPart.Size.X / MultipleOf) * MultipleOf,
		                            math.floor(MainPart.Size.Y / MultipleOf) * MultipleOf,
		                            math.floor(MainPart.Size.Z / MultipleOf) * MultipleOf

		
		local function GenerateGrid(SizeX, SizeY, SizeZ)
			local Grid = {}
			for X = 1, SizeX do
				Grid[X] = {};
				for Y = 1, SizeY do
					Grid[X][Y] = {};
					for Z = 1, SizeZ do
						Grid[X][Y][Z] = {};
					end
				end
			end
			return Grid;
		end

		ItemGrid.Grid = GenerateGrid;
	end

	BoxInventory.ItemAdded = CreateSignal();

	local function AddItem(Item)
		--'Item' is an InventoryObject item...
		local Bricks = qInstance.GetBricks(Item)

	end
end)
lib.MakeBoxInventory = MakeBoxInventory
lib.makeBoxInventory = MakeBoxInventory

NevermoreEngine.RegisterLibrary('InventorySystems', lib)
