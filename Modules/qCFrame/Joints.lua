local lib = {}

-- Joints.lua
-- @author Quenty
-- A library dedicated to working with ROBLOX joints.

local function GetRelativeCFrameValues(BasePart, Bricks)
	--- Oftentimes it's valuable to have a relative location of every single part
	--  in a table. This function calculates that
	-- @param BasePart The basepart it'll be relative to
	-- @param Bricks Array of bricks to use
	-- @return Hashmap
		 -- [Part] = CFrame value of the part in the BasePart's world space.

	local RelativeCFrameValues = {}

	for _, Brick in pairs(Bricks) do
		RelativeCFrameValues[Brick] = BasePart.CFrame:toObjectSpace(Brick.CFrame)
	end

	return RelativeCFrameValues
end
lib.GetRelativeCFrameValues = GetRelativeCFrameValues

return lib