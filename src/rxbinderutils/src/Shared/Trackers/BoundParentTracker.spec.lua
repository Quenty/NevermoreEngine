--!strict
--[[
	@class BoundParentTracker.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local BinderTestUtils = require("BinderTestUtils")
local BoundParentTracker = require("BoundParentTracker")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local setup = BinderTestUtils.setup
local makeTrackingClass = BinderTestUtils.makeTrackingClass

local function bind(binder, inst: Instance): any
	binder:Tag(inst)
	local ok, class = binder:Promise(inst):Yield()
	assert(ok, "Never bound")
	return class
end

describe("BoundParentTracker.new()", function()
	it("throws without a binder or child", function()
		expect(function()
			BoundParentTracker.new(nil :: any, Instance.new("Folder"))
		end).toThrow()
	end)
end)

describe("BoundParentTracker tracking", function()
	it("exposes the bound class of the direct parent", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local parent = controller.newInstance()
		local child = controller.newInstance(parent)
		local class = bind(binder, parent)

		local tracker = BoundParentTracker.new(binder, child)
		expect(tracker.Class.Value).toEqual(class)

		tracker:Destroy()
		controller:Destroy()
	end)

	it("has no value when the parent is unbound", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local parent = controller.newInstance()
		local child = controller.newInstance(parent)

		local tracker = BoundParentTracker.new(binder, child)
		expect(tracker.Class.Value).toBeNil()

		tracker:Destroy()
		controller:Destroy()
	end)

	it("picks up the parent binding after the tracker is constructed", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local parent = controller.newInstance()
		local child = controller.newInstance(parent)

		local tracker = BoundParentTracker.new(binder, child)
		expect(tracker.Class.Value).toBeNil()

		local class = bind(binder, parent)
		expect(tracker.Class.Value).toEqual(class)

		tracker:Destroy()
		controller:Destroy()
	end)

	it("ignores a bound grandparent", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local child = controller.newInstance(parent)
		bind(binder, grandparent)

		local tracker = BoundParentTracker.new(binder, child)
		expect(tracker.Class.Value).toBeNil()

		tracker:Destroy()
		controller:Destroy()
	end)

	it("clears the value when the child is reparented off the bound parent", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local parent = controller.newInstance()
		local child = controller.newInstance(parent)
		local class = bind(binder, parent)

		local tracker = BoundParentTracker.new(binder, child)
		expect(tracker.Class.Value).toEqual(class)

		child.Parent = controller.container
		expect(tracker.Class.Value).toBeNil()

		tracker:Destroy()
		controller:Destroy()
	end)

	it("clears the value when the parent's class is unbound", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local parent = controller.newInstance()
		local child = controller.newInstance(parent)
		local class = bind(binder, parent)

		local tracker = BoundParentTracker.new(binder, child)
		expect(tracker.Class.Value).toEqual(class)

		binder:Untag(parent)
		BinderTestUtils.awaitUnbound(binder, parent)

		expect(tracker.Class.Value).toBeNil()

		tracker:Destroy()
		controller:Destroy()
	end)

	it("keeps tracking after the child is left without a parent", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local first = controller.newInstance()
		local second = controller.newInstance()
		local child = controller.newInstance(first)
		local firstClass = bind(binder, first)
		local secondClass = bind(binder, second)

		local tracker = BoundParentTracker.new(binder, child)
		expect(tracker.Class.Value).toEqual(firstClass)

		child.Parent = nil
		expect(tracker.Class.Value).toBeNil()

		child.Parent = second
		expect(tracker.Class.Value).toEqual(secondClass)

		tracker:Destroy()
		controller:Destroy()
	end)

	it("tracks the new parent's class after the child is reparented", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local first = controller.newInstance()
		local second = controller.newInstance()
		local child = controller.newInstance(first)
		local firstClass = bind(binder, first)
		local secondClass = bind(binder, second)

		local tracker = BoundParentTracker.new(binder, child)
		expect(tracker.Class.Value).toEqual(firstClass)

		child.Parent = second
		expect(tracker.Class.Value).toEqual(secondClass)

		tracker:Destroy()
		controller:Destroy()
	end)

	it("stops following a parent the child no longer has", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local first = controller.newInstance()
		local second = controller.newInstance()
		local child = controller.newInstance(first)
		local firstClass = bind(binder, first)

		local tracker = BoundParentTracker.new(binder, child)
		expect(tracker.Class.Value).toEqual(firstClass)

		child.Parent = second
		expect(tracker.Class.Value).toBeNil()

		binder:Untag(first)
		BinderTestUtils.awaitUnbound(binder, first)

		expect(tracker.Class.Value).toBeNil()

		tracker:Destroy()
		controller:Destroy()
	end)
end)
