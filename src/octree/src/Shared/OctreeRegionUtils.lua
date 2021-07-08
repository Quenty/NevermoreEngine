--- Octree implementation
-- @module OctreeRegionUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Draw = require("Draw")

local EPSILON = 1e-6
local SQRT_3_OVER_2 = math.sqrt(3)/2
local SUB_REGION_POSITION_OFFSET = {
	{ 0.25, 0.25, -0.25 };
	{ -0.25, 0.25, -0.25 };
	{ 0.25, 0.25, 0.25 };
	{ -0.25, 0.25, 0.25 };
	{ 0.25, -0.25, -0.25 };
	{ -0.25, -0.25, -0.25 };
	{ 0.25, -0.25, 0.25 };
	{ -0.25, -0.25, 0.25 };
}

local OctreeRegionUtils = {}

function OctreeRegionUtils.visualize(region)
	local size = region.size
	local position = region.position
	local sx, sy, sz = size[1], size[2], size[3]
	local px, py, pz = position[1], position[2], position[3]

	local box = Draw.box(Vector3.new(px, py, pz), Vector3.new(sx, sy, sz))
	box.Transparency = 0.9
	box.Name = "OctreeRegion_" .. tostring(region.depth)

	return box
end

function OctreeRegionUtils.create(px, py, pz, sx, sy, sz, parent, parentIndex)
	local hsx, hsy, hsz = sx/2, sy/2, sz/2

	local region = {
		subRegions = {
			--topNorthEast
			--topNorthWest
			--topSouthEast
			--topSouthWest
			--bottomNorthEast
			--bottomNorthWest
			--bottomSouthEast
			--bottomSouthWest
		};
		lowerBounds = { px - hsx, py - hsy, pz - hsz };
		upperBounds = { px + hsx, py + hsy, pz + hsz };
		position = { px, py, pz };
		size = { sx, sy, sz }; -- { sx, sy, sz }
		parent = parent;
		depth = parent and (parent.depth + 1) or 1;
		parentIndex = parentIndex;
		nodes = {}; -- [node] = true (contains subchild nodes too)
		node_count = 0;
	}

	-- if region.depth >= 5 then
	-- 	OctreeRegionUtils.visualize(region)
	-- end

	return region
end

function OctreeRegionUtils.addNode(lowestSubregion, node)
	assert(node)

	local current = lowestSubregion
	while current do
		if not current.nodes[node] then
			current.nodes[node] = node
			current.node_count = current.node_count + 1
		end
		current = current.parent
	end
end

function OctreeRegionUtils.moveNode(fromLowest, toLowest, node)
	assert(fromLowest.depth == toLowest.depth, "fromLowest.depth ~= toLowest.depth")
	assert(fromLowest ~= toLowest, "fromLowest == toLowest")

	local currentFrom = fromLowest
	local currentTo = toLowest
	while currentFrom ~= currentTo do
		-- remove from current
		do
			assert(currentFrom.nodes[node])
			assert(currentFrom.node_count > 0)

			currentFrom.nodes[node] = nil
			currentFrom.node_count = currentFrom.node_count - 1

			-- remove subregion!
			if currentFrom.node_count <= 0 and currentFrom.parentIndex then
				assert(currentFrom.parent)
				assert(currentFrom.parent.subRegions[currentFrom.parentIndex] == currentFrom)
				currentFrom.parent.subRegions[currentFrom.parentIndex] = nil
			end
		end

		-- add to new
		do
			assert(not currentTo.nodes[node])
			currentTo.nodes[node] = node
			currentTo.node_count = currentTo.node_count + 1
		end

		currentFrom = currentFrom.parent
		currentTo = currentTo.parent
	end
end

function OctreeRegionUtils.removeNode(lowestSubregion, node)
	assert(node)

	local current = lowestSubregion
	while current do
		assert(current.nodes[node])
		assert(current.node_count > 0)

		current.nodes[node] = nil
		current.node_count = current.node_count - 1

		-- remove subregion!
		if current.node_count <= 0 and current.parentIndex then
			assert(current.parent)
			assert(current.parent.subRegions[current.parentIndex] == current)
			current.parent.subRegions[current.parentIndex] = nil
		end

		current = current.parent
	end
end

function OctreeRegionUtils.getSearchRadiusSquared(radius, diameter, epsilon)
	local diagonal = SQRT_3_OVER_2*diameter
	local searchRadius = radius + diagonal
	return searchRadius*searchRadius + epsilon
end

