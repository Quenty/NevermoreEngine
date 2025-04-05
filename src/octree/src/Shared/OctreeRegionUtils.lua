--!native
--!strict
--[=[
	Octree implementation utilities. Primarily this utility code
	should not be used directly and should be considered private to
	the library.

	Use [Octree](/api/Octree) instead of this library directly.

	@class OctreeRegionUtils
]=]

local require = require(script.Parent.loader).load(script)

local Draw = require("Draw")

local EPSILON = 1e-6
local SQRT_3_OVER_2 = math.sqrt(3) / 2
local SUB_REGION_POSITION_OFFSET = {
	{ 0.25, 0.25, -0.25 },
	{ -0.25, 0.25, -0.25 },
	{ 0.25, 0.25, 0.25 },
	{ -0.25, 0.25, 0.25 },
	{ 0.25, -0.25, -0.25 },
	{ -0.25, -0.25, -0.25 },
	{ 0.25, -0.25, 0.25 },
	{ -0.25, -0.25, 0.25 },
}

local OctreeRegionUtils = {}

--[=[
	A Vector3 equivalent for octrees. This type is primarily internal and
	used for faster access than a Vector3.

	@type OctreeVector3 { [1]: number, [2]: number, [3]: number }
	@within OctreeRegionUtils
]=]
export type OctreeVector3 = { number }

export type OctreeNode<T> = {
	GetRawPosition: (self: OctreeNode<T>) -> (number, number, number),
	GetObject: (self: OctreeNode<T>) -> T,
}

--[=[
	An internal region which stores the data.

	@interface OctreeRegion<T>
	.subRegions { OctreeRegion<T> }
	.lowerBounds OctreeVector3
	.upperBounds OctreeVector3
	.position OctreeVector3
	.size OctreeVector3
	.parent OctreeRegion<T>?
	.parentIndex number
	.depth number
	.nodes { OctreeNode<T> }
	.node_count number
	@within OctreeRegionUtils
]=]
export type OctreeRegion<T> = {
	subRegions: { OctreeRegion<T> },
	lowerBounds: OctreeVector3,
	upperBounds: OctreeVector3,
	position: OctreeVector3,
	size: OctreeVector3,
	parent: OctreeRegion<T>?,
	parentIndex: number?,
	depth: number,
	nodes: { [OctreeNode<T>]: OctreeNode<T> },
	node_count: number,
}

export type OctreeRegionHashMap<T> = { [number]: { OctreeRegion<T> } }

--[=[
	Visualizes the octree region.

	@param region OctreeRegion<T>
	@return MaidTask
]=]
function OctreeRegionUtils.visualize<T>(region: OctreeRegion<T>): Instance
	local size = region.size
	local position = region.position
	local sx, sy, sz = size[1], size[2], size[3]
	local px, py, pz = position[1], position[2], position[3]

	local box = Draw.box(Vector3.new(px, py, pz), Vector3.new(sx, sy, sz))
	box.Transparency = 0.9
	box.Name = "OctreeRegion_" .. tostring(region.depth)

	return box
end

--[=[
	Creates a new OctreeRegion<T>

	@param px number
	@param py number
	@param pz number
	@param sx number
	@param sy number
	@param sz number
	@param parent OctreeRegion<T>?
	@param parentIndex number?
	@return OctreeRegion<T>
]=]
function OctreeRegionUtils.create<T>(
	px: number,
	py: number,
	pz: number,
	sx: number,
	sy: number,
	sz: number,
	parent: OctreeRegion<T>?,
	parentIndex: number?
): OctreeRegion<T>
	local hsx, hsy, hsz = sx / 2, sy / 2, sz / 2

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
		},
		lowerBounds = { px - hsx, py - hsy, pz - hsz },
		upperBounds = { px + hsx, py + hsy, pz + hsz },
		position = { px, py, pz },
		size = { sx, sy, sz }, -- { sx, sy, sz }
		parent = parent,
		depth = parent and (parent.depth + 1) or 1,
		parentIndex = parentIndex,
		nodes = {}, -- [node] = true (contains subchild nodes too)
		node_count = 0,
	}

	-- if region.depth >= 5 then
	-- 	OctreeRegionUtils.visualize(region)
	-- end

	return region
