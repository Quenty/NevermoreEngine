local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Terrain = Workspace.Terrain

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")

qSystems:Import(getfenv(0))

-- This library handles generating water with terrain.
-- WaterGenerator.lua
-- @author Quenty

local WaterGenerator = {}

local WorldToCell = Terrain.WorldToCell
local SetWaterCell = Terrain.SetWaterCell
local GetCell = Terrain.GetCell 
local SetCell = Terrain.SetCell 
local SetCells = Terrain.SetCells

local function Vector3int16FromVector3(Vector3)
	return Vector3int16.new(Vector3.X, Vector3.Y, Vector3.Z)
end

local function LoadWater(Low, High, DoLoadSlow)
	-- @param Low Vector3, the low position to load. 
	-- @param High Vector3, the high position to load. 

	local LowCell  = WorldToCell(Terrain, Low)
	local HighCell = WorldToCell(Terrain, High)

	if Low.X > High.X then
		error("[WaterGenerator] - Low.X was > High.X")
	elseif Low.Y > High.Y then
		error("[WaterGenerator] - Low.Y was > High.Y")
	elseif Low.Z > High.Z then
		error("[WaterGenerator] - Low.Z was > High.Z")
	end

	local LowCellY = LowCell.Y
	local LowCellX = LowCell.X
	local LowCellZ = LowCell.Z

	local CurrentY = HighCell.Y -- We're start at the top and go down for Y.
	
	local HighCellX = HighCell.X
	local HighCellZ = HighCell.Z

	if DoLoadSlow then
		while CurrentY > LowCellY do
			local CurrentX = LowCellX

			while CurrentX <= HighCellX do
				local CurrentZ = LowCellZ

				while CurrentZ <= HighCellZ do
					SetWaterCell(Terrain, CurrentX, CurrentY, CurrentZ, "None", "X")
					CurrentZ = CurrentZ + 1
					-- print("CurrentZ = " .. CurrentZ)
				end
				CurrentX = CurrentX + 1
				-- print("CurrentX = " .. CurrentX)
				if CurrentX % 10 == 1 then
					wait()
				end
			end
			CurrentY = CurrentY - 1
			-- print("CurrentY = " .. CurrentY)
		end
	else
		while CurrentY > LowCellY do
			local CurrentX = LowCellX

			while CurrentX <= HighCellX do
				local CurrentZ = LowCellZ

				while CurrentZ <= HighCellZ do
					SetWaterCell(Terrain, CurrentX, CurrentY, CurrentZ, "None", "X")
					CurrentZ = CurrentZ + 1
					-- print("CurrentZ = " .. CurrentZ)
				end
				CurrentX = CurrentX + 1
				-- print("CurrentX = " .. CurrentX)
			end
			CurrentY = CurrentY - 1
			-- print("CurrentY = " .. CurrentY)
			-- wait()
		end
	end

	-- Set sand at bottom.
	SetCells(Terrain, Region3int16.new(Vector3int16.new(LowCell.X, LowCellY, LowCell.Z), Vector3int16.new(HighCell.X, LowCellY, HighCell.Z)), "Sand", "Solid", "X")
end
WaterGenerator.LoadWater = LoadWater

local function UnloadWater(Low, High)
	local LowCell  = WorldToCell(Terrain, Low)
	local HighCell = WorldToCell(Terrain, High)

	if Low.X > High.X then
		error("[WaterGenerator] - Low.X was > High.X")
	elseif Low.Y > High.Y then
		error("[WaterGenerator] - Low.Y was > High.Y")
	elseif Low.Z > High.Z then
		error("[WaterGenerator] - Low.Z was > High.Z")
	end


	-- Remove sand at bottom
	SetCells(Terrain, Region3int16.new(Vector3int16.new(LowCell.X, LowCell.Y, LowCell.Z), Vector3int16.new(HighCell.X, HighCell.Y, HighCell.Z)), "Empty", "Solid", "X")
end
WaterGenerator.UnloadWater = UnloadWater


return WaterGenerator

