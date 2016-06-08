local FindPartOnRayWithIgnoreList = workspace.FindPartOnRayWithIgnoreList





-- THERE IS A MAJOR EDGE CASE.
-- If the parts being added into the IgnoreList eventually should not be ignored
-- THEN THIS SYSTEM WILL NOT WORK AS EXPECTED.

-- NOTE: This module may also leak parts if used for long durations





local function AdvanceRaycastFactory(IgnoreHit, IgnoreList, TerrainCellsAreCubes, IgnoreWater)
	--- Returns a function to handle raycasting that will
	--  cast until IgnoreHit works out.
	-- @param IgnoreHit function IgnoreHit(Hit, Position, SurfaceNormal, Material)
		-- @param Hit object, the hit object
		-- @param Position The position that was hit.
		-- @param SurfaceNormal The surface normal of the surface it hit.
		-- @param Material The material it hit
		-- @return bool, true if the hit should be ignored and added
		--         to the ignore list, ...
		--         Where '...' is passed on out of the function.
	-- @param IgnoreList table, The IgnoreList to use
	
	if TerrainCellsAreCubes == nil then
		TerrainCellsAreCubes = true
	end
	
	local IgnoreList = IgnoreList or {}

	local function CleanIgnoreList()
		--- Cleans the ignore list by removing all items in it
		--  not in the game. Weaktable implimentation fails here because
		--  in-game references do

		local Index = 1

		while Index <= #IgnoreList do
			local Part = IgnoreList[Index]
			if not Part:IsDescendantOf(game) then
				table.remove(IgnoreList, Index)
			else
				Index = Index + 1
			end
		end
	end

	return function(RayCast, MaxCasts)
		--- Casts RayCast until IgnoreHit is satisified or nil is returned.
		-- @param RayCast The ray to cast
		-- @param [MaxCasts] Maximum casts before aborting and returning nil. Defaults to 5.`
		-- @return Hit, Position, SurfaceNormal, Material, ... 
			-- where '...' Is anything that IgnoreHit returns past its first argument (Which is whether to ignore or not)
		
		MaxCasts = MaxCasts or 5

		CleanIgnoreList()

		local Hit, Position, SurfaceNormal, Material
		local CastsCasted = 0

		repeat
			Hit, Position, SurfaceNormal, Material = FindPartOnRayWithIgnoreList(workspace, RayCast, IgnoreList, TerrainCellsAreCubes, IgnoreWater)
			CastsCasted = CastsCasted + 1

			if Hit and Position and SurfaceNormal then
				local CaughtTuple = {IgnoreHit(Hit, Position, SurfaceNormal, Material)}
				
				if CaughtTuple[1] then
					table.insert(IgnoreList, Hit)
				else
					
					table.remove(CaughtTuple, 1)
					return Hit, Position, SurfaceNormal, Material, unpack(CaughtTuple)
				end
			end
		until not (Hit and Position and SurfaceNormal) or CastsCasted >= MaxCasts

		return nil, nil, nil, nil
	end
end

return AdvanceRaycastFactory