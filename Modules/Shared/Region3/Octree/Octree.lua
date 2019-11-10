--- Octree implementation
-- @classmod Octree

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local OctreeRegionUtils = require("OctreeRegionUtils")
local OctreeNode = require("OctreeNode")

local EPSILON = 1e-6

local Octree = {}
Octree.ClassName = "Octree"
Octree.__index = Octree

function Octree.new()
	local self = setmetatable({}, Octree)

	self._maxRegionSize = { 256, 256, 256 } -- these should all be the same number
	self._maxDepth = 4
	self._regions = {} -- [hash] = region

	return self
end

function Octree:GetAllNodes()
	local options = {}

	for _, region in pairs(self._regions) do
		for node, _ in pairs(region.nodes) do
			options[#options+1] = node
		end
	end

	return options
end

function Octree:CreateNode(position, object)
	assert(typeof(position) == "Vector3")
	assert(object)

	local node = OctreeNode.new(self, object)

	node:SetPosition(position)

	return node
end

function Octree:RadiusSearch(position, radius)
	assert(typeof(position) == "Vector3")
	assert(type(radius) == "number")

	local radiusSquared = radius*radius
	local px, py, pz = position.x, position.y, position.z
	return self:_radiusSearch(px, py, pz, radiusSquared)
end

function Octree:KNearestNeighborsSearch(position, k, radius)
	assert(typeof(position) == "Vector3")
	assert(type(radius) == "number")

	local radiusSquared = radius*radius
	local px, py, pz = position.x, position.y, position.z
	local objects, nodeDistances2 = self:_radiusSearch(px, py, pz, radiusSquared)

	local sortable = {}
	for index, dist2 in pairs(nodeDistances2) do
		table.insert(sortable, {
			dist2 = dist2;
			index = index;
		})
	end

	table.sort(sortable, function(a, b)
		return a.dist2 < b.dist2
	end)

	local knearest = {}
	local knearestDist2 = {}
	for i = 1, math.min(#sortable, k) do
		local sorted = sortable[i]
		knearestDist2[#knearestDist2 + 1] = sorted.dist2
		knearest[#knearest + 1] = objects[sorted.index]
	end

	return knearest, knearestDist2
end

function Octree:CreateLowestSubRegion(px, py, pz)
	local region = self:_createRegion(px, py, pz)
	return OctreeRegionUtils.createSubRegionAtDepth(region, px, py, pz, self._maxDepth)
end

function Octree:_radiusSearch(px, py, pz, radiusSquared)
	local objectsFound = {}
	local nodeDistances2 = {}

	local regionDiameter = self._maxRegionSize[1]
	local regionDiameterSquared = regionDiameter*regionDiameter
	local searchRadius = regionDiameterSquared/4 + radiusSquared + math.sqrt((regionDiameterSquared)*radiusSquared)
		- EPSILON

	for _, region in pairs(self._regions) do
		local rpos = region.position
		local rpx, rpy, rpz = rpos[1], rpos[2], rpos[3]
		local ox, oy, oz = px - rpx, py - rpy, pz - rpz
		local dist2 = ox*ox + oy*oy + oz*oz

		if dist2 <= searchRadius then
			OctreeRegionUtils.getNeighborsWithinRadius(
				region, radiusSquared, px, py, pz, objectsFound, nodeDistances2, self._maxDepth)
		end
	end

	return objectsFound, nodeDistances2
end

function Octree:_getDeepistRegion(px, py, pz, maxDepth)
	local region = self:_getRegion(px, py, pz)
	return OctreeRegionUtils.getDeepestRegion(region, px, py, pz, maxDepth)
end

function Octree:_getRegion(px, py, pz)
	local cx, cy, cz = self:_getRegionCellIndex(px, py, pz)
	local index = self:_getRegionIndex(cx, cy, cz)
	return self._regions[index]
end

function Octree:_createRegion(px, py, pz)
	local cx, cy, cz = self:_getRegionCellIndex(px, py, pz)

	local index = self:_getRegionIndex(cx, cy, cz)

	if self._regions[index] then
		return self._regions[index]
	end

	local regionPosition = self:_getRegionPosition(cx, cy, cz)
	local region = OctreeRegionUtils.create(
		regionPosition[1], regionPosition[2], regionPosition[3],
		self._maxRegionSize[1], self._maxRegionSize[2], self._maxRegionSize[3])

	self._regions[index] = region

	return region
end

function Octree:_getRegionCellIndex(px, py, pz)
	return math.floor(px / self._maxRegionSize[1] + 0.5),
		math.floor(py / self._maxRegionSize[2] + 0.5),
		math.floor(pz / self._maxRegionSize[3] + 0.5)
end

--- spooky, will this collide?
function Octree:_getRegionIndex(cx, cy, cz)
	-- https://stackoverflow.com/questions/5928725/hashing-2d-3d-and-nd-vectors

	return bit32.bxor(cx * 73856093, cy*19351301, cz*83492791)
end

function Octree:_getRegionPosition(cx, cy, cz)
	return {
		self._maxRegionSize[1] * cx,
		self._maxRegionSize[2] * cy,
		self._maxRegionSize[3] * cz
	}
end

return Octree