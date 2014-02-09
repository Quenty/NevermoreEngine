local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems                = LoadCustomLibrary("qSystems")
local qInstance               = LoadCustomLibrary("qInstance")
local PenlightPretty          = LoadCustomLibrary("PenlightPretty")
local EventGroup               = LoadCustomLibrary("EventGroup")

qSystems:Import(getfenv(0));

-- Renders BoxInventories in a pretty 3D voxel. Yay.
-- Box3Drender.lua
-- @author Quenty

--[[ Change Log

February 7rd, 2014
- Moved script from InventorySystems (renamed to BoxInventory) to Box3DRender
- Added Destroy method

--]]

local lib = {}

local MakeBox3DRender = Class(function(Box3DRender, BoxInventory)
	local Events = EventGroup.MakeEventGroup()

	local function UpdateVoxelPartPosition(VoxelGrid, Slot)
		--- adds an interface to it
		-- @pre Parent has VoxelGrid assigned.

		if Slot.VoxelGrid then -- regular VoxelGrid

			if not VoxelGrid.VoxelPart then
				VoxelGrid.VoxelPart = Make 'Part' {
					Anchored      = false;
					Archivable    = false;
					BottomSurface = "Smooth";
					BrickColor    = BrickColor.new("Bright red");
					CanCollide    = false;
					FormFactor    = "Custom";
					Name          = "VoxelGrid_Part_Representation";
					Parent        = Slot.VoxelGrid.VoxelPart;
					TopSurface    = "Smooth";
					Transparency  = 1;
				};
				VoxelGrid.VoxelPart.Size = Vector3.new(Slot.ItemSize, Slot.ItemSize, Slot.ItemSize)
			end
			VoxelGrid.VoxelPart.Parent = Slot.VoxelGrid.VoxelPart

			local VoxelWeld = VoxelGrid.VoxelPart:FindFirstChild("Weld") or Make 'Weld' {
				Name = "Weld";
				Archivable = false;
				Parent = VoxelGrid.VoxelPart;
				--C0 = CFrame.new(0, 0, 0);
				--C1 = CFrame.new(0, 0, 0);
			};
			
			-- print("[Box3DRender] - Slot.VoxelGrid.VoxelPart = "..tostring(Slot.VoxelGrid.VoxelPart))

			VoxelWeld.Part0 = VoxelGrid.VoxelPart;	
			VoxelWeld.Part1 = Slot.VoxelGrid.VoxelPart;
			VoxelWeld.C1    = CFrame.new(Slot.RelativePosition)
			
		-- else -- Storage slot.
			-- print("[Box3DRender] - Storage Slot added")
		end
	end

	local function RemoveVoxelGrid(VoxelGrid, Slot)
		if VoxelGrid.VoxelPart then
			-- print("[Box3DRender] - Removing VoxelPart")
			VoxelGrid.VoxelPart.Parent = nil; --:Destroy()
			VoxelGrid.VoxelPart = nil;
		else
			print("[Box3DRender] - No VoxelPart to destroy? Error?")
		end
	end

	local function CratePartChanged(Item, Slot)
		-- print("Crate part's position changed ")

		local CrateData = Item.Interfaces.BoxInventory.CrateData;
		local SideLength = CrateData.SideLength;

		Item.Interfaces.Box3DRender = Item.Interfaces.Box3DRender or {}

		local CratePart = Item.Interfaces.Box3DRender.CratePart or Make 'Part' { -- Rendering component.
			Anchored      = false;
			Archivable    = false;
			BottomSurface = "Smooth";
			BrickColor    = CrateData.BrickColor;
			CanCollide    = false;
			FormFactor    = "Custom";
			Material      = CrateData.MostCommonMaterial;
			Name          = Item.ClassName.."Crate";
			Parent        = Slot.VoxelGrid.VoxelPart;
			TopSurface    = "Smooth";
			Transparency  = 0;
		}
		CratePart.Size = Vector3.new(SideLength, SideLength, SideLength);
		CratePart.Parent = Slot.VoxelGrid.VoxelPart;
		
		Item.Interfaces.Box3DRender.CratePart = CratePart;

		local CrateWeld = CratePart:FindFirstChild("Weld") or Make 'Weld' {
			Archivable = false;
			Name       = "Weld";
			Parent     = CratePart;
		}

		--print("[Box3DRender] - Slot.VoxelGrid.VoxelPart = "..tostring(Slot.VoxelGrid.VoxelPart))
		
		CrateWeld.Part0 = CratePart
		CrateWeld.Part1 = Slot.VoxelGrid.VoxelPart
		CrateWeld.C1 = CFrame.new(Slot.RelativePosition)
	end

	local function RemoveCrate(Item, Slot)
		local CratePart = Item.Interfaces.Box3DRender.CratePart
		if CratePart then
			CratePart:Destroy()
		end
	end

	local function Destroy()
		Events("Clear")
	end
	Box3DRender.Destroy = Destroy
	Box3DRender.destroy = Destroy

	--------------------
	-- CONNECT EVENTS --
	--------------------

	-- Incase events fire without connection...
	for _, VoxelGridSlot in pairs(BoxInventory.GetListOfVoxelGrids()) do
		UpdateVoxelPartPosition(VoxelGridSlot.Content, VoxelGridSlot)
	end
	for _, Item in pairs(BoxInventory.GetListOfItems()) do
		CratePartChanged(Item, Item.CurrentSlot)
	end

	-- Connect actual events.
	Events.VoxelGridAdded = BoxInventory.VoxelGridAdded:connect(function(VoxelGrid, Slot)
		UpdateVoxelPartPosition(VoxelGrid, Slot)
	end)

	Events.VoxelGridSlotChanged = BoxInventory.VoxelGridSlotChanged:connect(function(VoxelGrid, Slot)
		UpdateVoxelPartPosition(VoxelGrid, Slot)
	end)

	Events.ItemSlotChanged = BoxInventory.ItemSlotChanged:connect(function(Item, Slot)
		CratePartChanged(Item, Slot)
	end)

	Events.ItemAdded = BoxInventory.ItemAdded:connect(function(Item, Slot)
		CratePartChanged(Item, Slot)
	end)--]]

	Events.ItemRemoved = BoxInventory.ItemRemoved:connect(function(Item, Slot)
		RemoveCrate(Item, Slot)
	end)

	Events.VoxelGridRemoving = BoxInventory.VoxelGridRemoving:connect(function(VoxelGrid, Slot)
		RemoveVoxelGrid(VoxelGrid, Slot)
	end)
end)
lib.MakeBox3DRender = MakeBox3DRender
lib.makeBox3DRender = MakeBox3DRender

return lib