end

--[=[
	Adds a node to the lowest subregion
	@param lowestSubregion OctreeRegion<T>
	@param node OctreeNode
]=]
function OctreeRegionUtils.addNode<T>(lowestSubregion: OctreeRegion<T>, node: OctreeNode<T>)
	assert(node, "Bad node")

	local current: OctreeRegion<T> = lowestSubregion
	while current do
		if not current.nodes[node] then
			current.nodes[node] = node :: OctreeNode<T>
			current.node_count = current.node_count + 1
		end
		current = current.parent :: OctreeRegion<T>
	end
end

--[=[
	Moves a node from one region to another

	@param fromLowest OctreeRegion<T>
	@param toLowest OctreeRegion<T>
	@param node OctreeNode
]=]
function OctreeRegionUtils.moveNode<T>(fromLowest: OctreeRegion<T>, toLowest: OctreeRegion<T>, node: OctreeNode<T>)
	assert(fromLowest.depth == toLowest.depth, "fromLowest.depth ~= toLowest.depth")
	assert(fromLowest ~= toLowest, "fromLowest == toLowest")

	local currentFrom: OctreeRegion<T> = fromLowest
	local currentTo: OctreeRegion<T> = toLowest
	while currentFrom ~= currentTo do
		-- remove from current
		do
			assert(currentFrom.nodes[node], "Not in currentFrom")
			assert(currentFrom.node_count > 0, "No nodes in currentFrom")

			currentFrom.nodes[node] = nil
			currentFrom.node_count -= 1

			-- remove subregion!
			local parentIndex = currentFrom.parentIndex
			if currentFrom.node_count <= 0 and parentIndex then
				assert(currentFrom.parent, "Bad currentFrom.parent")
				assert(currentFrom.parent.subRegions[parentIndex] == currentFrom, "Not in subregion")
				currentFrom.parent.subRegions[parentIndex] = nil
			end
		end

		-- add to new
		do
			assert(not currentTo.nodes[node], "Failed to add")
			currentTo.nodes[node] = node
			currentTo.node_count = currentTo.node_count + 1
		end

		currentFrom = currentFrom.parent :: OctreeRegion<T>
		currentTo = currentTo.parent :: OctreeRegion<T>
	end
end

--[=[
	Removes a node from the given region

	@param lowestSubregion OctreeRegion<T>
	@param node OctreeNode
]=]
function OctreeRegionUtils.removeNode<T>(lowestSubregion: OctreeRegion<T>, node: OctreeNode<T>)
	assert(node, "Bad node")

	local current: OctreeRegion<T> = lowestSubregion
	while current do
		assert(current.nodes[node], "Not in current")
		assert(current.node_count > 0, "Current has bad node count")

		current.nodes[node] = nil
		current.node_count -= 1

		-- remove subregion!
		local parentIndex = current.parentIndex
		if current.node_count <= 0 and parentIndex then
			assert(current.parent, "No parent")
			assert(current.parent.subRegions[parentIndex] == current, "Not in subregion")
			current.parent.subRegions[parentIndex] = nil
		end

		current = current.parent :: OctreeRegion<T>
	end
end

--[=[
	Retrieves the search radius for a given radius given the region
	diameter

	@param radius number
	@param diameter number
	@param epsilon number
	@return number
]=]
function OctreeRegionUtils.getSearchRadiusSquared(radius: number, diameter: number, epsilon: number): number
	local diagonal = SQRT_3_OVER_2 * diameter
	local searchRadius = radius + diagonal
	return searchRadius * searchRadius + epsilon
end

