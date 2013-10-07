local VoxelGridMetatable = {
	__index = {
		GetSlot = function(self, X, Y, Z)
			-- Returns the slot at X, Y, Z
			local Content = self;
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



local function GenerateVoxelGrid(SizeX, SizeY, SizeZ)
	-- Generates a 3D array

	local VoxelGrid = {}
	for X = 1, SizeX do
		VoxelGrid[X] = {};
		for Y = 1, SizeY do
			VoxelGrid[X][Y] = {};
			for Z = 1, SizeZ do
				VoxelGrid[X][Y][Z] = "Slot @ "..X..", "..Y..", "..Z;
			end
		end
	end
	setmetatable(VoxelGrid, VoxelGridMetatable)
	-- So, I think VoxelGrid[X][Y][Z]
	return VoxelGrid;
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


local function MakeVoxelGrid()
	-- Makes a new VoxelGrid, aka a storage slot...
	local ItemGrid = {}
	ItemGrid.Type = "Voxel";
	ItemGrid.Content = GenerateVoxelGrid(10, 10, 10);
	return ItemGrid;
end

local VoxelGrid = MakeVoxelGrid()
local Count = 0
for Space in VoxelPairs(VoxelGrid) do
	Count = Count + 1;
	print(Count..Space)
end
print("Final iriterations: "..Count);
