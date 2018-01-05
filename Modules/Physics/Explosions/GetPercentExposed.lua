--- Identify parts that are potentially exposed to an explosion using a random vector
-- and raycasting
-- @module GetPercentExposed

local lib = {}

--- Equal distribution unit vectors around a sphere
local function GetRandomUnitVector()
	local s = 2*math.random()
	local t = 6.2831853071796*math.random()
	local rx = s
	local m = (1-s*s)^0.5
	local ry = m*math.cos(t)
	local rz = m*math.sin(t)
	return Vector3.new(rx,ry,rz)
end

--- Searches for percent exposure
-- @param Parts Whitelist parts to search for
-- @return A table mapping parts to to percent exposure
function lib.Search(Parts, Point, Radius)
	local HitCount = {}
	for _, Part in pairs(Parts) do
		HitCount[Part] = 0
	end

	local TotalHit = 0
	local RaysToCast = 314
	for _=1, RaysToCast do
		local Direction = GetRandomUnitVector()
		local CastRay = Ray.new(Point, Direction * Radius)

		-- Ignore water
		local Hit = workspace:FindPartOnRayWithWhitelist(CastRay, Parts, true)
		if Hit then
			TotalHit = TotalHit + 1
			HitCount[Hit] = HitCount[Hit] + 1
		end
	end

	if TotalHit > 0 then
		for BasePart, Count in pairs(HitCount) do
			HitCount[BasePart] = Count / RaysToCast --/ TotalHit
		end
	end

	return HitCount
end


return lib