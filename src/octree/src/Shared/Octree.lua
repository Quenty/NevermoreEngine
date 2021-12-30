--[=[
	Octree implementation. An octree is a data structure that allows for quick spatial
	data queries of static objects. For example, trees can be stored in an octree, and
	nearby trees could be found near the player.

	Octrees exists as a grid of nodes, which are subdivided in half in each axis, which
	results in 8 different regions. This recursively happens to a set depth.

	This allows for O(n) data storage and log(n) retrieval of nearby objects. With a large
	quantity of items in the octree, this can make data retrieval significantly faster.

	See also: https://en.wikipedia.org/wiki/Octree

	```lua
	local octree = Octree.new()
	octree:CreateNode(Vector3.new(0, 0, 0), "A")
	octree:CreateNode(Vector3.new(0, 0, 0), "B")
	octree:CreateNode(Vector3.new(0, 0, 0), workspace)
	octree:CreateNode(Vector3.new(0, 0, 1000), "C")
	print(octree:RadiusSearch(Vector3.new(0, 0, 0), 100)) --> { "A", "B", workspace }
	```

	:::tip
	Octrees are best for static objects in the world, and not objects moving around, since then
	data can be statically cached.

	Sometimes using Roblox's spatial hash using the region API is faster than using an octree. However,
	for data that is centralized, or static, an octree can be a very efficient spatial query mechanism.
	:::

	@class Octree
]=]

local require = require(script.Parent.loader).load(script)

local OctreeRegionUtils = require("OctreeRegionUtils")
local OctreeNode = require("OctreeNode")

local EPSILON = 1e-9

local Octree = {}
Octree.ClassName = "Octree"
Octree.__index = Octree

--[=[
	Constructs a new Octree.

	@return Octree<T>
]=]
function Octree.new()
	local self = setmetatable({}, Octree)

	self._maxRegionSize = { 512, 512, 512 } -- these should all be the same number
	self._maxDepth = 4
	self._regionHashMap = {} -- [hash] = region

	return self
end

--[=[
	Returns all octree nodes stored in the octree!

	```lua
	local octree = Octree.new()
	octree:CreateNode(Vector3.new(0, 0, 0), "Hi")
	octree:CreateNode(Vector3.new(0, 0, 0), "Bob")
	print(octree:GetAllNodes()) --> { "Hi", "Bob" }
	```

	Order is not guaranteed.

	:::warning
	If you have 100,000 nodes in your octree, this is going to be very slow.
	:::

	@return { OctreeNode<T> }
]=]
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

--[=[
	Creates a new OctreeNode at the given position which can be retrieved

	:::tip
	Be sure to call :Destroy() on a node if the data becomes stale. Note that
	this is not necessary if the whole octree is removed from memory.
	:::

	```lua
	local octree = Octree.new()
	octree:CreateNode(Vector3.new(0, 0, 0), "A")
	octree:CreateNode(Vector3.new(0, 0, 0), "B")
	```

	@param position Vector3
	@param object T
	@return OctreeNode<T>
]=]
function Octree:CreateNode(position, object)
	assert(typeof(position) == "Vector3", "Bad position value")
	assert(object, "Bad object value")

	local node = OctreeNode.new(self, object)

	node:SetPosition(position)

	return node
end

--[=[
	Searches at the position and radius for any objects that may be within
	this radius.

	```lua
	local octree = Octree.new()
	octree:CreateNode(Vector3.new(0, 0, 0), "A")
	octree:CreateNode(Vector3.new(0, 0, 0), "B")
	octree:CreateNode(Vector3.new(0, 0, 1000), "C")
	print(octree:RadiusSearch(Vector3.new(0, 0, 0), 100)) --> { "A", "B" }
	```

	@param position Vector3
	@param radius number
	@return { T } -- Objects found
	@return { number } -- Distances squared
]=]
function Octree:RadiusSearch(position, radius)
	assert(typeof(position) == "Vector3", "Bad position")
	assert(type(radius) == "number", "Bad radius")

	local px, py, pz = position.x, position.y, position.z
	return self:_radiusSearch(px, py, pz, radius)
end

--[=[
	Searches at the position and radius for any objects that may be within
	this radius. Returns the knearest entries.

	The closest entities will be first in the list.

	@param position Vector3
	@param k number -- Number of objects to find
	@param radius number
	@return { any } -- Objects found
	@return { number } -- Distances squared
]=]
function Octree:KNearestNeighborsSearch(position, k, radius)
	assert(typeof(position) == "Vector3", "Bad position")
	assert(type(radius) == "number", "Bad radius")

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

--[=[
	Internal API to create lowest subregion

	@private
	@param px number
	@param py number
	@param pz number
	@return OctreeSubregion
]=]
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