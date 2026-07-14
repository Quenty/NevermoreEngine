--!nonstrict
--[[
	@class OctreeNode.spec.lua
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local Jest = require("Jest")
local Octree = require("Octree")
local OctreeNode = require("OctreeNode")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("OctreeNode.new", function()
	it("errors without an octree", function()
		expect(function()
			OctreeNode.new(nil, "A")
		end).toThrow()
	end)

	it("errors without an object", function()
		local octree = Octree.new()
		expect(function()
			OctreeNode.new(octree, nil)
		end).toThrow()
	end)

	it("starts with no position", function()
		local octree = Octree.new()
		local node = OctreeNode.new(octree, "A")

		expect(node:GetPosition()).toBeNil()

		local px, py, pz = node:GetRawPosition()
		expect(px).toBeNil()
		expect(py).toBeNil()
		expect(pz).toBeNil()
	end)
end)

describe("OctreeNode.GetObject", function()
	it("returns the stored object", function()
		local octree = Octree.new()
		local node = octree:CreateNode(Vector3.zero, "A")
		expect(node:GetObject()).toBe("A")
	end)
end)

describe("OctreeNode.GetPosition / GetRawPosition", function()
	it("reports the position set through the octree", function()
		local octree = Octree.new()
		local node = octree:CreateNode(Vector3.new(10, 20, 30), "A")

		expect(node:GetPosition()).toEqual(Vector3.new(10, 20, 30))

		local px, py, pz = node:GetRawPosition()
		expect(px).toBe(10)
		expect(py).toBe(20)
		expect(pz).toBe(30)
	end)
end)

describe("OctreeNode.SetPosition", function()
	it("is a no-op when set to the same position", function()
		local octree = Octree.new()
		local node = octree:CreateNode(Vector3.new(1, 2, 3), "A")

		node:SetPosition(Vector3.new(1, 2, 3))

		expect(node:GetPosition()).toEqual(Vector3.new(1, 2, 3))
		expect(#octree:RadiusSearch(Vector3.new(1, 2, 3), 1)).toBe(1)
	end)

	it("moves the node between regions", function()
		local octree = Octree.new()
		local node = octree:CreateNode(Vector3.zero, "A")
		expect(#octree:RadiusSearch(Vector3.zero, 10)).toBe(1)

		node:SetPosition(Vector3.new(1000, 0, 0))

		expect(#octree:RadiusSearch(Vector3.zero, 10)).toBe(0)
		expect(#octree:RadiusSearch(Vector3.new(1000, 0, 0), 10)).toBe(1)
	end)

	it("moves the node within the same region without duplicating it", function()
		local octree = Octree.new()
		local node = octree:CreateNode(Vector3.new(1, 1, 1), "A")

		node:SetPosition(Vector3.new(2, 2, 2))

		expect(#octree:GetAllNodes()).toBe(1)
		expect(#octree:RadiusSearch(Vector3.new(2, 2, 2), 1)).toBe(1)
		expect(#octree:RadiusSearch(Vector3.new(1, 1, 1), 0.1)).toBe(0)
	end)
end)

describe("OctreeNode.RadiusSearch", function()
	it("searches relative to the node's own position and includes itself", function()
		local octree = Octree.new()
		local node = octree:CreateNode(Vector3.zero, "A")
		octree:CreateNode(Vector3.new(0, 0, 5), "B")

		local objects = node:RadiusSearch(10)
		local set = {}
		for _, object in objects do
			set[object] = true
		end
		expect(set.A).toBe(true)
		expect(set.B).toBe(true)
	end)
end)

describe("OctreeNode.KNearestNeighborsSearch", function()
	it("includes itself at distance zero and orders by distance", function()
		local octree = Octree.new()
		local node = octree:CreateNode(Vector3.zero, "A")
		octree:CreateNode(Vector3.new(0, 0, 5), "B")

		local objects, distances = node:KNearestNeighborsSearch(2, 100)
		expect(objects[1]).toBe("A")
		expect(objects[2]).toBe("B")
		expect(distances[1]).toBeCloseTo(0, 6)
		expect(distances[2]).toBeCloseTo(25, 6)
	end)
end)

describe("OctreeNode.Destroy", function()
	it("removes the node from the octree", function()
		local octree = Octree.new()
		local node = octree:CreateNode(Vector3.zero, "A")

		node:Destroy()

		expect(#octree:GetAllNodes()).toBe(0)
		expect(#octree:RadiusSearch(Vector3.zero, 10)).toBe(0)
	end)

	it("does not error for a node that was never positioned", function()
		local octree = Octree.new()
		local node = OctreeNode.new(octree, "A")

		expect(function()
			node:Destroy()
		end).never.toThrow()
	end)
end)
