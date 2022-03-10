--[=[
	@class SpawnerUtils
]=]

local SpawnerUtils = {}

function SpawnerUtils.getSpawnLocation(spawnPart, raycaster)
	local size = spawnPart.Size
	local sy = size.y

	local ox = (math.random() - 0.5)*size.x
	local oz = (math.random() - 0.5)*size.z

	local point = spawnPart.CFrame:pointToWorldSpace(Vector3.new(ox, sy/2, oz))

	local ray = Ray.new(point, Vector3.new(0, -sy*2, 0))

	local data = raycaster:FindPartOnRay(ray)
	if not data then
		return point
	end

	return data.Position, data
end

return SpawnerUtils