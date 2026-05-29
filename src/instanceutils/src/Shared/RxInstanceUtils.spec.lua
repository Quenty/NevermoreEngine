--!nonstrict
--[[
	@class RxInstanceUtils.spec.lua
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local Brio = require("Brio")
local Jest = require("Jest")
local RxInstanceUtils = require("RxInstanceUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("RxInstanceUtils.observeChildrenBrio", function()
	local part = Instance.new("Part")
	local observe = RxInstanceUtils.observeChildrenBrio(part)
	local externalResult = nil

	it("should not emit anything", function()
		observe:Subscribe(function(result)
			externalResult = result
		end)

		expect(externalResult).toEqual(nil)
	end)
end)

describe("RxInstanceUtils.observeLastNamedChildBrio", function()
	describe("with no children", function()
		it("should not emit anything", function()
			local parent = Instance.new("Folder")
			local lastBrio = nil
			local fireCount = 0

			local sub = RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"):Subscribe(function(brio)
				lastBrio = brio
				fireCount = fireCount + 1
			end)

			expect(fireCount).toEqual(0)
			expect(lastBrio).toBeNil()

			sub:Destroy()
		end)
	end)

	describe("with a matching child already present", function()
		it("should emit a brio with the child", function()
			local parent = Instance.new("Folder")
			local child = Instance.new("Part")
			child.Name = "Target"
			child.Parent = parent

			local lastBrio = nil
			local fireCount = 0

			local sub = RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"):Subscribe(function(brio)
				lastBrio = brio
				fireCount = fireCount + 1
			end)

			expect(fireCount).toEqual(1)
			expect(lastBrio).never.toBeNil()
			expect(Brio.isBrio(lastBrio)).toEqual(true)
			expect(lastBrio:IsDead()).toEqual(false)
			expect(lastBrio:GetValue()).toEqual(child)

			sub:Destroy()
		end)
	end)

	describe("with wrong className", function()
		it("should not emit for a child with the wrong class", function()
			local parent = Instance.new("Folder")
			local child = Instance.new("Folder")
			child.Name = "Target"
			child.Parent = parent

			local fireCount = 0

			local sub = RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"):Subscribe(function()
				fireCount = fireCount + 1
			end)

			expect(fireCount).toEqual(0)

			sub:Destroy()
		end)
	end)

	describe("with wrong name", function()
		it("should not emit for a child with the wrong name", function()
			local parent = Instance.new("Folder")
			local child = Instance.new("Part")
			child.Name = "Wrong"
			child.Parent = parent

			local fireCount = 0

			local sub = RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"):Subscribe(function()
				fireCount = fireCount + 1
			end)

			expect(fireCount).toEqual(0)

			sub:Destroy()
		end)
	end)

	describe("when a child is added after subscription", function()
		it("should emit when a matching child is added", function()
			local parent = Instance.new("Folder")
			local lastBrio = nil
			local fireCount = 0

			local sub = RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"):Subscribe(function(brio)
				lastBrio = brio
				fireCount = fireCount + 1
			end)

			expect(fireCount).toEqual(0)

			local child = Instance.new("Part")
			child.Name = "Target"
			child.Parent = parent

			expect(fireCount).toEqual(1)
			expect(lastBrio).never.toBeNil()
			expect(Brio.isBrio(lastBrio)).toEqual(true)
			expect(lastBrio:GetValue()).toEqual(child)

			sub:Destroy()
		end)
	end)

	describe("when a matching child is removed", function()
		it("should kill the previous brio", function()
			local parent = Instance.new("Folder")
			local child = Instance.new("Part")
			child.Name = "Target"
			child.Parent = parent

			local lastBrio = nil
			local fireCount = 0

			local sub = RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"):Subscribe(function(brio)
				lastBrio = brio
				fireCount = fireCount + 1
			end)

			expect(fireCount).toEqual(1)
			local firstBrio = lastBrio

			child.Parent = nil

			expect(firstBrio:IsDead()).toEqual(true)

			sub:Destroy()
		end)
	end)

	describe("when child name changes to match", function()
		it("should emit when a child is renamed to the target name", function()
			local parent = Instance.new("Folder")
			local child = Instance.new("Part")
			child.Name = "Wrong"
			child.Parent = parent

			local lastBrio = nil
			local fireCount = 0

			local sub = RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"):Subscribe(function(brio)
				lastBrio = brio
				fireCount = fireCount + 1
			end)

			expect(fireCount).toEqual(0)

			child.Name = "Target"

			expect(fireCount).toEqual(1)
			expect(lastBrio).never.toBeNil()
			expect(lastBrio:GetValue()).toEqual(child)

			sub:Destroy()
		end)
	end)

	describe("when child name changes away from match", function()
		it("should kill the brio when a child is renamed away", function()
			local parent = Instance.new("Folder")
			local child = Instance.new("Part")
			child.Name = "Target"
			child.Parent = parent

			local lastBrio = nil
			local fireCount = 0

			local sub = RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"):Subscribe(function(brio)
				lastBrio = brio
				fireCount = fireCount + 1
			end)

			expect(fireCount).toEqual(1)
			local firstBrio = lastBrio

			child.Name = "NotTarget"

			expect(firstBrio:IsDead()).toEqual(true)

			sub:Destroy()
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

			local lastBrio = nil
			local fireCount = 0

			local sub = RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"):Subscribe(function(brio)
				lastBrio = brio
				fireCount = fireCount + 1
			end)

			-- Should have emitted (possibly more than once as children are iterated)
			expect(lastBrio).never.toBeNil()
			expect(Brio.isBrio(lastBrio)).toEqual(true)
			expect(lastBrio:IsDead()).toEqual(false)

			local value = lastBrio:GetValue()
			-- The emitted child should be one of the two matching children
			expect(value:IsA("Part")).toEqual(true)
			expect(value.Name).toEqual("Target")

			sub:Destroy()
		end)

		it("should switch to remaining child when the emitted one is removed", function()
			local parent = Instance.new("Folder")
			local child1 = Instance.new("Part")
			child1.Name = "Target"
			child1.Parent = parent
			local child2 = Instance.new("Part")
			child2.Name = "Target"
			child2.Parent = parent

			local lastBrio = nil

			local sub = RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"):Subscribe(function(brio)
				lastBrio = brio
			end)

			local emittedChild = lastBrio:GetValue()
			local otherChild = if emittedChild == child1 then child2 else child1

			-- Remove the currently emitted child
			emittedChild.Parent = nil

			-- Should now emit the other child
			expect(lastBrio).never.toBeNil()
			expect(lastBrio:IsDead()).toEqual(false)
			expect(lastBrio:GetValue()).toEqual(otherChild)

			sub:Destroy()
		end)

		it("should emit nothing when all matching children are removed", function()
			local parent = Instance.new("Folder")
			local child1 = Instance.new("Part")
			child1.Name = "Target"
			child1.Parent = parent
			local child2 = Instance.new("Part")
			child2.Name = "Target"
			child2.Parent = parent

			local lastBrio = nil

			local sub = RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"):Subscribe(function(brio)
				lastBrio = brio
			end)

			expect(lastBrio).never.toBeNil()

			child1.Parent = nil
			child2.Parent = nil

			-- The last brio should be dead since no matching children remain
			expect(lastBrio:IsDead()).toEqual(true)

			sub:Destroy()
		end)
	end)

	describe("subscription cleanup", function()
		it("should kill the brio when subscription is destroyed", function()
			local parent = Instance.new("Folder")
			local child = Instance.new("Part")
			child.Name = "Target"
			child.Parent = parent

			local lastBrio = nil

			local sub = RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"):Subscribe(function(brio)
				lastBrio = brio
			end)

			expect(lastBrio).never.toBeNil()
			expect(lastBrio:IsDead()).toEqual(false)

			sub:Destroy()

			expect(lastBrio:IsDead()).toEqual(true)
		end)
	end)

	describe("className inheritance", function()
		it("should match subclasses via IsA", function()
			local parent = Instance.new("Folder")
			local child = Instance.new("Part")
			child.Name = "Target"
			child.Parent = parent

			local lastBrio = nil
			local fireCount = 0

			-- Part IsA BasePart, so this should match
			local sub = RxInstanceUtils.observeLastNamedChildBrio(parent, "BasePart", "Target"):Subscribe(function(brio)
				lastBrio = brio
				fireCount = fireCount + 1
			end)

			expect(fireCount).toEqual(1)
			expect(lastBrio:GetValue()).toEqual(child)

			sub:Destroy()
		end)
	end)

	describe("non-matching child added then removed", function()
		it("should not emit for non-matching children", function()
			local parent = Instance.new("Folder")
			local fireCount = 0

			local sub = RxInstanceUtils.observeLastNamedChildBrio(parent, "Part", "Target"):Subscribe(function()
				fireCount = fireCount + 1
			end)

			local child = Instance.new("Folder")
			child.Name = "Target"
			child.Parent = parent
			child.Parent = nil

			expect(fireCount).toEqual(0)

			sub:Destroy()
		end)
	end)
end)
