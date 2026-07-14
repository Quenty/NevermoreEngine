--!nonstrict
--[[
	@class OctreeRegionUtils.spec.lua
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local Jest = require("Jest")
local OctreeRegionUtils = require("OctreeRegionUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local MAX_REGION_SIZE = { 512, 512, 512 }

-- Minimal fake node implementing the OctreeNode interface used by the region utils
local function fakeNode(px, py, pz, object)
	return {
		GetRawPosition = function()
			return px, py, pz
		end,
		GetObject = function()
			return object
		end,
	}
end

describe("OctreeRegionUtils.create", function()
	it("computes bounds, position, and size from center + size", function()
		local region = OctreeRegionUtils.create(0, 0, 0, 512, 512, 512)

		expect(region.position[1]).toBe(0)
		expect(region.position[2]).toBe(0)
		expect(region.position[3]).toBe(0)

		expect(region.size[1]).toBe(512)
		expect(region.size[2]).toBe(512)
		expect(region.size[3]).toBe(512)

		expect(region.lowerBounds[1]).toBe(-256)
		expect(region.lowerBounds[2]).toBe(-256)
		expect(region.lowerBounds[3]).toBe(-256)

		expect(region.upperBounds[1]).toBe(256)
		expect(region.upperBounds[2]).toBe(256)
		expect(region.upperBounds[3]).toBe(256)
	end)

	it("starts empty and at depth 1 when it has no parent", function()
		local region = OctreeRegionUtils.create(0, 0, 0, 512, 512, 512)

		expect(region.depth).toBe(1)
		expect(region.parent).toBeNil()
		expect(region.parentIndex).toBeNil()
		expect(region.node_count).toBe(0)
		expect(next(region.nodes)).toBeNil()
		expect(next(region.subRegions)).toBeNil()
	end)

	it("derives depth from its parent", function()
		local parent = OctreeRegionUtils.create(0, 0, 0, 512, 512, 512)
		local child = OctreeRegionUtils.create(128, 128, 128, 256, 256, 256, parent, 3)

		expect(child.depth).toBe(2)
		expect(child.parent).toBe(parent)
		expect(child.parentIndex).toBe(3)
	end)

	it("supports non-cubic sizes", function()
		local region = OctreeRegionUtils.create(10, 20, 30, 2, 4, 6)

		expect(region.lowerBounds[1]).toBe(9)
		expect(region.lowerBounds[2]).toBe(18)
		expect(region.lowerBounds[3]).toBe(27)
		expect(region.upperBounds[1]).toBe(11)
		expect(region.upperBounds[2]).toBe(22)
		expect(region.upperBounds[3]).toBe(33)
	end)
end)

describe("OctreeRegionUtils.getSearchRadiusSquared", function()
	it("returns epsilon for a zero radius and zero diameter", function()
		expect(OctreeRegionUtils.getSearchRadiusSquared(0, 0, 0)).toBe(0)
		expect(OctreeRegionUtils.getSearchRadiusSquared(0, 0, 1e-6)).toBeCloseTo(1e-6, 9)
	end)

	it("squares the radius when the diameter is zero", function()
		expect(OctreeRegionUtils.getSearchRadiusSquared(2, 0, 0)).toBe(4)
	end)

	it("expands the radius by the region diagonal", function()
		-- searchRadius = radius + sqrt(3)/2 * diameter
		expect(OctreeRegionUtils.getSearchRadiusSquared(1, 2, 0.5)).toBeCloseTo(7.9641016, 5)
	end)
end)

describe("OctreeRegionUtils.inRegionBounds", function()
	local region = OctreeRegionUtils.create(0, 0, 0, 512, 512, 512)

	it("returns true for a point in the middle", function()
		expect(OctreeRegionUtils.inRegionBounds(region, 0, 0, 0)).toBe(true)
		expect(OctreeRegionUtils.inRegionBounds(region, 100, -100, 50)).toBe(true)
	end)

	it("treats the lower and upper bounds as inclusive", function()
		expect(OctreeRegionUtils.inRegionBounds(region, -256, -256, -256)).toBe(true)
		expect(OctreeRegionUtils.inRegionBounds(region, 256, 256, 256)).toBe(true)
	end)

	it("returns false just outside any axis", function()
		expect(OctreeRegionUtils.inRegionBounds(region, 257, 0, 0)).toBe(false)
		expect(OctreeRegionUtils.inRegionBounds(region, 0, -257, 0)).toBe(false)
		expect(OctreeRegionUtils.inRegionBounds(region, 0, 0, 257)).toBe(false)
	end)
end)

describe("OctreeRegionUtils.getSubRegionIndex", function()
	local region = OctreeRegionUtils.create(0, 0, 0, 512, 512, 512)

	it("maps each octant to a distinct index in [1, 8]", function()
		expect(OctreeRegionUtils.getSubRegionIndex(region, 1, 1, -1)).toBe(1)
		expect(OctreeRegionUtils.getSubRegionIndex(region, -1, 1, -1)).toBe(2)
		expect(OctreeRegionUtils.getSubRegionIndex(region, 1, 1, 1)).toBe(3)
		expect(OctreeRegionUtils.getSubRegionIndex(region, -1, 1, 1)).toBe(4)
		expect(OctreeRegionUtils.getSubRegionIndex(region, 1, -1, -1)).toBe(5)
		expect(OctreeRegionUtils.getSubRegionIndex(region, -1, -1, -1)).toBe(6)
		expect(OctreeRegionUtils.getSubRegionIndex(region, 1, -1, 1)).toBe(7)
		expect(OctreeRegionUtils.getSubRegionIndex(region, -1, -1, 1)).toBe(8)
	end)

	it("classifies a point exactly on the center deterministically", function()
		-- px > position is false (-> 2), py <= position adds 4, pz >= position adds 2
		expect(OctreeRegionUtils.getSubRegionIndex(region, 0, 0, 0)).toBe(8)
	end)
end)

describe("OctreeRegionUtils.createSubRegion", function()
	it("offsets, halves, and deepens the parent for index 1", function()
		local parent = OctreeRegionUtils.create(0, 0, 0, 512, 512, 512)
		local sub = OctreeRegionUtils.createSubRegion(parent, 1)

		expect(sub.position[1]).toBe(128)
		expect(sub.position[2]).toBe(128)
		expect(sub.position[3]).toBe(-128)
		expect(sub.size[1]).toBe(256)
		expect(sub.depth).toBe(2)
		expect(sub.parent).toBe(parent)
		expect(sub.parentIndex).toBe(1)
	end)

	it("offsets in the opposite direction for index 8", function()
		local parent = OctreeRegionUtils.create(0, 0, 0, 512, 512, 512)
		local sub = OctreeRegionUtils.createSubRegion(parent, 8)

		expect(sub.position[1]).toBe(-128)
		expect(sub.position[2]).toBe(-128)
		expect(sub.position[3]).toBe(128)
	end)
end)

describe("OctreeRegionUtils.getTopLevelRegionCellIndex", function()
	it("rounds to the nearest cell", function()
		expect(select(1, OctreeRegionUtils.getTopLevelRegionCellIndex(MAX_REGION_SIZE, 0, 0, 0))).toBe(0)
		expect(select(1, OctreeRegionUtils.getTopLevelRegionCellIndex(MAX_REGION_SIZE, 255, 0, 0))).toBe(0)
	end)

	it("rounds up at the half-size boundary", function()
		expect(select(1, OctreeRegionUtils.getTopLevelRegionCellIndex(MAX_REGION_SIZE, 256, 0, 0))).toBe(1)
	end)

	it("handles negative coordinates", function()
		local cx, cy, cz = OctreeRegionUtils.getTopLevelRegionCellIndex(MAX_REGION_SIZE, -300, -256, -257)
		expect(cx).toBe(-1)
		expect(cy).toBe(0)
		expect(cz).toBe(-1)
	end)
end)

describe("OctreeRegionUtils.getTopLevelRegionPosition", function()
	it("scales the cell index by the region size", function()
		local px, py, pz = OctreeRegionUtils.getTopLevelRegionPosition(MAX_REGION_SIZE, 1, -1, 2)
		expect(px).toBe(512)
		expect(py).toBe(-512)
		expect(pz).toBe(1024)
	end)
end)

describe("OctreeRegionUtils.getTopLevelRegionHash", function()
	it("is deterministic and returns zero at the origin", function()
		expect(OctreeRegionUtils.getTopLevelRegionHash(0, 0, 0)).toBe(0)
		expect(OctreeRegionUtils.getTopLevelRegionHash(1, 0, 0)).toBe(73856093)
		expect(OctreeRegionUtils.getTopLevelRegionHash(2, 3, 4)).toBe(OctreeRegionUtils.getTopLevelRegionHash(2, 3, 4))
	end)
end)

describe("OctreeRegionUtils.areEqualTopRegions", function()
	local region = OctreeRegionUtils.create(512, -512, 0, 512, 512, 512)

	it("returns true only when all axes match the region position", function()
		expect(OctreeRegionUtils.areEqualTopRegions(region, 512, -512, 0)).toBe(true)
		expect(OctreeRegionUtils.areEqualTopRegions(region, 512, -512, 1)).toBe(false)
		expect(OctreeRegionUtils.areEqualTopRegions(region, 0, -512, 0)).toBe(false)
	end)
end)

describe("OctreeRegionUtils.getOrCreateRegion / findRegion", function()
	it("creates a region on first request and reuses it afterwards", function()
		local hashMap = {}
		local first = OctreeRegionUtils.getOrCreateRegion(hashMap, MAX_REGION_SIZE, 10, 20, 30)
		local second = OctreeRegionUtils.getOrCreateRegion(hashMap, MAX_REGION_SIZE, 10, 20, 30)

		expect(first).toBe(second)
	end)

	it("creates distinct regions for distinct cells", function()
		local hashMap = {}
		local a = OctreeRegionUtils.getOrCreateRegion(hashMap, MAX_REGION_SIZE, 0, 0, 0)
		local b = OctreeRegionUtils.getOrCreateRegion(hashMap, MAX_REGION_SIZE, 1000, 0, 0)

		expect(a).never.toBe(b)
	end)

	it("findRegion returns nil before creation and the region after", function()
		local hashMap = {}
		expect(OctreeRegionUtils.findRegion(hashMap, MAX_REGION_SIZE, 0, 0, 0)).toBeNil()

		local created = OctreeRegionUtils.getOrCreateRegion(hashMap, MAX_REGION_SIZE, 0, 0, 0)
		expect(OctreeRegionUtils.findRegion(hashMap, MAX_REGION_SIZE, 0, 0, 0)).toBe(created)
	end)

	it("findRegion returns nil for a cell in a populated but non-matching hash bucket", function()
		local hashMap = {}
		OctreeRegionUtils.getOrCreateRegion(hashMap, MAX_REGION_SIZE, 0, 0, 0)
		-- A far-away cell that has never been created
		expect(OctreeRegionUtils.findRegion(hashMap, MAX_REGION_SIZE, 100000, 0, 0)).toBeNil()
	end)
end)

describe("OctreeRegionUtils.getOrCreateSubRegionAtDepth", function()
	it("descends to create a subregion at the requested max depth", function()
		local top = OctreeRegionUtils.create(0, 0, 0, 512, 512, 512)
		local lowest = OctreeRegionUtils.getOrCreateSubRegionAtDepth(top, 10, 10, 10, 4)

		expect(lowest.depth).toBe(5)
	end)

	it("reuses subregions for points sharing a lowest region", function()
		local top = OctreeRegionUtils.create(0, 0, 0, 512, 512, 512)
		local a = OctreeRegionUtils.getOrCreateSubRegionAtDepth(top, 10, 10, 10, 4)
		local b = OctreeRegionUtils.getOrCreateSubRegionAtDepth(top, 10, 10, 10, 4)

		expect(a).toBe(b)
	end)

	it("creates different lowest regions for opposite octants", function()
		local top = OctreeRegionUtils.create(0, 0, 0, 512, 512, 512)
		local a = OctreeRegionUtils.getOrCreateSubRegionAtDepth(top, 100, 100, 100, 4)
		local b = OctreeRegionUtils.getOrCreateSubRegionAtDepth(top, -100, -100, -100, 4)

		expect(a).never.toBe(b)
	end)
end)

describe("OctreeRegionUtils.addNode", function()
	it("adds the node to the lowest region and every ancestor", function()
		local top = OctreeRegionUtils.create(0, 0, 0, 512, 512, 512)
		local lowest = OctreeRegionUtils.getOrCreateSubRegionAtDepth(top, 10, 10, 10, 4)
		local node = fakeNode(10, 10, 10, "A")

		OctreeRegionUtils.addNode(lowest, node)

		expect(lowest.nodes[node]).toBe(node)
		expect(lowest.node_count).toBe(1)
		expect(top.nodes[node]).toBe(node)
		expect(top.node_count).toBe(1)
	end)

	it("is idempotent for a node that is already present", function()
		local top = OctreeRegionUtils.create(0, 0, 0, 512, 512, 512)
		local lowest = OctreeRegionUtils.getOrCreateSubRegionAtDepth(top, 10, 10, 10, 4)
		local node = fakeNode(10, 10, 10, "A")

		OctreeRegionUtils.addNode(lowest, node)
		OctreeRegionUtils.addNode(lowest, node)

		expect(lowest.node_count).toBe(1)
		expect(top.node_count).toBe(1)
	end)
end)

describe("OctreeRegionUtils.removeNode", function()
	it("removes the node from every ancestor and prunes empty subregions", function()
		local top = OctreeRegionUtils.create(0, 0, 0, 512, 512, 512)
		local lowest = OctreeRegionUtils.getOrCreateSubRegionAtDepth(top, 10, 10, 10, 4)
		local node = fakeNode(10, 10, 10, "A")

		OctreeRegionUtils.addNode(lowest, node)
		OctreeRegionUtils.removeNode(lowest, node)

		expect(lowest.nodes[node]).toBeNil()
		expect(lowest.node_count).toBe(0)
		expect(top.node_count).toBe(0)
		-- The now-empty lowest region should be detached from its parent
		expect(lowest.parent.subRegions[lowest.parentIndex]).toBeNil()
	end)

	it("keeps shared ancestors alive when a sibling still holds a node", function()
		local top = OctreeRegionUtils.create(0, 0, 0, 512, 512, 512)
		local a = OctreeRegionUtils.getOrCreateSubRegionAtDepth(top, 100, 100, 100, 4)
		local b = OctreeRegionUtils.getOrCreateSubRegionAtDepth(top, -100, -100, -100, 4)
		local nodeA = fakeNode(100, 100, 100, "A")
		local nodeB = fakeNode(-100, -100, -100, "B")

		OctreeRegionUtils.addNode(a, nodeA)
		OctreeRegionUtils.addNode(b, nodeB)
		expect(top.node_count).toBe(2)

		OctreeRegionUtils.removeNode(a, nodeA)

		expect(top.node_count).toBe(1)
		expect(top.nodes[nodeB]).toBe(nodeB)
	end)
end)

describe("OctreeRegionUtils.moveNode", function()
	it("asserts the source and destination differ", function()
		local top = OctreeRegionUtils.create(0, 0, 0, 512, 512, 512)
		local lowest = OctreeRegionUtils.getOrCreateSubRegionAtDepth(top, 10, 10, 10, 4)
		local node = fakeNode(10, 10, 10, "A")
		OctreeRegionUtils.addNode(lowest, node)

		expect(function()
			OctreeRegionUtils.moveNode(lowest, lowest, node)
		end).toThrow()
	end)

	it("moves a node between sibling lowest regions", function()
		local top = OctreeRegionUtils.create(0, 0, 0, 512, 512, 512)
		local from = OctreeRegionUtils.getOrCreateSubRegionAtDepth(top, 100, 100, 100, 4)
		local to = OctreeRegionUtils.getOrCreateSubRegionAtDepth(top, -100, -100, -100, 4)
		local node = fakeNode(100, 100, 100, "A")

		OctreeRegionUtils.addNode(from, node)
		OctreeRegionUtils.moveNode(from, to, node)

		expect(from.nodes[node]).toBeNil()
		expect(to.nodes[node]).toBe(node)
		-- The common ancestor still contains the node exactly once
		expect(top.nodes[node]).toBe(node)
		expect(top.node_count).toBe(1)
	end)
end)

describe("OctreeRegionUtils.getNeighborsWithinRadius", function()
	it("collects objects for nodes within the radius and skips those outside", function()
		local top = OctreeRegionUtils.create(0, 0, 0, 512, 512, 512)

		local nearRegion = OctreeRegionUtils.getOrCreateSubRegionAtDepth(top, 0, 0, 5, 4)
		local near = fakeNode(0, 0, 5, "near")
		OctreeRegionUtils.addNode(nearRegion, near)

		local farRegion = OctreeRegionUtils.getOrCreateSubRegionAtDepth(top, 0, 0, 200, 4)
		local far = fakeNode(0, 0, 200, "far")
		OctreeRegionUtils.addNode(farRegion, far)

		local objectsFound = {}
		local nodeDistances2 = {}
		OctreeRegionUtils.getNeighborsWithinRadius(top, 10, 0, 0, 0, objectsFound, nodeDistances2, 4)

		expect(#objectsFound).toBe(1)
		expect(objectsFound[1]).toBe("near")
		expect(nodeDistances2[1]).toBeCloseTo(25, 6)
	end)
end)
