--!strict
--[[
	@class BoundAncestorTracker.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local BinderTestUtils = require("BinderTestUtils")
local BoundAncestorTracker = require("BoundAncestorTracker")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("BoundAncestorTracker.new()", function()
	it("throws without a binder or child", function()
		expect(function()
			BoundAncestorTracker.new(nil :: any, Instance.new("Folder"))
		end).toThrow()
	end)
end)

describe("BoundAncestorTracker tracking", function()
	it("exposes the nearest bound ancestor's class", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local child = controller.newInstance(parent)
		local class = controller.bind(binder, grandparent)

		local tracker = BoundAncestorTracker.new(binder, child)
		expect(tracker.Class.Value).toEqual(class)

		tracker:Destroy()
		controller:Destroy()
	end)

	it("counts the child's direct parent as an ancestor", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local parent = controller.newInstance()
		local child = controller.newInstance(parent)
		local class = controller.bind(binder, parent)

		local tracker = BoundAncestorTracker.new(binder, child)
		expect(tracker.Class.Value).toEqual(class)

		tracker:Destroy()
		controller:Destroy()
	end)

	it("never counts the child itself", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local parent = controller.newInstance()
		local child = controller.newInstance(parent)

		local tracker = BoundAncestorTracker.new(binder, child)
		controller.bind(binder, child)

		expect(tracker.Class.Value).toBeNil()

		tracker:Destroy()
		controller:Destroy()
	end)

	it("has no value when no ancestor is bound", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local parent = controller.newInstance()
		local child = controller.newInstance(parent)

		local tracker = BoundAncestorTracker.new(binder, child)
		expect(tracker.Class.Value).toBeNil()

		tracker:Destroy()
		controller:Destroy()
	end)

	it("updates when an ancestor becomes bound", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local ancestor = controller.newInstance()
		local parent = controller.newInstance(ancestor)
		local child = controller.newInstance(parent)

		local tracker = BoundAncestorTracker.new(binder, child)
		expect(tracker.Class.Value).toBeNil()

		local class = controller.bind(binder, ancestor)
		expect(tracker.Class.Value).toEqual(class)

		tracker:Destroy()
		controller:Destroy()
	end)

	it("takes the closest bound ancestor when several are bound", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local greatGrandparent = controller.newInstance()
		local grandparent = controller.newInstance(greatGrandparent)
		local parent = controller.newInstance(grandparent)
		local child = controller.newInstance(parent)
		controller.bind(binder, greatGrandparent)
		local grandparentClass = controller.bind(binder, grandparent)

		local tracker = BoundAncestorTracker.new(binder, child)
		expect(tracker.Class.Value).toEqual(grandparentClass)

		tracker:Destroy()
		controller:Destroy()
	end)

	it("switches to a closer ancestor that binds afterwards", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local greatGrandparent = controller.newInstance()
		local grandparent = controller.newInstance(greatGrandparent)
		local parent = controller.newInstance(grandparent)
		local child = controller.newInstance(parent)
		local outerClass = controller.bind(binder, greatGrandparent)

		local tracker = BoundAncestorTracker.new(binder, child)
		expect(tracker.Class.Value).toEqual(outerClass)

		local grandparentClass = controller.bind(binder, grandparent)
		expect(tracker.Class.Value).toEqual(grandparentClass)

		binder:Untag(grandparent)
		expect(binder:Get(grandparent)).toBeNil()

		expect(tracker.Class.Value).toEqual(outerClass)

		tracker:Destroy()
		controller:Destroy()
	end)

	it("clears the value when the child leaves the bound ancestry", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local ancestor = controller.newInstance()
		local parent = controller.newInstance(ancestor)
		local child = controller.newInstance(parent)
		local class = controller.bind(binder, ancestor)

		local tracker = BoundAncestorTracker.new(binder, child)
		expect(tracker.Class.Value).toEqual(class)

		child.Parent = controller.container
		expect(tracker.Class.Value).toBeNil()

		tracker:Destroy()
		controller:Destroy()
	end)

	it("ignores an unrelated instance binding", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local child = controller.newInstance(parent)
		local unrelated = controller.newInstance()

		local tracker = BoundAncestorTracker.new(binder, child)
		expect(tracker.Class.Value).toBeNil()

		controller.bind(binder, unrelated)
		expect(tracker.Class.Value).toBeNil()

		tracker:Destroy()
		controller:Destroy()
	end)
end)
