local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems                = LoadCustomLibrary("qSystems")
local qInstance               = LoadCustomLibrary("qInstance")
local Table                   = LoadCustomLibrary("Table")

qSystems:Import(getfenv(0))

local lib = {}

-- BoxInventory.lua
-- @author Quenty
-- Last Modified 
-- This system handles 3D inventory interactions (datastructure).

--[[ Change Log
February 13th, 2014
- Removed ItemSystem dependency as an argument, the BoxInventory doesn't need to know the ItemSystem.

February 7rd, 2014
- Moved 3D inventory rendering to a seperate script.
- Removed qCFrame dependency
- Removed PenlightPretty dependency
- Renamed to BoxInventory from "InventorySystems"
- Slight documentation added
- Change Log added
- Removed SerializerContainer support to work with New ItemSystem
- Removed DeSerailize functions

- Changed method name GetListOfItems to GetListOfSlotsWithItems 
- Added GetListOfItems function (seperate from changed method)
- Fixed glitch with SourceCFrame being nil

- Made GenerateCrateData available to the public.
- Fixed issue with removal / Container removal

February 6th, 2014
- Stabilized version

February 3rd, 2014
- Modified to work with new Nevermore
- Modified to use new ClassSystem
--]]

--[[

This is a very badly organized system to do 3D inventory stuff in a voxel grid. The first thing I should have done when writing this was
written a seperaet class to handle JUST the voxel grid. Now the voxel grids are integreated into the system, which is kind of messy.

Also, there were some bugs parsing this into ROBLOX's systems to send over remote events, you see it uses CreateInternalSignal() instead of
ROBLOX's event class.

Also, the way this works out, it's confusing conceptually, the main problems were with getting it to be sorted correctly, in the most optimal
position. That was a pain. 

--]]

----------------------
-- HELPER FUNCTIONS --
----------------------

local function GetMaxGridSizeFromSmallestSide(SmallestSide)
	local Index = 0 
	local SideSize 
	repeat 
		Index = Index + 1 
		SideSize = 2^Index 
	until SideSize > SmallestSide 
	return Index
end

--[[

print(" ItemSize : Volume : SideLength : GridSize : ItemSizeRecalculated")
for i=0, 10 do
i = 2^i
print(i .. " : " .. i^3 .. " : " .. SideLengthFromVolume(i^3) .. " : " .. ItemSizeToGridSize(i) .. " : " .. GridSizeToItemSize(ItemSizeToGridSize(i)))
end

 GridSize :  ItemSize : Volume     : SideLength : ItemSizeRecalculated
     1    :     1     : 1          :     1      :    1
     2    :     2     : 8          :     2      :    2
     3    :     4     : 64         :     4      :    4
     4    :     8     : 512        :     8      :    8
     5    :     16    : 4096       :     16     :    16
     6    :     32    : 32768      :     32     :    32
     7    :     64    : 262144     :     64     :    64
     8    :     128   : 2097152    :     128    :    128
     9    :     256   : 16777216   :     256    :    256
     10   :     512   : 134217728  :     512    :    512
     11   :     1024  : 1073741824 :     1024   :    1024

]]

local function ItemSizeToGridSize(ItemSize, GridSizePowerOf)
	-- From the scaled ItemSize to the linear GridSize

	GridSizePowerOf = GridSizePowerOf or 2;
	return (math.log(ItemSize) / math.log(GridSizePowerOf)) + 1;
end

local function GridSizeToItemSize(GridSize, GridSizePowerOf)
	-- Converts linear GridSize to scaled ItemSize

	GridSizePowerOf = GridSizePowerOf or 2;
	return GridSizePowerOf^(GridSize - 1)
end


local function GetSmallestSide(PartSize)
	-- Return's the smallest side in a part.

	return math.min(PartSize.X, math.min(PartSize.Y, PartSize.Z));
end

local function SideLengthFromVolume(PartVolume)
	-- Based upon volume, returns the appropriate shipping crate side length 
	-- (All shipping crates are squares)

	---[[
	local Index = 0 
	local Volume 
	repeat 
		Index = Index + 1 
		Volume = (Index)^3
	until Volume > PartVolume 
	return (Index-1)
	--]]

	--return math.floor(PartVolume^(1/3) + 0.5) -- Sacrifice rounding w/ unprecise values for efficiency.
