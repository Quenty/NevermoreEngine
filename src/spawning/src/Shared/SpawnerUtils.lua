--!strict
--[=[
	@class SpawnerUtils
]=]

local require = require(script.Parent.loader).load(script)

local Raycaster = require("Raycaster")

local SpawnerUtils = {}

function SpawnerUtils.getSpawnLocation(spawnPart: BasePart, raycaster: Raycaster.Raycaster): (Vector3, Raycaster.RaycastData?)
	local size = spawnPart.Size
	local sy = size.Y

	local ox = (math.random() - 0.5) * size.X
	local oz = (math.random() - 0.5) * size.Z

	local point = spawnPart.CFrame:PointToWorldSpace(Vector3.new(ox, sy / 2, oz))

	local ray = Ray.new(point, Vector3.new(0, -sy*2, 0))

	local data = raycaster:FindPartOnRay(ray)
	if not data then
		return point
	end

	return data.Position, data
end

return SpawnerUtils