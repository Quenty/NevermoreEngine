--!strict
--[[
	@class RxInstanceUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Jest = require("Jest")
local ObservableSpy = require("ObservableSpy")
local RxInstanceUtils = require("RxInstanceUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("RxInstanceUtils.observeChildrenBrio", function()
	it("should not emit anything", function()
		local part = Instance.new("Part")

		local brios = ObservableSpy.new(RxInstanceUtils.observeChildrenBrio(part))

		expect(#brios).toEqual(0)

		brios:Destroy()
		part:Destroy()
	end)
end)

describe("RxInstanceUtils.observeLastNamedChildBrio", function()
	describe("with no children", function()
		it("should not emit anything", function()
			local parent = Instance.new("Folder")

			local brios = ObservableSpy.new(RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"))

			expect(#brios).toEqual(0)
			expect(brios:GetLastValue()).toBeNil()

			brios:Destroy()
		end)
	end)

	describe("with a matching child already present", function()
		it("should emit a brio with the child", function()
			local parent = Instance.new("Folder")
			local child = Instance.new("Part")
			child.Name = "Target"
			child.Parent = parent

			local brios = ObservableSpy.new(RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"))

			expect(#brios).toEqual(1)
			expect(brios[1]).never.toBeNil()
			expect(Brio.isBrio(brios[1])).toEqual(true)
			expect(brios[1]:IsDead()).toEqual(false)
			expect(brios[1]:GetValue()).toEqual(child)

			brios:Destroy()
		end)
	end)

	describe("with wrong className", function()
		it("should not emit for a child with the wrong class", function()
			local parent = Instance.new("Folder")
			local child = Instance.new("Folder")
			child.Name = "Target"
			child.Parent = parent

			local brios = ObservableSpy.new(RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"))

			expect(#brios).toEqual(0)

			brios:Destroy()
		end)
	end)

	describe("with wrong name", function()
		it("should not emit for a child with the wrong name", function()
			local parent = Instance.new("Folder")
			local child = Instance.new("Part")
			child.Name = "Wrong"
			child.Parent = parent

			local brios = ObservableSpy.new(RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"))

			expect(#brios).toEqual(0)

			brios:Destroy()
		end)
	end)

	describe("when a child is added after subscription", function()
		it("should emit when a matching child is added", function()
			local parent = Instance.new("Folder")

			local brios = ObservableSpy.new(RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"))

			expect(#brios).toEqual(0)

			local child = Instance.new("Part")
			child.Name = "Target"
			child.Parent = parent

			expect(#brios).toEqual(1)
			expect(brios[1]).never.toBeNil()
			expect(Brio.isBrio(brios[1])).toEqual(true)
			expect(brios[1]:GetValue()).toEqual(child)

			brios:Destroy()
		end)
	end)

	describe("when a matching child is removed", function()
		it("should kill the previous brio", function()
			local parent = Instance.new("Folder")
			local child = Instance.new("Part")
			child.Name = "Target"
			child.Parent = parent

			local brios = ObservableSpy.new(RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"))

			expect(#brios).toEqual(1)
			local firstBrio = brios:GetLastValue()

			child.Parent = nil

			expect(firstBrio:IsDead()).toEqual(true)

			brios:Destroy()
		end)
	end)

	describe("when child name changes to match", function()
		it("should emit when a child is renamed to the target name", function()
			local parent = Instance.new("Folder")
			local child = Instance.new("Part")
			child.Name = "Wrong"
			child.Parent = parent

			local brios = ObservableSpy.new(RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"))

			expect(#brios).toEqual(0)

			child.Name = "Target"

			expect(#brios).toEqual(1)
			expect(brios[1]).never.toBeNil()
			expect(brios[1]:GetValue()).toEqual(child)

			brios:Destroy()
		end)
	end)

	describe("when child name changes away from match", function()
		it("should kill the brio when a child is renamed away", function()
			local parent = Instance.new("Folder")
			local child = Instance.new("Part")
			child.Name = "Target"
			child.Parent = parent

			local brios = ObservableSpy.new(RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"))

			expect(#brios).toEqual(1)
			local firstBrio = brios:GetLastValue()

			child.Name = "NotTarget"

			expect(firstBrio:IsDead()).toEqual(true)

			brios:Destroy()
		end)
	end)

	describe("with multiple matching children", function()
		it("should emit a brio with one of the children", function()
			local parent = Instance.new("Folder")
			local child1 = Instance.new("Part")
			child1.Name = "Target"
			child1.Parent = parent
			local child2 = Instance.new("Part")
			child2.Name = "Target"
			child2.Parent = parent

			local brios = ObservableSpy.new(RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"))

			-- Should have emitted (possibly more than once as children are iterated)
			local latestBrio = brios:GetLastValue()
			expect(latestBrio).never.toBeNil()
			expect(Brio.isBrio(latestBrio)).toEqual(true)
			expect(latestBrio:IsDead()).toEqual(false)

			local value = brios:GetLastValue():GetValue()
			-- The emitted child should be one of the two matching children
			expect(value:IsA("Part")).toEqual(true)
			expect(value.Name).toEqual("Target")

			brios:Destroy()
		end)

		it("should switch to remaining child when the emitted one is removed", function()
			local parent = Instance.new("Folder")
			local child1 = Instance.new("Part")
			child1.Name = "Target"
			child1.Parent = parent
			local child2 = Instance.new("Part")
			child2.Name = "Target"
			child2.Parent = parent

			local brios = ObservableSpy.new(RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"))

			local emittedChild = brios:GetLastValue():GetValue()
			local otherChild = if emittedChild == child1 then child2 else child1

			-- Remove the currently emitted child
			emittedChild.Parent = nil

			-- Should now emit the other child
			local brio = brios:GetLastValue()
			expect(brio).never.toBeNil()
			expect(brio:IsDead()).toEqual(false)
			expect(brio:GetValue()).toEqual(otherChild)

			brios:Destroy()
		end)

		it("should emit nothing when all matching children are removed", function()
			local parent = Instance.new("Folder")
			local child1 = Instance.new("Part")
			child1.Name = "Target"
			child1.Parent = parent
			local child2 = Instance.new("Part")
			child2.Name = "Target"
			child2.Parent = parent

			local brios = ObservableSpy.new(RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"))

			expect(brios:GetLastValue()).never.toBeNil()

			child1.Parent = nil
			child2.Parent = nil

			-- The last brio should be dead since no matching children remain
			expect(brios:GetLastValue():IsDead()).toEqual(true)

			brios:Destroy()
		end)
	end)

	describe("subscription cleanup", function()
		it("should kill the brio when subscription is destroyed", function()
			local parent = Instance.new("Folder")
			local child = Instance.new("Part")
			child.Name = "Target"
			child.Parent = parent

			local brios = ObservableSpy.new(RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"))

			expect(brios:GetLastValue()).never.toBeNil()
			expect(brios:GetLastValue():IsDead()).toEqual(false)

			brios:Destroy()

			expect(brios:GetLastValue():IsDead()).toEqual(true)
		end)
	end)

	describe("className inheritance", function()
		it("should match subclasses via IsA", function()
			local parent = Instance.new("Folder")
			local child = Instance.new("Part")
			child.Name = "Target"
			child.Parent = parent

			-- Part IsA BasePart, so this should match
			local brios = ObservableSpy.new(RxInstanceUtils.observeLastNamedChildBrio(parent, "BasePart", "Target"))

			expect(#brios).toEqual(1)
			expect(brios[1]:GetValue()).toEqual(child)

			brios:Destroy()
		end)
	end)

	describe("non-matching child added then removed", function()
		it("should not emit for non-matching children", function()
			local parent = Instance.new("Folder")

			local brios = ObservableSpy.new(RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"))

			local child = Instance.new("Folder")
			child.Name = "Target"
			child.Parent = parent
			child.Parent = nil

			expect(#brios).toEqual(0)

			brios:Destroy()
		end)
	end)
end)