end

local function GenerateCrateData(Objects)
	-- Given a table of 'Objects', it'll find the most common material, average color, volume, and 
	-- the part of the most common material that is also the largest. 

	-- It is all scaled to Volume per part. 

	local VolumeListByMaterial = {};

	local PartToVolumeList = {}
	local MaterialToPartList = {};

	local WeightedColor = Vector3.new();
	local TotalVolume = 0

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
	CrateData.Volume = TotalVolume;
	CrateData.MaterialToPartList = MaterialToPartList[LargestMaterial];
	CrateData.SideLength = SideLengthFromVolume(TotalVolume)
	CrateData.ItemSize = CrateData.SideLength -- For now, they're the same.
	CrateData.GridSize = ItemSizeToGridSize(CrateData.ItemSize); -- Scalier, what the item fits INTO. 

	return CrateData;
end
lib.GenerateCrateData = GenerateCrateData
lib.generateCrateData = GenerateCrateData

local function VoxelPairsSlot(VoxelGrid)
	-- Prefer Y, then X, then Z
	-- So first return all the content on the yLevel, that is, 1 and up...
	--- Generic ForLoop for Voxel Slot
	-- @param VoxelGrid Slot with VoxelGrid.Content as a VoxelGrid

	local Content = VoxelGrid.Content
	--assert(Content ~= nil, "Content is nil, invalid Slot sent")
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
lib.VoxelPairsSlot = VoxelPairsSlot
lib.voxelPairsSlot = VoxelPairsSlot

local function VoxelPairs(VoxelGrid)
	-- Prefer Y, then X, then Z
	-- So first return all the content on the yLevel, that is, 1 and up...
	--- Generic ForLoop for Voxel Slot

	local CurrentX = 1;
	local CurrentY = 1;
	local TargetY = #(VoxelGrid[1]);
	local CurrentZ = 1;

	return function()
		local Slot, FaultAt
		while CurrentY <= TargetY do
			Slot, FaultAt = VoxelGrid:GetSlot(CurrentX, CurrentY, CurrentZ)
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

local GetSlot = function(self, X, Y, Z)
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

local function GetRelativeSlotPosition(LocalPosition, GridSize, ItemSize)
	-- Return's relative Position from Center and Vector position and Size and Vector GridSize (X, Y, Z)

	-- GridSize is linear (And a vector)
	-- ItemSize, as always, is scalar...


	--return (LocalPosition + ((-GridSize - Vector3.new(1, 1, 1))/2)) * ItemSize -- Fun mathz!
	
	-- // ARCHIVE --
	--local RelativeToTop = ((LocalPosition - Vector3.new(1, 1, 1)) * (ItemSize/2))
	--local RelativeToCenter = (ItemSize/2) * ((GridSize - Vector3.new(1, 1, 1))/2) - RelativeToTop
	--return RelativeToCenter;
	-- // END ARCHIVE --

	local RelativeToTop = ((LocalPosition - Vector3.new(1, 1, 1)) * (ItemSize))
	local RelativeToCenter = (ItemSize) * ((GridSize - Vector3.new(1, 1, 1))/2) - RelativeToTop
	return -RelativeToCenter;
end

local function GenerateVoxelGrid(GridSize, ItemSize, Size)
	--- Generates a 3D array 
	-- @param Slot The slot that the VoxelGrid is being genearted for.

	-- GridSize is linear
	-- ItemSize, as always, is scalar...
	-- Size is a Vector

	local SizeX, SizeY, SizeZ = Size.X, Size.Y, Size.Z
	-- print("[BoxInventory] - Generating voxel grid of "..SizeX..", "..SizeY..", "..SizeZ)
	local VoxelGrid = {}
	for X = 1, SizeX do
		VoxelGrid[X] = {};
		for Y = 1, SizeY do
			VoxelGrid[X][Y] = {};
			for Z = 1, SizeZ do
				local Slot = {
					Type          = "EmptySlot";
					--Content     = {};
					ItemSize      = ItemSize;
					GridSize      = ItemSizeToGridSize(ItemSize);
					LocalPosition = Vector3.new(X, Y, Z); -- Linear
					VoxelGrid     = VoxelGrid;
					VoxelGridSlot = Slot
					--Weight      = 0; -- Used for
				};
				Slot.RelativePosition = GetRelativeSlotPosition(Slot.LocalPosition, Size, ItemSize)
				--print("[BoxInventory] - Slot.RelativePosition = "..tostring(Slot.RelativePosition))
				VoxelGrid[X][Y][Z] = Slot
			end
		end
	end
	VoxelGrid.GetSlot = GetSlot;

	return VoxelGrid;
