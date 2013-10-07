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
local qCFrame           = LoadCustomLibrary('qCFrame')

qSystems:Import(getfenv(0));

local lib = {}

local MakeListInventory = Class 'ListInventory' (function(ListInventory, ItemSystem, Configuration)
	-- A ListInventory is an inventory that is a list (Like Skyrim, no?)...  It'll handle adding, removing, et. cetera.
	-- Does not handle rendering...

	-- Untested. 

	Configuration = Configuration or {}
	Configuration.MaxCummulativeItemValue = Configuration.MaxCummulativeItemValue or 10;
	Configuration.GetItemValue = Configuration.GetItemValue or function(Item) return 1 end;

	local Items = {}

	ListInventory.ItemAdded = CreateSignal(); -- Fired when an Item is added. 
	ListInventory.ItemRemoved = CreateSignal(); -- Fired when an item is removed.
	ListInventory.Sorted = CreateSignal(); -- Fired when the inventory is sorted. Generally indicates a re-rendering...

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



local function GetMaxGridSizeFromSmallestSide(SmallestSide)
	local Index = 0 
	local SideSize 
	repeat 
		Index = Index + 1 
		SideSize = 2^Index 
	until SideSize > SmallestSide 
	return 2^(Index-1)
end

local function ConvertScaledGridsizeToLinearGridsizePartSize(PartSize, GridSize)
	-- Used when generating grids, et cetera
	-- PartSize is a Vector3, GridSize is a number (Probably 2)

	-- GridSize is quadratic, but converted to linear

	return Vector3.new((math.log(PartSize.X) / math.log(GridSize)), (math.log(PartSize.X) / math.log(GridSize)), (math.log(PartSize.X) / math.log(GridSize)));
end;

local function ScaledGridsizeToLinear(GridSize, GridSizePowerOf)
	GridSizePowerOf = GridSizePowerOf or 2;
	return math.log(GridSize) / math.log(GridSizePowerOf);
end

local function GetSmallestSide(PartSize)
	-- Return's the smallest side in a part.

	return math.min(PartSize.X, math.min(PartSize.Y, PartSize.Z));
end

local function SideLengthFromVolume(PartVolume)
	-- Based upon volume, returns the appropriate shipping crate side length 
	-- (All shipping crates are squares)

	local Index = 0 
	local Volume 
	repeat 
		Index = Index + 1 
		Volume = (2^Index)^3 
	until Volume > PartVolume 
	return 2^(Index-1)
end

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
	local CrateData = {}
	CrateData.MostCommonMaterial = LargestMaterial;
	CrateData.BrickColor = Color;
	CrateData.Volume = Volume;
	CrateData.MaterialToPartList = MaterialToPartList[LargestMaterial];
	CrateData.CrateSideLength = SideLengthFromVolume(Volume);

	return CrateData;
end

local function VoxelPairs(VoxelGrid)
	-- Prefer Y, then X, then Z
	-- So first return all the content on the yLevel, that is, 1 and up...

	local Content = VoxelGrid.Content
	local CurrentX = 1;
	local CurrentY = 1;
	local TargetY = #(Content[1]);
	local CurrentZ = 1;

	return function()
		local Slot, FaultAt
		while CurrentY <= TargetY do
			Slot, FaultAt = Content:GetSlot(CurrentX, CurrentY, CurrentZ)
			if Slot then
				CurrentX = CurrentX + 1
				return Slot;
			elseif FaultAt == "x" then
				CurrentZ = CurrentZ + 1
				CurrentX = 1;
			elseif FaultAt == "z" then
				CurrentY = CurrentY + 1;
				CurrentX = 1;
				CurrentZ = 1;
			elseif FaultAt == "y" then
				return nil;
			end
		end
		return nil;
	end
end
lib.VoxelPairs = VoxelPairs
lib.voxelPairs = VoxelPairs

local VoxelGridMetatable = {
	__index = {
		GetSlot = function(self, X, Y, Z)
			-- Return's the slot at X, Y, Z
			local Content = self;
			if type(X) ~= "number" then -- Must be Vector3
				X, Y, Z = X.x, X.y,X.z
			end

			if Content[X] ~= nil then
				if Content[X][Y] ~= nil then
					if Content[X][Y][Z] ~= nil then
						return Content[X][Y][Z];
					else
						return nil, "z";
					end
				else
					return nil, "y";
				end
			else
				return nil, "x"
			end
			return nil;
		end;
	};
}

local function SlotRelativeCFrameFromVector(BaseCFrame, SlotPosition, SlotSize, GridSize)
	-- Return's relative CFrame from BaseCFrame and Vector position and Size and Vector GridSize (Slots X, Y, Z)

	-- Gridsize is quadratic

	SlotPosition = SlotPosition * SlotSize
	return BaseCFrame * CFrame.new(SlotPosition - (GridSize * SlotSize)/2)
end

local function GenerateVoxelGrid(GridSize, ItemSize, Center)
	-- Generates a 3D array 

	-- GridSize is linear (And a vector)
	-- ItemSize, as always, is scalar...

	local SizeX, SizeY, SizeZ = GridSize.X, GridSize.Y, GridSize.Z

	local VoxelGrid = {}
	for X = 1, SizeX do
		VoxelGrid[X] = {};
		for Y = 1, SizeY do
			VoxelGrid[X][Y] = {};
			for Z = 1, SizeZ do
				local Slot = {
					Type = "Slot";
					-- Content = nil;
					Size = ItemSize;
					LocalPosition = Vector3.new(X, Y, Z);
					VoxelGrid = VoxelGrid;
				};
				Slot.RelativeCFrame = SlotRelativeCFrameFromVector(Center, Slot.LocalPosition, ItemSize, GridSize)
				VoxelGrid[X][Y][Z] = Slot
			end
		end
	end
	setmetatable(VoxelGrid, VoxelGridMetatable)

	return VoxelGrid;
end

local function MakeVoxelGrid(Center, PartCFrame, GridSize, ItemSize)
	--- Makes a new VoxelGrid, aka a storage slot...

	-- GridSize is linear.
	-- ItemSize is scalar. 
	
	local ItemGrid = {}
	ItemGrid.Type           = "Voxel";
	ItemGrid.Size           = GridSize;
	ItemGrid.Content        = GenerateVoxelGrid(Vector3.new(GridSize, GridSize, GridSize), ItemSize, PartCFrame); -- Convert gridsize to scalar. 
	ItemGrid.RelativeCFrame = Center:Inverse() * PartCFrame; -- Better hope we're anchored and not moving...
	-- ItemGrid.VoxelPart = nil
	return ItemGrid;
end

local LookForEmptySlotInVoxelGrid
function LookForEmptySlotInVoxelGrid(VoxelGrid, CrateData, DoNotRecurse)
	-- Search's for an empty slot in the voxel grid with the same size as the crate data, or recurses down...

	if VoxelGrid.Size == CrateData.Size then
		for Slot in VoxelPairs(VoxelGrid) do
			if Slot.Content and Slot.Content.Type ~= "Voxel" then
				return Slot;
			end
		end
	elseif VoxelGrid.Size < CrateData.Size then
		for Slot in VoxelPairs(VoxelGrid) do
			if Slot.Content and Slot.Content.Type == "Voxel" then
				return LookForEmptySlotInVoxelGrid(Slot.Content, CrateData);
			elseif VoxelGrid.Size >= 2 then -- Smallest size is 1?
				Slot.Content = MakeVoxelGrid(Center, Slot.RelativeCFrame, VoxelGrid.Size - 1)
				if not DoNotRecurse then
					return LookForEmptySlotInVoxelGrid(Slot.Content, CrateData);
				end
				return nil;
			else
				return nil;
			end
		end
	else
		return nil;
	end
end

local function GetVoxelPart(Slot)
	-- Goes up and get's the VoxelPart on the top for welding, et cetera.

	local VoxelPart = Slot.VoxelGrid.VoxelPart
	while not VoxelPart do
		
	end
	return VoxelPart;
end
local MakeBoxInventory = Class 'BoxInventory' (function(BoxInventory)
	--[[
	This system needs to handle several things.  First of all, the inventory needs to be accessible as a 
	list.  This list needs to be sortable.  

	Secondly, this inventory, as the name implies, will limit objects based on their physical 'box' size. That is
	all items will have a 3D model, and will a general Color, Volume, and Material will be 
	--]]

	local StorageSpaces = {}
	--[[
		Super complex data structure...

		StorageSpaces
			VoxelGrid
				Type = "Voxel"
				Size = GridSize (Linear)
				RelativeCFrame
				Content = {}[X][Y][Z] (Slots)
					Slot can contain...

					VoxelGrid
						...
					InventoryItem
						Interfaces
							BoxInventory
								CrateData	
							...
						Type = nil

					
		StorageSpaces[1].Content[X][Y][Z].Slot.Content[X][Y][Z].Content.Interfaces.BoxInventory.CrateData.Volume -- Potental line...

	--]]
	local Center

	BoxInventory.ItemAdded = CreateSignal();
	BoxInventory.ItemRemoved = CreateSignal();
	BoxInventory.StorageSlotAdded = CreateSignal(); 
	BoxInventory.CrateSlotChanged = CreateSignal();
	local StorageSpaces = StorageSpaces;

	local function AddStorageSlot(Part)
		-- Add a brick into the storage slot...

		Center = Center or Part.CFrame;
		local GridSize = GetMaxGridSizeFromSmallestSide(GetSmallestSide(Part.Size))
		GridSize = ScaledGridsizeToLinear(GridSize);
		StorageSpaces[#StorageSpaces+1] = MakeVoxelGrid(Center, Part.CFrame, GridSize);
		StorageSpaces[#StorageSpaces].VoxelPart = Part;
		BoxInventory.StorageSlotAdded:fire(StorageSpaces[#StorageSpaces], Part)
	end
	BoxInventory.AddStorageSlot = AddStorageSlot
	BoxInventory.addStorageSlot = AddStorageSlot

	local function GetStorageSlots()
		-- Return's storage slots
		return StorageSpaces;
	end

	local function ComputeSlotWeight(Slot)
		-- Weights a slot's value...
		--[[
		Weight by: 
		    100000 : Has solid content
			Also factor in volume / 100
		--]]

		local Weight = 0
		if Slot.Content then
			if Slot.Content.Type == nil then -- Must be an inventory item..
				if Slot.Content.Interfaces.BoxInventory.Weight then
					return Slot.Content.Interfaces.BoxInventory.Weight
				else
					Weight = Weight + 1000000; -- Add for being solid...
					Weight = Weight + (Slot.Content.Interfaces.BoxInventory.CrateData.Volume / 100);

					-- Cache data...
					Slot.Content.Interfaces.BoxInventory.Weight = Weight
					return Weight
				end
			else
				error("[BoxInventory] - Could not identify/weigh slot @ "..Slot.Content.Type)
			end
		else
			return 0 -- No content..
		end
	end

	local function SimpleSort(VoxelGrid)
		-- Simply shifts stuff down and around, for use only when adding new items...

		local SlotList = {}
		local Weight = {}
		for Slot in VoxelPairs(VoxelGrid) do
			if Slot.Content and Slot.Content.Type == nil then
				SlotList[#SlotList+1] = Slot;
				Weight[Slot] = ComputeSlotWeight(Slot);
			end
		end

		Table.ShellSort(SlotList, (function(Slot) return Weight[Slot] end))
		local CurrentIndex = 1
		for Slot in VoxelPairs(VoxelGrid) do
			if SlotList[CurrentIndex] then
				if SlotList[CurrentIndex] ~= Slot.Content then
					OldSlot = SlotList[CurrentIndex].CurrentSlot
					Slot.Content = SlotList[CurrentIndex]
					SlotList[CurrentIndex].Interfaces.BoxInventory.CurrentSlot = Slot;
					BoxInventory.CrateSlotChanged:fire(SlotList[CurrentIndex], Slot, OldSlot)
				end
			else
				Slot.Content = nil;
			end
			CurrentIndex = CurrentIndex + 1;
		end
	end

	local function GetListOfItems()
		-- Return's a list of all the items in the inventory at the time...

		local List = {}
		local Recurse
		function Recurse(VoxelGrid)
			for Slot in VoxelPairs(VoxelGrid) do
				if Slot.Content then
					if Slot.Content.Type == nil then -- When it's nil, it's an object. 
						table.insert(List, Slot)
					elseif Slot.Content.Type == "VoxelGrid" then
						Recurse(Slot)
					end
				end
			end
		end
		for _, VoxelGrid in pairs(StorageSpaces) do
			Recurse(VoxelGrid)
		end
		return List;
	end
	BoxInventory.GetListOfItems = GetListOfItems;
	BoxInventory.getListOfItems = GetListOfItems;

	local function DeepSort()
		-- Sorts everything as it should be... Sorts it in relationship to time, I think. I'm pretty sure I need to weight according to time.
		-- Probably O(n^1.#INF) efficiency

		local CrateLevelData = {}
		local LargestSize = 0;

		-- Add in storagespaces and calculate the largest grid size (Linear)
		for _, VoxelGrid in ipairs(StorageSpaces) do
			CrateLevelData[VoxelGrid.Size] = CrateLevelData[VoxelGrid.Size] or {}
			CrateLevelData[VoxelGrid.Size][#CrateLevelData[VoxelGrid.Size]+1] = VoxelGrid;
			if VoxelGrid.Size > LargestSize then
				LargestSize = VoxelGrid.Size
			end
		end

		-- Start at top and work down..
		for GridSizeLevel = LargestSize, 0, -1 do
			if CrateLevelData[GridSizeLevel] then 
				local SlotList = {}
				local WeightList = {}
				local VoxelGrids = CrateLevelData[GridSizeLevel]

				for _, VoxeGrid in ipairs(VoxelGrids) do
					for Slot in VoxelPairs(VoxelGrid) do
						if Slot.Type == "Voxel" then
							SlotList[#SlotList+1] = Slot;
							WeightList[Slot] = ComputeSlotWeight(Slot)
						end
					end
				end

				-- Now that we have it all in an array, we can sort it...
				Table.ShellSort(Datas, (function(Slot) return Weight[Slot] end))

				-- And then readd into the tables...
				local CurrentIndex = 1;
				for _, VoxeGrid in ipairs(VoxelGrids) do
					for Slot in VoxelPairs(VoxelGrid) do
						if SlotList[CurrentIndex] then
							if Slot.Content ~= SlotList[CurrentIndex] then
								local OldSlot = SlotList[CurrentIndex].CurrentSlot
								Slot.Content = SlotList[CurrentIndex]
								SlotList[CurrentIndex].Interfaces.BoxInventory.CurrentSlot = Slot;
								-- Readd voxels in for next level sorting...
								if Slot.Content.Type == "Voxel" then
									CrateLevelData[Slot.Content.Size] = CrateLevelData[Slot.Content.Size] or {}
									CrateLevelData[Slot.Content.Size][#CrateLevelData[Slot.Content.Size]+1] = Slot.Content;
								else
									BoxInventory.CrateSlotChanged:fire(SlotList[CurrentIndex], Slot, OldSlot)
								end
							end
						else

							-- If the slot doesn't have anything, clear out old memory...
							Slot.Content = nil;
						end
						CurrentIndex = CurrentIndex + 1;
					end
				end
			end
		end
	end

	local function GetEmptySlot(CrateData)
		-- Return's an empty spot, if it can find it...

		-- Search for the empty slot in each one...
		for _, VoxelGrid in ipairs(StorageSpaces) do
			local EmptySlot = LookForEmptySlotInVoxelGrid(VoxelGrid, CrateData)
			if EmptySlot then -- Only return if we've got one...
				return EmptySlot
			end
		end

		return nil -- Could not find...
	end

	local CrateDataCache = {} -- Cache data per model to save on calcuation costs.
	local function AddBoxInventoryInterface(Item)
		-- Add's data storage interface and calculates data...

		if not Item.Interfaces.BoxInventory then
			-- Create a new interface that can be used to store data...

			local NewInterface = {};

			NewInterface.CrateData = CrateDataCache[Item.Model] or GenerateObjectData((Item.Model and qInstance.GetBricks(Item.Model) or error("[BoxInventory] - BoxInventory requires all items to have a 'Model'")))
			CrateDataCache[Item.Model] = NewInterface.CrateData
			-- NewInterface.CurrentSlot = nil;

			Item.Interfaces.BoxInventory = NewInterface
		end
	end

	local function AddItem(Item, SourceCFrame)
		--'Item' is an InventoryObject item...
		-- SourceCFrame is the position that the item came from. Not required.
		-- Return's the slot it was added too..

		AddBoxInventoryInterface(Item)

		local EmptySlot = GetEmptySlot(NewInterface.CrateData)
		if EmptySlot then
			EmptySlot.Content = Item;
			Item.Interfaces.BoxInventory.CurrentSlot = EmptySlot
			SimpleSort(EmptySlot.VoxelGrid)

			if SourceCFrame then
				-- Find CFrame relative to the Source...
				Item.Interfaces.BoxInventory.SourceCFrame = Item.Interfaces.BoxInventory.CurrentSlot.RelativeCFrame:inverse() * SourceCFrame
			else
				Item.Interfaces.BoxInventory.SourceCFrame = Item.Interfaces.BoxInventory.CurrentSlot.RelativeCFrame
			end

			BoxInventory.ItemAdded:fire(Item, Item.Interfaces.BoxInventory.CurrentSlot); -- Fire OnAdd event...
			return EmptySlot;
		else
			return nil; -- Not enough space...
		end
	end
	BoxInventory.AddItem = AddItem;
	BoxInventory.addItem = AddItem;

	local function CanAdd(Item)
		-- Return's the slot it can be added to...

		AddBoxInventoryInterface(Item)

		local EmptySlot = GetEmptySlot(NewInterface.CrateData)
		return EmptySlot
	end
	BoxInventory.CanAdd = CanAdd;
	BoxInventory.canAdd = CanAdd;

	local function RemoveItem(Slot)
		local ItemBeingRemoved = Slot.Content
		Slot.Content = nil;
		BoxInventory.ItemRemoved:fire(ItemBeingRemoved, Slot)
	end
end)
lib.MakeBoxInventory = MakeBoxInventory
lib.makeBoxInventory = MakeBoxInventory




local MakeBox3DRender = Class 'Box3DRender' (function(Box3DRender, BoxInventory)
	-- Renders BoxInventory in a visual format.

	local Configuration = {
		WeldMode = true;
	}

	-- Make sure we can override
	local ActiveTumblerIds = {}
	setmetatable(ActiveTumblerIds, {__mode = "k"})

	local function GenerateRandomVelocity()
		return math.floor(math.random() + 0.5) - 0.5 * math.random(1, 3);
	end

	local function TumbleBrick(Brick, TargetCFrame, TumbleRatio, TimePlay, SetCFrame, GravityPull, OnEnd)
		-- Makes a brick tumble through the air (From it's current CFrame to the target CFrame, 
		-- and then sets it using SetCFrame. Will do it in a parabala. 

		-- Scale it to time played
		TumbleRatio = TumbleRatio / TimePlay
		GravityPull = GravityPull / TimePlay
		-- Setup localId system
		ActiveTumblerIds[Brick] = ActiveTumblerIds[Brick] and ActiveTumblerIds[Brick] + 1 or 1;
		local LocalTumblerId    = ActiveTumblerIds[Brick];

		-- Get rotation we're rotating to so we can convert into a velocity
		local XRotation, YRotation, ZRotation = TargetCFrame:toEulerAnglesXYZ()
		local TargetRotation                  = Vector3.new(XRotation, YRotation, ZRotation);

		local RotationalVelocity = Vector3.new(GenerateRandomVelocity(), GenerateRandomVelocity(), GenerateRandomVelocity()) * math.pi * TumbleRatio
		local AnimationEndTime   = tick() + TimePlay

		local FinalPosition = TargetCFrame.p;
		local InitialPosition = Brick.Position
		local InitialVelocity = (FinalPosition - InitialPosition) / TimePlay - GravityPull * TimePlay * 0.5--(FinalPosition - ((GravityPull * TimePlay * TimePlay) * 0.5) - InitialPosition) / TimePlay
		while ActiveTumblerIds[Brick] == LocalTumblerId do
			local CurrentFrame = (((AnimationEndTime - tick()) / TimePlay) ^ 4) * TimePlay
			if tick() > AnimationEndTime then
				-- End animation...
				ActiveTumblerIds[Brick] = ActiveTumblerIds[Brick] + 1;
				SetCFrame(TargetCFrame)
				--print("Done")
			else
				local RotationToApplyVector = TargetRotation + (RotationalVelocity * (CurrentFrame))
				local RotationToApply = CFrame.Angles(RotationToApplyVector.X, RotationToApplyVector.Y, RotationToApplyVector.Z)
				local Time = TimePlay - CurrentFrame
				local NewPosition = InitialPosition + (InitialVelocity * Time) + (0.5 * GravityPull * (Time * Time)) -- Calculate parabula...
				local CFrameOfFrame = CFrame.new(NewPosition) * RotationToApply
				SetCFrame(CFrameOfFrame)
				Item.Interfaces.Box3DRender.RenderedRelativeCFrame = CFrameOfFrame
			end
			wait(0)
		end
		if tick() > AnimationEndTime then
			if OnEnd then
				OnEnd()
			end
			Item.Interfaces.Box3DRender.RenderedRelativeCFrame = Item.Interfaces.BoxInventory.CurrentSlot.RelativeCFrame
		end
	end

	local function SlideRepositionCrate(Item, NewRelativeCFrame, TimePlay, SetCFrame, OnEnd)
		-- Tweens to a new position without tumble or bounce.  AddBoxInventoryInterface should be added first. 
		Item.Interfaces.Box3DRender.TargetPosition = NewRelativeCFrame
		ActiveTumblerIds[Brick]                    = ActiveTumblerIds[Brick] and ActiveTumblerIds[Brick] + 1 or 1;
		local LocalTumblerId                       = ActiveTumblerIds[Brick];
		local StartCFrame                          = Item.Interfaces.Box3DRender.SourceCFrame
		local AnimationEndTime                     = tick() + TimePlay
		local StartRelativeCFrame                  = Item.Interfaces.BoxInventory.CurrentSlot.RelativeCFrame

		while ActiveTumblerIds[Brick] == LocalTumblerId do
			local CurrentFrame = (((AnimationEndTime - tick()) / TimePlay) ^ 4) * TimePlay
			if tick() > AnimationEndTime then
				ActiveTumblerIds[Brick] = ActiveTumblerIds[Brick] + 1;
				SetCFrame(TargetCFrame)
			else
				local CFrameOfFrame = qCFrame.SlerpCFrame(StartRelativeCFrame, NewRelativeCFrame, CurrentFrame)
				SetCFrame(CFrameOfFrame)
				Item.Interfaces.Box3DRender.RenderedRelativeCFrame = CFrameOfFrame;
			end
			wait(0)
		end
		if tick() > AnimationEndTime then
			if OnEnd then
				OnEnd()
			end
			Item.Interfaces.Box3DRender.RenderedRelativeCFrame = Item.Interfaces.BoxInventory.CurrentSlot.RelativeCFrame
		end
	end

	local function AddBox3DRenderInterface(Item)
		-- Add's data storage interface and calculates data...

		if not Item.Interfaces.Box3DRender then
			local NewInterface = {};
			local CrateData = Item.Interfaces.BoxInventory.CrataData;
			local SideLength = CrateData.CrateSideLength;

			NewInterface.Crate = Make 'Part' {
				Size = Vector3.new(SideLength, SideLength, SideLength);
				BrickColor = CrateData.BrickColor;
				Material = CrateData.MostCommonMaterial;
				Anchored = not Configuration.WeldMode;
				CanCollide = false;
				Transparency = 0;
				TopSurface = "Smooth";
				BottomSurface = "Smooth";
			}
			NewInterface.Weld = Make 'Weld' {
				Part1 = NewInterface.Crate;
				C1 = CFrame.new(0, 0, 0);
				Archivable = false;
			}

			NewInterface.TargetPosition = Item.Interfaces.BoxInventory.CurrentSlot.SourceCFrame
			NewInterface.RenderedRelativeCFrame = Item.Interfaces.BoxInventory.CurrentSlot.RelativeCFrame
			Item.Interfaces.Box3DRender = NewInterface
			end

		Item.Interfaces.Box3DRender.Weld.Part1 = Item.Interfaces.Box3DRender.Crate
		Item.Interfaces.Box3DRender.Weld.C1 = CFrame.new(0, 0, 0);
		Item.Interfaces.Box3DRender.Crate.CFrame = Item.Interfaces.Box3DRender.TargetPosition -- Set it to a relative position from origin...
	end

	local function RemoveBox3DInventoryInterface(Item)
		-- Safely removes and GC's interface

		local Interface = Item.Interface.Box3DRender
		Interface.Weld:Destroy()
		Interface.Crate:Destroy()

		Item.Interface.Box3DRender = nil; 
	end

	local function AddItem(Item, SourcePosition)
		-- Called when ItemAdded fires..

		--local DidAdd = BoxInventory.AddItem(Box3DRender);
		if DidAdd then
			AddBox3DRenderInterface(Item, SourcePosition)
			TumbleBrick(
				Item.Interfaces.Box3DRender.Crate, 
				CFrame.new(), 
				100, 
				5, 
				(function()
					if Configuration.WeldMode then
						return function(NewCFrame)
							Item.Interfaces.Box3DRender.Weld.C1 = Item.Interfaces.BoxInventory.CurrentSlot.RelativeCFrame * NewCFrame
						end;
					else
						error("[Box3DRender] - Non weld mode is not supported")
						return nil;
					end
				end)(), 
				Vector3.new(0, -15, 0),
				function()
					-- OnEnd
					Item.Interfaces.Box3DRender.TargetPosition = CFrame.new()
					NewInterface.Weld.C1 = Item.Interfaces.BoxInventory.CurrentSlot.RelativeCFrame
				end
			)
		end
	end

	local function RemoveItem(Item, Slot)
		-- Make it rise up and disappear...

		TumbleBrick(
			Item.Interfaces.Box3DRender.Crate, 
			CFrame.new(), 
			100, 
			5, 
			function(NewCFrame)
				Item.Interfaces.Box3DRender.Weld.C1 = Item.Interfaces.BoxInventory.CurrentSlot.RelativeCFrame * NewCFrame
			end, 
			Vector3.new(0, 0, 0),
			function()
				-- Remove interface if animation finishes. 
				RemoveBox3DInventoryInterface(Item)
			end
		)
	end

	BoxInventory.ItemAdded:connect(function(ItemAdded, Slot)
		AddItem(ItemAdded, ItemAdded.Interfaces.BoxInventory.SourceCFrame)
	end)

	BoxInventory.ItemRemoved:connect(function(Item, Slot)
		RemoveItem(Item, Slot)
	end)

	BoxInventory.CrateSlotChanged:connect(function(Item, OldSlot, NewSlot)
		SlideRepositionCrate(Item.Interfaces.Box3DRender.Crate,
			NewSlot.RelativeCFrame,
			5,
			(function()
				if Configuration.WeldMode then
					return function(NewCFrame)
						Item.Interfaces.Box3DRender.Weld.C1 = NewCFrame
					end;
				else
					error("[Box3DRender] - Non weld mode is not supported")
					return nil;
				end
			end)()
		)
	end);
end)
lib.MakeBox3DRender = MakeBox3DRender
lib.makeBox3DRender = MakeBox3DRender



NevermoreEngine.RegisterLibrary('InventorySystems', lib)
