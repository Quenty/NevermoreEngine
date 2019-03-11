--- Identify parts that are potentially exposed to an explosion using a random vector raycasting
-- @module GetPercentExposed

local Workspace = game:GetService("Workspace")

local lib = {}
lib.RAY_COUNT = 314

--- Equal distribution unit vectors around a sphere
local function getRandomUnitVector()
	local s = 2*math.random()
	local t = 6.2831853071796*math.random()
	local rx = s
	local m = (1-s*s)^0.5
	local ry = m*math.cos(t)
	local rz = m*math.sin(t)
	return Vector3.new(rx,ry,rz)
end

--- Searches for percent exposure of all parts given
-- @tparam Vector3 point point to search
-- @tparam number Radius
-- @return A table mapping parts to to percent exposure
function lib.Search(point, radius)
	local hits = {}
	local totalHits = 0
	for _=1, lib.RAY_COUNT do
		local ray = Ray.new(point, getRandomUnitVector() * radius)
		local part = Workspace:FindPartOnRay(ray, nil, true) -- Ignore water
		if part then
			totalHits = totalHits + 1
			hits[part] = (hits[part] or 0) + 1
		end
	end

	if totalHits <= 0 then
		return hits
	end

	for part, count in pairs(hits) do
		hits[part] = count / lib.RAY_COUNT
	end

	return hits
end


return lib