-- luacheck: push ignore
--[=[
	Adds all octree nod values to objectsFound

	See basic algorithm:
	https://github.com/PointCloudLibrary/pcl/blob/29f192af57a3e7bdde6ff490669b211d8148378f/octree/include/pcl/octree/impl/octree_search.hpp#L309

	@param region OctreeRegion<T>
	@param radius number
	@param px number
	@param py number
	@param pz number
	@param objectsFound { T }
	@param nodeDistances2 { number }
	@param maxDepth number
]=]
function OctreeRegionUtils.getNeighborsWithinRadius<T>(
	region: OctreeRegion<T>,
	radius: number,
	px: number,
	py: number,
	pz: number,
	objectsFound: { T },
	nodeDistances2: { number },
	maxDepth: number
)
	-- luacheck: pop
	assert(maxDepth, "Bad maxDepth")

	local childDiameter = region.size[1] / 2
	local searchRadiusSquared = OctreeRegionUtils.getSearchRadiusSquared(radius, childDiameter, EPSILON)

	local radiusSquared = radius * radius

	-- for each child
	for _, childRegion in region.subRegions do
		local cposition = childRegion.position
		local cpx, cpy, cpz = cposition[1], cposition[2], cposition[3]

		local ox, oy, oz = px - cpx, py - cpy, pz - cpz
		local dist2 = ox * ox + oy * oy + oz * oz

		-- within search radius
		if dist2 <= searchRadiusSquared then
			if childRegion.depth == maxDepth then
				for node, _ in childRegion.nodes do
					local npx, npy, npz = node:GetRawPosition()
					local nox, noy, noz = px - npx, py - npy, pz - npz
					local ndist2 = nox * nox + noy * noy + noz * noz
					if ndist2 <= radiusSquared then
						objectsFound[#objectsFound + 1] = node:GetObject()
						nodeDistances2[#nodeDistances2 + 1] = ndist2
					end
				end
			else
				OctreeRegionUtils.getNeighborsWithinRadius(
					childRegion,
					radius,
					px,
					py,
					pz,
					objectsFound,
					nodeDistances2,
					maxDepth
				)
			end
		end
	end
end

--[=[
	Recursively ensures that a subregion exists at a given depth, and returns
	that region for usage.

	@param region OctreeRegion<T> -- Top level region
	@param px number
	@param py number
	@param pz number
	@param maxDepth number
	@return OctreeRegion<T>
]=]
function OctreeRegionUtils.getOrCreateSubRegionAtDepth<T>(
	region: OctreeRegion<T>,
	px: number,
	py: number,
	pz: number,
	maxDepth: number
): OctreeRegion<T>
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

--[=[
	Creates a subregion for an octree.
	@param parentRegion OctreeRegion<T>
	@param parentIndex number
	@return OctreeRegion<T>
]=]
function OctreeRegionUtils.createSubRegion<T>(parentRegion: OctreeRegion<T>, parentIndex: number): OctreeRegion<T>
	local size = parentRegion.size
	local position = parentRegion.position
	local multiplier = SUB_REGION_POSITION_OFFSET[parentIndex]

	local px = position[1] + multiplier[1] * size[1]
	local py = position[2] + multiplier[2] * size[2]
	local pz = position[3] + multiplier[3] * size[3]
	local sx, sy, sz = size[1] / 2, size[2] / 2, size[3] / 2

	return OctreeRegionUtils.create(px, py, pz, sx, sy, sz, parentRegion, parentIndex)
end

--[=[
	Computes whether a region is in bounds.

	Consider regions to be range [px, y).

	@param region OctreeRegion<T>
	@param px number
	@param py number
	@param pz number
	@return boolean
]=]
function OctreeRegionUtils.inRegionBounds<T>(region: OctreeRegion<T>, px: number, py: number, pz: number): boolean
	local lowerBounds = region.lowerBounds
	local upperBounds = region.upperBounds
	return (
		px >= lowerBounds[1]
		and px <= upperBounds[1]
		and py >= lowerBounds[2]
		and py <= upperBounds[2]
		and pz >= lowerBounds[3]
		and pz <= upperBounds[3]
	)
end

--[=[
	Gets a subregion's internal index.

	@param region OctreeRegion<T>
	@param px number
	@param py number
	@param pz number
	@return number
]=]
function OctreeRegionUtils.getSubRegionIndex<T>(region: OctreeRegion<T>, px: number, py: number, pz: number): number
	local index = px > region.position[1] and 1 or 2
	if py <= region.position[2] then
		index = index + 4
	end

	if pz >= region.position[3] then
		index = index + 2
	end
	return index
end

--[=[
	This definitely collides fairly consistently

	See: https://stackoverflow.com/questions/5928725/hashing-2d-3d-and-nd-vectors

	@param cx number
	@param cy number
	@param cz number
	@return number
]=]
function OctreeRegionUtils.getTopLevelRegionHash(cx: number, cy: number, cz: number): number
	-- Normally you would modulus this to hash table size, but we want as flat of a structure as possible
	return cx * 73856093 + cy * 19351301 + cz * 83492791
end

--[=[
	Computes the index for a top level cell given a position

	@param maxRegionSize OctreeVector3
	@param px number
	@param py number
	@param pz number
	@return number -- rpx
	@return number -- rpy
	@return number -- rpz
]=]
function OctreeRegionUtils.getTopLevelRegionCellIndex(
	maxRegionSize: OctreeVector3,
	px: number,
	py: number,
	pz: number
): (number, number, number)
	return math.floor(px / maxRegionSize[1] + 0.5),
		math.floor(py / maxRegionSize[2] + 0.5),
		math.floor(pz / maxRegionSize[3] + 0.5)
end

--[=[
	Computes a top-level region's position

	@param maxRegionSize OctreeVector3
	@param cx number
	@param cy number
	@param cz number
	@return number
	@return number
	@return number
]=]
function OctreeRegionUtils.getTopLevelRegionPosition(
	maxRegionSize: OctreeVector3,
	cx: number,
	cy: number,
	cz: number
): (number, number, number)
	return maxRegionSize[1] * cx, maxRegionSize[2] * cy, maxRegionSize[3] * cz
end

--[=[
	Given a top-level region, returns if the region position are equal
	to this region

	@param region OctreeRegion<T>
	@param rpx number
	@param rpy number
	@param rpz number
	@return boolean
]=]
function OctreeRegionUtils.areEqualTopRegions<T>(region: OctreeRegion<T>, rpx: number, rpy: number, rpz: number)
	local position = region.position
	return position[1] == rpx and position[2] == rpy and position[3] == rpz
end

--[=[
	Given a world space position, finds the current region in the hashmap

	@param regionHashMap { [number]: { OctreeRegion<T> } }
	@param maxRegionSize OctreeVector3
	@param px number
	@param py number
	@param pz number
	@return OctreeRegion3?
]=]
function OctreeRegionUtils.findRegion<T>(
	regionHashMap: OctreeRegionHashMap<T>,
	maxRegionSize: OctreeVector3,
	px: number,
	py: number,
	pz: number
): OctreeRegion<T>?
	local cx, cy, cz = OctreeRegionUtils.getTopLevelRegionCellIndex(maxRegionSize, px, py, pz)
	local hash = OctreeRegionUtils.getTopLevelRegionHash(cx, cy, cz)

	local regionList: { OctreeRegion<T> } = regionHashMap[hash]
	if not regionList then
		return nil
	end

	local rpx, rpy, rpz = OctreeRegionUtils.getTopLevelRegionPosition(maxRegionSize, cx, cy, cz)
	for _, region in regionList do
		if OctreeRegionUtils.areEqualTopRegions(region, rpx, rpy, rpz) then
			return region
		end
	end

	return nil
end

--[=[
	Gets the current region for a position, or creates a new one.

	@param regionHashMap { [number]: { OctreeRegion<T> } }
	@param maxRegionSize OctreeVector3
	@param px number
	@param py number
	@param pz number
	@return OctreeRegion<T>
]=]
function OctreeRegionUtils.getOrCreateRegion<T>(regionHashMap: OctreeRegionHashMap<T>, maxRegionSize: OctreeVector3, px: number, py: never, pz: number): OctreeRegion<T>
	local cx, cy, cz = OctreeRegionUtils.getTopLevelRegionCellIndex(maxRegionSize, px, py, pz)
	local hash = OctreeRegionUtils.getTopLevelRegionHash(cx, cy, cz)

	local regionList = regionHashMap[hash]
	if not regionList then
		regionList = {}
		regionHashMap[hash] = regionList
	end

	local rpx, rpy, rpz = OctreeRegionUtils.getTopLevelRegionPosition(maxRegionSize, cx, cy, cz)
	for _, region in regionList do
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