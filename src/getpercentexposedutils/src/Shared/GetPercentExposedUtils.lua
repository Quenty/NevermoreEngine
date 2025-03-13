--!strict
--[=[
	Identify parts that are potentially exposed to an explosion using a random vector raycasting
	@class GetPercentExposedUtils
]=]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local RandomVector3Utils = require("RandomVector3Utils")

local GetPercentExposedUtils = {}

--[=[
	Number of rays to use when searching
	@readonly
	@prop RAY_COUNT number
	@within GetPercentExposedUtils
]=]
GetPercentExposedUtils.RAY_COUNT = 314

--[=[
	Searches for percent exposure of all parts given.

	@param point Vector3 -- Point to search
	@param radius number
	@param raycaster Raycaster?
	@return { [BasePart]: number } -- A table mapping parts to to percent exposure
]=]
function GetPercentExposedUtils.search(point: Vector3, radius: number, raycaster): { [BasePart]: number }
	local hits = {}
	local totalHits = 0

	for _=1, GetPercentExposedUtils.RAY_COUNT do
		local ray = Ray.new(point, RandomVector3Utils.getRandomUnitVector() * radius)
		if raycaster then
			local hitData = raycaster:FindPartOnRay(ray)
			if hitData then
				totalHits = totalHits + 1
				hits[hitData.Part] = (hits[hitData.Part] or 0) + 1
			end
		else
			local part = Workspace:FindPartOnRay(ray, nil, true) -- Ignore water
			if part then
				totalHits = totalHits + 1
				hits[part] = (hits[part] or 0) + 1
			end
		end
	end

	if totalHits <= 0 then
		return hits
	end

	for part, count in hits do
		hits[part] = count / GetPercentExposedUtils.RAY_COUNT
	end

	return hits
end

return GetPercentExposedUtils