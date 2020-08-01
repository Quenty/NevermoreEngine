--- Octree implementation
-- @classmod Octree

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local OctreeRegionUtils = require("OctreeRegionUtils")
local OctreeNode = require("OctreeNode")

local EPSILON = 1e-9

local Octree = {}
Octree.ClassName = "Octree"
Octree.__index = Octree

function Octree.new()
	local self = setmetatable({}, Octree)

	self._maxRegionSize = { 512, 512, 512 } -- these should all be the same number
	self._maxDepth = 4
	self._regionHashMap = {} -- [hash] = region

	return self
end

function Octree:GetAllNodes()
	local options = {}

	for _, regionList in pairs(self._regionHashMap) do
		for _, region in pairs(regionList) do
			for node, _ in pairs(region.nodes) do
				options[#options+1] = node
			end
		end
	end

	return options
end

function Octree:CreateNode(position, object)
	assert(typeof(position) == "Vector3", "Bad position value")
	assert(object, "Bad object value")

	local node = OctreeNode.new(self, object)

	node:SetPosition(position)

	return node
end

function Octree:RadiusSearch(position, radius)
	assert(typeof(position) == "Vector3")
	assert(type(radius) == "number")

	local px, py, pz = position.x, position.y, position.z
	return self:_radiusSearch(px, py, pz, radius)
end

function Octree:KNearestNeighborsSearch(position, k, radius)
	assert(typeof(position) == "Vector3")
	assert(type(radius) == "number")

	local px, py, pz = position.x, position.y, position.z
	local objects, nodeDistances2 = self:_radiusSearch(px, py, pz, radius)

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

function Octree:GetOrCreateLowestSubRegion(px, py, pz)
	local region = self:_getOrCreateRegion(px, py, pz)
	return OctreeRegionUtils.getOrCreateSubRegionAtDepth(region, px, py, pz, self._maxDepth)
end

function Octree:_radiusSearch(px, py, pz, radius)
	local objectsFound = {}
	local nodeDistances2 = {}

	local diameter = self._maxRegionSize[1]
	local searchRadiusSquared = OctreeRegionUtils.getSearchRadiusSquared(radius, diameter, EPSILON)

	for _, regionList in pairs(self._regionHashMap) do
		for _, region in pairs(regionList) do
			local rpos = region.position
			local rpx, rpy, rpz = rpos[1], rpos[2], rpos[3]
			local ox, oy, oz = px - rpx, py - rpy, pz - rpz
			local dist2 = ox*ox + oy*oy + oz*oz

			if dist2 <= searchRadiusSquared then
				OctreeRegionUtils.getNeighborsWithinRadius(
					region, radius, px, py, pz, objectsFound, nodeDistances2, self._maxDepth)
			end
		end
	end

	return objectsFound, nodeDistances2
end

function Octree:_getRegion(px, py, pz)
	return OctreeRegionUtils.findRegion(self._regionHashMap, self._maxRegionSize, px, py, pz)
end

function Octree:_getOrCreateRegion(px, py, pz)
	return OctreeRegionUtils.getOrCreateRegion(self._regionHashMap, self._maxRegionSize, px, py, pz)
end

return Octree