end

local function RoundNumberDown(Number, Divider)
	return math.floor((Number/Divider))*Divider
end

----------------
-- MAIN CLASS --
----------------

local MakeBoxInventory = Class(function(BoxInventory, Name)
	--- A 3D "Box" inventory, that revolves around packaging items into crates as representation.
	-- @param Name The Name of the BoxInventory. If no name is given, then it'll just generate one. 

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
				RelativePosition
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

	BoxInventory.Name                 = Name or "Inventory@" .. tostring(BoxInventoryA);
	BoxInventory.LargestGridSize      = 1; -- The largest gridSize stored in the inevntory
	BoxInventory.Interfaces           = {} -- Stores internal data from interfacing programs. This is like the ItemSystem class, except other classes use it.

	-- ROBLOX Signals apparenlty don't support circular referenced items. Let's use Lua instead. 
	BoxInventory.StorageSlotAdded     = CreateSignalInternal(); 
	
	BoxInventory.ItemAdded            = CreateSignalInternal(); -- (Item, ItemSlot)
	BoxInventory.ItemRemoved          = CreateSignalInternal(); -- (Item, OldItemSlot)
	BoxInventory.ItemSlotChanged      = CreateSignalInternal(); -- (Item, NewSlot)
	
	BoxInventory.VoxelGridAdded       = CreateSignalInternal(); -- Whenever a new voxelgrid is added.
	BoxInventory.VoxelGridRemoving    = CreateSignalInternal(); -- Whenever a new voxelgrid is added. Fires before removal, probably.
	BoxInventory.VoxelGridSlotChanged = CreateSignalInternal(); -- When a VoxelGrid's slot changes.

	local StorageSpaces = StorageSpaces;

	local function AddVoxelGridToSlot(Slot, GridSize, ItemSize, Size)
		-- Add's a VoxelGrid to Slot.Content and updates relative information.
		-- @Param Size The X, Y, Z number of slots, a Vector3 Value
		-- @Pre Slot has a VoxelGrid...

		--print("[BoxInventory] - Generating voxel grid at GridSize @ ".. tostring(GridSize)..", ItemSize ((2^ItemSize)=GridSize) @ "..tostring(ItemSize))
		assert(ItemSize ~= nil, "[BoxInventory][MakeVoxelGrid] - ItemSize is nil")
		assert(GridSize ~= nil, "[BoxInventory][MakeVoxelGrid] - GridSize is nil")
		--assert(RelativePosition ~= nil, "[BoxInventory][MakeVoxelGrid] - RelativePosition is nil")
		--assert(2^GridSize ~= ItemSize, "2^GridSize ("..(2^GridSize)..") ~= "..ItemSize)

		Size = Size or Vector3.new(2, 2, 2)
		Slot.Type               = "VoxelGrid";
		Slot.Content            = GenerateVoxelGrid(GridSize, ItemSize, Size); -- Convert gridsize to scalar.
		Slot.Content.ContentItemSize    = ItemSize; -- Scalar -- Size of the VoxelGrid's content's ItemSize and GridSize
		Slot.Content.ContentGridSize    = GridSize; -- Linear
		Slot.Content.AddTime = tick() -- For sorting

		--assert(Slot.Content   ~= nil, "Content somehow ended up nil. FML.") 
		--Slot.RelativePosition = GetRelativeSlotPosition(Slot.LocalPosition, GridSize, ItemSize)
		Slot.Content.Slot       = Slot; -- Parent reference. Huzzah. 

		BoxInventory.VoxelGridAdded:fire(Slot.Content, Slot) -- Fire Events..

		return Slot;
	end

	local function MakeVoxelGrid(GridSize, ItemSize, Size)
		--- Makes a new VoxelGrid, aka a storage slot...
		-- @param GridSize the Size of the grid in linear form, (step based)
		-- @param ItemSize the Size of each item in the grid, which is 2^GridSize, probably
		-- @param [Size] the size of the grid, may be nil, but is in linear form, so gridsize, but can be anything. A vector3 value.

		-- GridSize is linear.
		-- ItemSize is scalar. 

		local Slot = {}
		AddVoxelGridToSlot(Slot, GridSize, ItemSize, Size)
		return Slot
	end

	local LookForEmptySlotInVoxelGridSlot
	function LookForEmptySlotInVoxelGridSlot(VoxelGrid, CrateData, DoNotRecurse)
		--- Search's for an empty slot in the voxel grid with the same size as the crate data, or recurses down...
		-- @param VoxelGrid Slot with it's Content.Type as "Voxel"

		if VoxelGrid.Content and VoxelGrid.Type == "VoxelGrid" then
			if VoxelGrid.Content.ContentGridSize == CrateData.GridSize then
				for Slot in VoxelPairsSlot(VoxelGrid) do
					if (Slot.Content == nil) then
						return Slot;
					end
				end
				return nil;
			elseif VoxelGrid.Content.ContentGridSize > CrateData.GridSize then
				for Slot in VoxelPairsSlot(VoxelGrid) do
					if Slot.Content and Slot.Type == "VoxelGrid" then
						local RecursionResult = LookForEmptySlotInVoxelGridSlot(Slot, CrateData);
						if RecursionResult then
							return RecursionResult
						end
					elseif Slot.Content == nil and VoxelGrid.Content.ContentGridSize >= 1 then -- Smallest size is 1?
						AddVoxelGridToSlot(Slot, VoxelGrid.Content.ContentGridSize - 1, GridSizeToItemSize(VoxelGrid.Content.ContentGridSize - 1))
						if not DoNotRecurse then
							local RecursionResult = LookForEmptySlotInVoxelGridSlot(Slot, CrateData);
							if RecursionResult then
								return RecursionResult
							end
						end
					end
				end
				return nil;
			else
				return nil;
			end
		else
			error("[BoxInventory] - VoxelGrid.Content is nil, or VoxelGrid.Type ("..tostring(VoxelGrid.Type)..") ~= \"VoxelGrid\" invalid input")
		end
	end

	local function AddStorageSlot(Part)
		-- Add a brick into the storage slot...
		-- assert(Part ~= nil, "[BoxInventory][AddStorageSlot] - Part is nil")

		Center = Center or Part.CFrame;

		local PartSize = Part.Size
		local SmallestSide = GetSmallestSide(PartSize)
		local GridSize = GetMaxGridSizeFromSmallestSide(SmallestSide) -- Scalier
		BoxInventory.LargestGridSize = math.max(BoxInventory.LargestGridSize, GridSize)
		local ItemSize = GridSizeToItemSize(GridSize);
		local Size = Vector3.new(
			math.floor(PartSize.X/SmallestSide), 
			math.floor(PartSize.Y/SmallestSide), 
			math.floor(PartSize.Z/SmallestSide)
		)
		
		--print("[Adding Storage Slot] - GridSize (Linear) "..tostring(GridSize).."; ItemSize (Scaliar): "..ItemSize.."; Size = "..tostring(Size))
		-- assert(PartSize ~= nil, "[BoxInventory][AddStorageSlot] - PartSize is nil")
		-- assert(SmallestSide ~= nil, "[BoxInventory][AddStorageSlot] - SmallestSide is nil")
		-- assert(ItemSize ~= nil, "[BoxInventory][AddStorageSlot] - ItemSize is nil")
		-- assert(GridSize ~= nil, "[BoxInventory][AddStorageSlot] - GridSize is nil")
		

		local StorageSlot               = MakeVoxelGrid(GridSize, ItemSize, Size);
		StorageSlot.IsStorageSlot       = true;
		StorageSlot.Content.VoxelPart   = Part;
		StorageSlot.GridSize            = GridSize;
		StorageSlot.ItemSize            = ItemSize;
		StorageSlot.RelativePosition    = Vector3.new(0, 0, 0) -- Relative to itself, it's obviously 0. 
		StorageSpaces[#StorageSpaces+1] = StorageSlot

		BoxInventory.StorageSlotAdded:fire(StorageSlot, Part)
		return StorageSlot
	end
	BoxInventory.AddStorageSlot = AddStorageSlot
	BoxInventory.addStorageSlot = AddStorageSlot

	local function GetStorageSlots()
		-- Return's storage slots
		return StorageSpaces;
	end
	BoxInventory.GetStorageSlots = GetStorageSlots
	BoxInventory.getStorageSlots = GetStorageSlots

	local function GetListOfSlotsWithItems()
		-- Return's a list of all the items in the inventory at the time...

		local List = {}
		local Recurse
		function Recurse(VoxelGrid)
			for Slot in VoxelPairsSlot(VoxelGrid) do
				if Slot.Content then
					if Slot.Type == "Item" then -- When it's nil, it's an object. 
						table.insert(List, Slot)
					elseif Slot.Type == "VoxelGrid" then
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
	BoxInventory.GetListOfSlotsWithItems = GetListOfSlotsWithItems;
	BoxInventory.getListOfSlotsWithItems = GetListOfSlotsWithItems;

	local function GetListOfItems()
		local List = {}
		local Recurse
		function Recurse(VoxelGrid)
			for Slot in VoxelPairsSlot(VoxelGrid) do
				if Slot.Content then
					if Slot.Type == "Item" then -- When it's nil, it's an object. 
						table.insert(List, Slot)
					elseif Slot.Type == "VoxelGrid" then
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
	BoxInventory.GetListOfItems = GetListOfItems
	BoxInventory.getListOfItems = GetListOfItems

	local function GetListOfVoxelGrids()
		-- Return's a list of VoxelGrids

		local List = {}
		local Recurse
		function Recurse(VoxelGrid)
			table.insert(List, VoxelGrid)
			for Slot in VoxelPairsSlot(VoxelGrid) do
				if Slot.Content then
					if Slot.Type == "VoxelGrid" then
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
	BoxInventory.GetListOfVoxelGrids = GetListOfVoxelGrids
	BoxInventory.getListOfVoxelGrids = GetListOfVoxelGrids

	local function DeepSort()
		--- Sorts the inventory, in a specific order. 
		--[[ Should do the following, 
		
		Remove all empty VoxelGrids.
			For each voxel grid, we want to find out how many Slot children they have
			If it's 0, and none of the DEPENDING items have a child, then we can remove it. 

		Solid parts go on the bottom
	
		Initially using how many items were contained in a voxel grid + child voxel grid to sort the voxel grids.
		However, this doesn't work out too well, as we want the smaller items, that is, the ones not filled out completely
		to bubble up to the top.

		So "volume" would be a better way to do it, that is, the ones with the smallest volume should go up?
		]]

		local VoxelGridSlotsByGridSize          = {} -- Contains VoxelGrids (Slots) by GridSize
		local VoxelGridParentsByContentGridSize = {} -- Contains VoxelGrids (Slots) by what GridSize their content is. 
		local ItemSlotsByGridSize               = {} -- Contains Items (Slots). Array. 
		local LargestContentGridSize            = 1;

		local RecursePopulateLists
		function RecursePopulateLists(VoxelGridSlot)
			--- This looks like gibberish to me now. 
			-- Oh gosh.

			local ItemVolumeSum = 0;

			for Slot in VoxelPairsSlot(VoxelGridSlot) do
				if Slot.Type == "VoxelGrid" then
					ItemVolumeSum = ItemVolumeSum  + RecursePopulateLists(Slot, FunctionToExecute) 

					local SlotContentGridSize = Slot.Content.ContentGridSize
					local SlotGridSize = Slot.GridSize

					if SlotContentGridSize > LargestContentGridSize then -- Update largestest GridSize
						LargestContentGridSize = SlotContentGridSize
					end

					VoxelGridSlotsByGridSize[SlotGridSize] = VoxelGridSlotsByGridSize[SlotGridSize] or {}
					local VoxelGridSlots = VoxelGridSlotsByGridSize[SlotGridSize]

					VoxelGridSlots[#VoxelGridSlots + 1] = Slot

					VoxelGridParentsByContentGridSize[SlotContentGridSize] = VoxelGridParentsByContentGridSize[SlotContentGridSize] or {}
					local VoxelGridParents = VoxelGridParentsByContentGridSize[SlotContentGridSize]
					VoxelGridParents[#VoxelGridParents + 1] = Slot
				elseif Slot.Type == "Item" then
					local SlotGridSize = Slot.GridSize

					ItemSlotsByGridSize[SlotGridSize] = ItemSlotsByGridSize[SlotGridSize] or {}
					local ItemSlots = ItemSlotsByGridSize[SlotGridSize]

					ItemSlots[#ItemSlots + 1] = Slot

					ItemVolumeSum = ItemVolumeSum + Slot.ItemSize^3;
				end
			end

			VoxelGridSlot.Content.ItemVolumeSum = ItemVolumeSum;
			return ItemVolumeSum;
		end

		for _, StorageSlot in ipairs(StorageSpaces) do
			RecursePopulateLists(StorageSlot)
			VoxelGridParentsByContentGridSize[StorageSlot.Content.ContentGridSize] = VoxelGridParentsByContentGridSize[StorageSlot.Content.ContentGridSize] or {}
			local VoxelGridParents = VoxelGridParentsByContentGridSize[StorageSlot.Content.ContentGridSize]
			VoxelGridParents[StorageSlot] = true
		end

		-- Sort backwards, because ChildCount changes, so sorting the VoxelGrids changes. :/
		for GridSize = 1, LargestContentGridSize do
			if VoxelGridParentsByContentGridSize[GridSize] then -- Make sure slots holding this level exist.
				-- For each slot we want to sort into new positions
				-- And then remove the inactive slots.

				local VoxelGridContentSlots = VoxelGridParentsByContentGridSize[GridSize]
				local VoxelGridSlots        = VoxelGridSlotsByGridSize[GridSize]
				local ItemSlots             = ItemSlotsByGridSize[GridSize]
				local Slots                 = {}

				if ItemSlots then
					-- Sort slots...
					table.sort(ItemSlots, function(ItemA, ItemB)
						local BoxInventoryA = ItemA.Content.Interfaces.BoxInventory
						local BoxInventoryB = ItemB.Content.Interfaces.BoxInventory

						if BoxInventoryA.CrateData.Volume == BoxInventoryB.CrateData.Volume then
							return BoxInventoryA.AddTime < BoxInventoryB.AddTime -- We want added ones added first, first.
						else
							return BoxInventoryA.CrateData.Volume > BoxInventoryB.CrateData.Volume
						end
					end)

					for Index, Item in ipairs(ItemSlots) do -- ItemSlots come first...
						Slots[Index] = Item.Content
					end
				end

				-- Sort VoxelGrids, we want the full ones first. There should not be any emptyones in here. 
				if VoxelGridSlots then
					table.sort(VoxelGridSlots, function(ItemA, ItemB)
						if ItemA.Content.ItemVolumeSum == ItemB.Content.ItemVolumeSum then
							return ItemA.Content.AddTime < ItemB.Content.AddTime
						else
							return ItemA.Content.ItemVolumeSum > ItemB.Content.ItemVolumeSum
						end
					end)

					local ItemSlotsCount = #Slots

					for Index, Item in ipairs(VoxelGridSlots) do
						Slots[ItemSlotsCount + Index] = Item.Content
					end
				end

				local Index = 1;
				for _, VoxelGridSlot in ipairs(VoxelGridContentSlots) do
					local ItemVolumeSum = 0;

					for Slot in VoxelPairsSlot(VoxelGridSlot) do -- There should theroetically be enough slots every single time.
						local NewContent = Slots[Index]
						if NewContent then					
							local SlotType = Slot.Type

							if Slot.Content ~= NewContent then
								Slot.Content = NewContent

								if NewContent.Interfaces then -- Determine type of newly modified slot.
									NewContent.Interfaces.BoxInventory.CurrentSlot = Slot;
									ItemVolumeSum = ItemVolumeSum + NewContent.Interfaces.BoxInventory.CrateData.ItemSize^3;
									Slot.Type = "Item";

									BoxInventory.ItemSlotChanged:fire(Slot.Content, Slot)
								else
									Slot.Type = "VoxelGrid";
									ItemVolumeSum = ItemVolumeSum + Slot.Content.ItemVolumeSum
									BoxInventory.VoxelGridSlotChanged:fire(Slot.Content, Slot)
								end
							else -- We still have to add to the count.
								if NewContent.Interfaces then -- Item
									ItemVolumeSum = ItemVolumeSum + NewContent.Interfaces.BoxInventory.CrateData.ItemSize^3;
								else -- VoxelGrid
									ItemVolumeSum = ItemVolumeSum + Slot.Content.ItemVolumeSum
								end
							end
						elseif SlotType ~= "EmptySlot" then -- No  content can be added, remove it!
							if not Slot.IsStorageSlot then
								Slot.Type = "EmptySlot";
								Slot.Content = nil;
							else -- StorageSlots just get their content wiped
								Slot.Content = nil;
							end
						end
						Index = Index + 1;
					end

					if ItemVolumeSum == 0 then --if ItemChildCount == 0 then
						-- Remove this voxel grid, unless it's a Storage slot
						if not VoxelGridSlot.IsStorageSlot then
							BoxInventory.VoxelGridRemoving:fire(VoxelGridSlot.Content, VoxelGridSlot)

							-- Remove from table index of sorting thing
							local FoundIndex
							for Index, SlotInList in pairs(VoxelGridSlotsByGridSize[VoxelGridSlot.GridSize]) do
								if SlotInList == VoxelGridSlot then
									FoundIndex = Index;
									break;
								end
							end
							table.remove(VoxelGridSlotsByGridSize[VoxelGridSlot.GridSize], FoundIndex)

							VoxelGridSlot.Content = nil;
							VoxelGridSlot.Type = "EmptySlot";
						end
					else
						-- VoxelGridSlot.Content.ItemChildCount = ItemChildCount
						VoxelGridSlot.Content.ItemVolumeSum = ItemVolumeSum;
					end
				end
			end
		end
	end
	BoxInventory.DeepSort = DeepSort;
	BoxInventory.deepSort = DeepSort


	local function GetEmptySlot(CrateData)
		-- Return's an empty spot, if it can find it...

		-- Search for the empty slot in each one...
		for _, VoxelSlot in ipairs(StorageSpaces) do
			local EmptySlot = LookForEmptySlotInVoxelGridSlot(VoxelSlot, CrateData)
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
			--NewInterface.CurrentBoxInventory = BoxInventory
			NewInterface.CrateData = CrateDataCache[Item.Model] or GenerateCrateData((Item.Model and qInstance.GetBricks(Item.Model) or error("[BoxInventory] - BoxInventory requires all items to have a 'Model'")))
			--assert(NewInterface.CrateData ~= nil, "[BoxInventory][InterfaceAdder] - Crate data ended up nil")
			CrateDataCache[Item.Model] = NewInterface.CrateData
			-- NewInterface.CurrentSlot = nil;

			function NewInterface.RemoveSelfFromInventory()
				-- Removes the item from the inventory.
				if NewInterface.CurrentSlot then
					BoxInventory.RemoveItemFromSlot(NewInterface.CurrentSlot)
					return true;
				else
					error("Item is not currently in an inventory, cannot remove")
					return false;
				end
			end

			Item.Interfaces.BoxInventory = NewInterface
		end
	end

	-------------------
	-- ITEM ADDITION --
	-------------------

	local function AddItem(Item, SourceCFrame, DoNotSort)
		--- 'Item' is an InventoryObject item...
		-- SourceCFrame is the position that the item came from. Not required. Relative to global origin. 
		-- Return's the slot it was added too..
		-- @param DoNotSort 

		AddBoxInventoryInterface(Item)
		-- print("Adding Item, ItemSize: "..Item.Interfaces.BoxInventory.CrateData.ItemSize.."; GridSize: "..Item.Interfaces.BoxInventory.CrateData.GridSize.."; SideLength = "..Item.Interfaces.BoxInventory.CrateData.SideLength)
		local EmptySlot = GetEmptySlot(Item.Interfaces.BoxInventory.CrateData)
		if EmptySlot then
			--print(EmptySlot.Content, EmptySlot.LocalPosition)
			EmptySlot.Content = Item;
			EmptySlot.Type = "Item"
			Item.Interfaces.BoxInventory.CurrentSlot = EmptySlot
			Item.Interfaces.BoxInventory.AddTime = tick() -- For sorting.

			-- assert(EmptySlot.VoxelGrid ~= nil, "EmptySlot.VoxelGrid is nil. What is this!")
			--SimpleSort(EmptySlot.VoxelGrid)

			if SourceCFrame then
				-- Find CFrame relative to the Source...
				-- Origin will be the current slot... 
				-- local RelativePosition, VoxelPart = GetRelativePositionToVoxelPart(Item.Interfaces.BoxInventory.CurrentSlot)
				--Item.Interfaces.BoxInventory.SourceCFrame = SourceCFrame * VoxelPart.CFrame:inverse()
				--weld.Part0.CFrame * weld.C0 = weld.Part1.CFrame * weld.C1 ~ Oysi

				Item.Interfaces.BoxInventory.SourceCFrame = SourceCFrame
			else
				Item.Interfaces.BoxInventory.SourceCFrame = CFrame.new(Item.Interfaces.BoxInventory.CurrentSlot.RelativePosition)
			end
			--assert(Item.Interfaces.BoxInventory.SourceCFrame ~= nil, "Item.Interfaces.BoxInventory.SourceCFrame is nil")
			
			if not DoNotSort then
				DeepSort()
			end

			BoxInventory.ItemAdded:fire(Item, Item.Interfaces.BoxInventory.CurrentSlot); -- Fire OnAdd event...
			return EmptySlot;
		else
			print("[BoxInventory] - *** ERROR *** Could not identify slot for item to be added, Size: "..Item.Interfaces.BoxInventory.CrateData.ItemSize)
			return nil; -- Not enough space...
		end
	end
	BoxInventory.AddItem = AddItem;
	BoxInventory.addItem = AddItem;

	local function CanAdd(Item)
		--- Return's the slot it can be added to...
		-- @param Item an InventoryItem that should be tested for, if it can be added. 
		-- @return the Slot that the item may be added too.

		AddBoxInventoryInterface(Item)

		local EmptySlot = GetEmptySlot(NewInterface.CrateData)
		return EmptySlot
	end
	BoxInventory.CanAdd = CanAdd;
	BoxInventory.canAdd = CanAdd;

	local function RemoveItemFromSlot(Slot)
		--- Removes an item from a slot
		-- @param Slot The slot to remove the item from
		-- @return The slot that is being removed. 

		local ItemBeingRemoved = Slot.Content
		if Slot.Type == "Item" then
			local OldContent = Slot.Content

			Slot.Content = nil;
			Slot.Type = "EmptySlot";

			DeepSort()

			BoxInventory.ItemRemoved:fire(ItemBeingRemoved, Slot)
			return OldContent;
		else
			error("[BoxInventory] - Cannot remove a(n) "..tostring(Slot.Type).." form a slot, it must be an Item");
			return nil;
		end
	end
	BoxInventory.RemoveItemFromSlot = RemoveItemFromSlot;
	BoxInventory.removeItemFromSlot = RemoveItemFromSlot;

	local function GetSlotOfItemClass(ClassName)
		--- Get's the slot of an ItemClass if it exists and returns it.

		local Recurse
		function Recurse(VoxelGrid)
			for Slot in VoxelPairsSlot(VoxelGrid) do
				if Slot.Content then
					if Slot.Content.Type == nil then -- When it's nil, it's an object. 
						if Slot.Content.ClassName == ClassName then
							return Slot
						end
					elseif Slot.Content.Type == "VoxelGrid" then
						Recurse(Slot)
					end
				end
			end
		end
		for _, VoxelGrid in pairs(StorageSpaces) do
			local Result = Recurse(VoxelGrid)
			if Result then
				return Result
			end
		end
		return nil;
	end
	BoxInventory.GetSlotOfItemClass = GetSlotOfItemClass
	BoxInventory.getSlotOfItemClass = GetSlotOfItemClass

	local function RemoveItemClass(ClassName)
		-- Removes a single item of "ItemClass" from the inventory if it can find it.
		-- @return If it removed it successfully or not

		local Slot = GetSlotOfItemClass(ClassName)
		if Slot then
			RemoveItemFromSlot(Slot)
		end
	end
	BoxInventory.RemoveItemClass = RemoveItemClass
	BoxInventory.removeItemClass = RemoveItemClass
end)
lib.MakeBoxInventory = MakeBoxInventory
lib.makeBoxInventory = MakeBoxInventory

return lib