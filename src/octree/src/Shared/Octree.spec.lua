--!nonstrict
--[[
	@class Octree.spec.lua
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local Jest = require("Jest")
local Octree = require("Octree")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Collects the stored objects out of a { OctreeNode } list for order-independent asserts
local function objectSet(nodes)
	local set = {}
	for _, node in nodes do
		set[node:GetObject()] = true
	end
	return set
end

describe("Octree.new", function()
	it("constructs an empty octree", function()
		local octree = Octree.new()

		expect(octree.ClassName).toBe("Octree")
		expect(#octree:GetAllNodes()).toBe(0)
	end)

	it("returns no results when searching an empty octree", function()
		local octree = Octree.new()

		local objects, distances = octree:RadiusSearch(Vector3.zero, 100)
		expect(#objects).toBe(0)
		expect(#distances).toBe(0)
	end)
end)

describe("Octree.CreateNode", function()
	it("stores a node retrievable via search", function()
		local octree = Octree.new()
		octree:CreateNode(Vector3.zero, "A")

		local objects = octree:RadiusSearch(Vector3.zero, 10)
		expect(#objects).toBe(1)
		expect(objects[1]).toBe("A")
	end)

	it("supports multiple nodes at the same position", function()
		local octree = Octree.new()
		octree:CreateNode(Vector3.zero, "A")
		octree:CreateNode(Vector3.zero, "B")

		local objects = octree:RadiusSearch(Vector3.zero, 10)
		expect(#objects).toBe(2)

		local set = {}
		for _, object in objects do
			set[object] = true
		end
		expect(set.A).toBe(true)
		expect(set.B).toBe(true)
	end)

	it("supports arbitrary object types including tables and instances", function()
		local octree = Octree.new()
		local tableObject = {}
		local instanceObject = Instance.new("Folder")

		octree:CreateNode(Vector3.zero, tableObject)
		octree:CreateNode(Vector3.zero, instanceObject)

		local set = objectSet(octree:GetAllNodes())
		expect(set[tableObject]).toBe(true)
		expect(set[instanceObject]).toBe(true)

		instanceObject:Destroy()
	end)

	it("rejects a non-Vector3 position", function()
		local octree = Octree.new()
		expect(function()
			octree:CreateNode(5 :: any, "A")
		end).toThrow()
	end)

	it("rejects a nil object", function()
		local octree = Octree.new()
		expect(function()
			octree:CreateNode(Vector3.zero, nil :: any)
		end).toThrow()
	end)
end)

describe("Octree.GetAllNodes", function()
	it("returns every created node regardless of region", function()
		local octree = Octree.new()
		octree:CreateNode(Vector3.zero, "A")
		octree:CreateNode(Vector3.new(1000, 0, 0), "B")
		octree:CreateNode(Vector3.new(0, -2000, 0), "C")

		local set = objectSet(octree:GetAllNodes())
		expect(set.A).toBe(true)
		expect(set.B).toBe(true)
		expect(set.C).toBe(true)
		expect(#octree:GetAllNodes()).toBe(3)
	end)

	it("stops returning a node after it is destroyed", function()
		local octree = Octree.new()
		local node = octree:CreateNode(Vector3.zero, "A")
		expect(#octree:GetAllNodes()).toBe(1)

		node:Destroy()
		expect(#octree:GetAllNodes()).toBe(0)
	end)
end)

describe("Octree.RadiusSearch", function()
	it("includes nodes inside the radius and excludes those outside", function()
		local octree = Octree.new()
		octree:CreateNode(Vector3.zero, "A")
		octree:CreateNode(Vector3.new(0, 0, 5), "B")
		octree:CreateNode(Vector3.new(0, 0, 1000), "C")

		local objects = octree:RadiusSearch(Vector3.zero, 100)
		local set = {}
		for _, object in objects do
			set[object] = true
		end
		expect(set.A).toBe(true)
		expect(set.B).toBe(true)
		expect(set.C).never.toBe(true)
	end)

	it("returns the squared distance for each object", function()
		local octree = Octree.new()
		octree:CreateNode(Vector3.new(0, 0, 5), "B")

		local objects, distances = octree:RadiusSearch(Vector3.zero, 100)
		expect(#objects).toBe(1)
		expect(distances[1]).toBeCloseTo(25, 6)
	end)

	it("excludes a node just outside the radius", function()
		local octree = Octree.new()
		octree:CreateNode(Vector3.new(0, 0, 5), "B")

		-- Node is exactly 5 studs away; a radius of 4 must not include it
		local objects = octree:RadiusSearch(Vector3.zero, 4)
		expect(#objects).toBe(0)
	end)

	it("finds a node at its exact position with radius zero", function()
		local octree = Octree.new()
		octree:CreateNode(Vector3.new(10, 20, 30), "A")

		local objects, distances = octree:RadiusSearch(Vector3.new(10, 20, 30), 0)
		expect(#objects).toBe(1)
		expect(distances[1]).toBeCloseTo(0, 6)
	end)

	it("works across negative coordinates and separate top-level regions", function()
		local octree = Octree.new()
		octree:CreateNode(Vector3.new(-1000, -1000, -1000), "neg")

		local objects = octree:RadiusSearch(Vector3.new(-1000, -1000, -1000), 10)
		expect(#objects).toBe(1)
		expect(objects[1]).toBe("neg")
	end)

	it("rejects a non-Vector3 position", function()
		local octree = Octree.new()
		expect(function()
			octree:RadiusSearch(5 :: any, 10)
		end).toThrow()
	end)

	it("rejects a non-number radius", function()
		local octree = Octree.new()
		expect(function()
			octree:RadiusSearch(Vector3.zero, "big" :: any)
		end).toThrow()
	end)
end)

describe("Octree.KNearestNeighborsSearch", function()
	it("returns the k closest objects ordered by distance", function()
		local octree = Octree.new()
		octree:CreateNode(Vector3.zero, "A")
		octree:CreateNode(Vector3.new(0, 0, 5), "B")
		octree:CreateNode(Vector3.new(0, 0, 10), "C")

		local objects, distances = octree:KNearestNeighborsSearch(Vector3.zero, 2, 100)
		expect(#objects).toBe(2)
		expect(objects[1]).toBe("A")
		expect(objects[2]).toBe("B")
		expect(distances[1]).toBeCloseTo(0, 6)
		expect(distances[2]).toBeCloseTo(25, 6)
	end)

	it("returns everything in range when k exceeds the node count", function()
		local octree = Octree.new()
		octree:CreateNode(Vector3.zero, "A")
		octree:CreateNode(Vector3.new(0, 0, 5), "B")

		local objects = octree:KNearestNeighborsSearch(Vector3.zero, 10, 100)
		expect(#objects).toBe(2)
	end)

	it("returns nothing when k is zero", function()
		local octree = Octree.new()
		octree:CreateNode(Vector3.zero, "A")

		local objects, distances = octree:KNearestNeighborsSearch(Vector3.zero, 0, 100)
		expect(#objects).toBe(0)
		expect(#distances).toBe(0)
	end)

	it("respects the radius bound", function()
		local octree = Octree.new()
		octree:CreateNode(Vector3.zero, "A")
		octree:CreateNode(Vector3.new(0, 0, 50), "far")

		local objects = octree:KNearestNeighborsSearch(Vector3.zero, 5, 10)
		expect(#objects).toBe(1)
		expect(objects[1]).toBe("A")
	end)
end)