-- See basic algorithm:
-- luacheck: push ignore
-- https://github.com/PointCloudLibrary/pcl/blob/29f192af57a3e7bdde6ff490669b211d8148378f/octree/include/pcl/octree/impl/octree_search.hpp#L309
-- luacheck: pop
function OctreeRegionUtils.getNeighborsWithinRadius(
		region, radius, px, py, pz, objectsFound, nodeDistances2, maxDepth)
	assert(maxDepth)

	local childDiameter = region.size[1]/2
	local searchRadiusSquared = OctreeRegionUtils.getSearchRadiusSquared(radius, childDiameter, EPSILON)

	local radiusSquared = radius*radius

	-- for each child
	for _, childRegion in pairs(region.subRegions) do
		local cposition = childRegion.position
		local cpx, cpy, cpz = cposition[1], cposition[2], cposition[3]

		local ox, oy, oz = px - cpx, py - cpy, pz - cpz
		local dist2 = ox*ox + oy*oy + oz*oz

		-- within search radius
		if dist2 <= searchRadiusSquared then
			if childRegion.depth == maxDepth then
				for node, _ in pairs(childRegion.nodes) do
					local npx, npy, npz = node:GetRawPosition()
					local nox, noy, noz = px - npx, py - npy, pz - npz
					local ndist2 = nox*nox + noy*noy + noz*noz
					if ndist2 <= radiusSquared then
						objectsFound[#objectsFound + 1] = node:GetObject()
						nodeDistances2[#nodeDistances2 + 1] = ndist2
					end
				end
			else
				OctreeRegionUtils.getNeighborsWithinRadius(
					childRegion, radius, px, py, pz, objectsFound, nodeDistances2, maxDepth)
			end
		end
	end
end

function OctreeRegionUtils.getOrCreateSubRegionAtDepth(region, px, py, pz, maxDepth)
	local current = region
	for _ = region.depth, maxDepth do
		local index = OctreeRegionUtils.getSubRegionIndex(current, px, py, pz)
		local _next = current.subRegions[index]

		-- construct
		if not _next then
			_next = OctreeRegionUtils.createSubRegion(current, index)
			current.subRegions[index] = _next
		end

		-- iterate
		current = _next
	end
	return current
end

function OctreeRegionUtils.createSubRegion(parentRegion, parentIndex)
	local size = parentRegion.size
	local position = parentRegion.position
	local multiplier = SUB_REGION_POSITION_OFFSET[parentIndex]

	local px = position[1] + multiplier[1]*size[1]
	local py = position[2] + multiplier[2]*size[2]
	local pz = position[3] + multiplier[3]*size[3]
	local sx, sy, sz = size[1]/2, size[2]/2, size[3]/2

	return OctreeRegionUtils.create(px, py, pz, sx, sy, sz, parentRegion, parentIndex)
end

-- Consider regions to be range [px, y)
function OctreeRegionUtils.inRegionBounds(region, px, py, pz)
	local lowerBounds = region.lowerBounds
	local upperBounds = region.upperBounds
	return (
		px >= lowerBounds[1] and px <= upperBounds[1] and
		py >= lowerBounds[2] and py <= upperBounds[2] and
		pz >= lowerBounds[3] and pz <= upperBounds[3]
	)
end

function OctreeRegionUtils.getSubRegionIndex(region, px, py, pz)
	local index = px > region.position[1] and 1 or 2
	if py <= region.position[2] then
		index = index + 4
	end

	if pz >= region.position[3] then
		index = index + 2
	end
	return index
end

--- This definitely collides
-- https://stackoverflow.com/questions/5928725/hashing-2d-3d-and-nd-vectors
function OctreeRegionUtils.getTopLevelRegionHash(cx, cy, cz)
	-- Normally you would modulus this to hash table size, but we want as flat of a structure as possible
	return cx * 73856093 + cy*19351301 + cz*83492791
end

function OctreeRegionUtils.getTopLevelRegionCellIndex(maxRegionSize, px, py, pz)
	return math.floor(px / maxRegionSize[1] + 0.5),
		math.floor(py / maxRegionSize[2] + 0.5),
		math.floor(pz / maxRegionSize[3] + 0.5)
end

function OctreeRegionUtils.getTopLevelRegionPosition(maxRegionSize, cx, cy, cz)
	return maxRegionSize[1] * cx,
		maxRegionSize[2] * cy,
		maxRegionSize[3] * cz
end

function OctreeRegionUtils.areEqualTopRegions(region, rpx, rpy, rpz)
	local position = region.position
	return position[1] == rpx
		and position[2] == rpy
		and position[3] == rpz
end

function OctreeRegionUtils.findRegion(regionHashMap, maxRegionSize, px, py, pz)
	local cx, cy, cz = OctreeRegionUtils.getTopLevelRegionCellIndex(maxRegionSize, px, py, pz)
	local hash = OctreeRegionUtils.getTopLevelRegionHash(cx, cy, cz)

	local regionList = regionHashMap[hash]
	if not regionList then
		return nil
	end

	local rpx, rpy, rpz = OctreeRegionUtils.getTopLevelRegionPosition(maxRegionSize, cx, cy, cz)
	for _, region in pairs(regionList) do
		if OctreeRegionUtils.areEqualTopRegions(region, rpx, rpy, rpz) then
			return region
		end
	end

	return nil
end

function OctreeRegionUtils.getOrCreateRegion(regionHashMap, maxRegionSize, px, py, pz)
	local cx, cy, cz = OctreeRegionUtils.getTopLevelRegionCellIndex(maxRegionSize, px, py, pz)
	local hash = OctreeRegionUtils.getTopLevelRegionHash(cx, cy, cz)

	local regionList = regionHashMap[hash]
	if not regionList then
		regionList = {}
		regionHashMap[hash] = regionList
	end

	local rpx, rpy, rpz = OctreeRegionUtils.getTopLevelRegionPosition(maxRegionSize, cx, cy, cz)
	for _, region in pairs(regionList) do
		if OctreeRegionUtils.areEqualTopRegions(region, rpx, rpy, rpz) then
			return region
		end
	end

	local region = OctreeRegionUtils.create(
		rpx, rpy, rpz,
		maxRegionSize[1], maxRegionSize[2], maxRegionSize[3])
	table.insert(regionList, region)

	return region
end

return OctreeRegionUtils