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

local setup = BinderTestUtils.setup
local makeTrackingClass = BinderTestUtils.makeTrackingClass

local function bind(binder, inst: Instance): any
	binder:Tag(inst)
	local ok, class = binder:Promise(inst):Yield()
	assert(ok, "Never bound")
	return class
end

describe("BoundAncestorTracker.new()", function()
	it("throws without a binder or child", function()
		expect(function()
			BoundAncestorTracker.new(nil :: any, Instance.new("Folder"))
		end).toThrow()
	end)
end)

describe("BoundAncestorTracker tracking", function()
	it("exposes the nearest bound ancestor's class", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local child = controller.newInstance(parent)
		local class = bind(binder, grandparent)

		local tracker = BoundAncestorTracker.new(binder, child)
		expect(tracker.Class.Value).toEqual(class)

		tracker:Destroy()
		controller:Destroy()
	end)

	it("counts the child's direct parent as an ancestor", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local parent = controller.newInstance()
		local child = controller.newInstance(parent)
		local class = bind(binder, parent)

		local tracker = BoundAncestorTracker.new(binder, child)
		expect(tracker.Class.Value).toEqual(class)

		tracker:Destroy()
		controller:Destroy()
	end)

	it("never counts the child itself", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local parent = controller.newInstance()
		local child = controller.newInstance(parent)

		local tracker = BoundAncestorTracker.new(binder, child)
		bind(binder, child)

		expect(tracker.Class.Value).toBeNil()

		tracker:Destroy()
		controller:Destroy()
	end)

	it("has no value when no ancestor is bound", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local parent = controller.newInstance()
		local child = controller.newInstance(parent)

		local tracker = BoundAncestorTracker.new(binder, child)
		expect(tracker.Class.Value).toBeNil()

		tracker:Destroy()
		controller:Destroy()
	end)

	it("updates when an ancestor becomes bound", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local ancestor = controller.newInstance()
		local parent = controller.newInstance(ancestor)
		local child = controller.newInstance(parent)

		local tracker = BoundAncestorTracker.new(binder, child)
		expect(tracker.Class.Value).toBeNil()

		local class = bind(binder, ancestor)
		expect(tracker.Class.Value).toEqual(class)

		tracker:Destroy()
		controller:Destroy()
	end)

	it("takes the closest bound ancestor when several are bound", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local greatGrandparent = controller.newInstance()
		local grandparent = controller.newInstance(greatGrandparent)
		local parent = controller.newInstance(grandparent)
		local child = controller.newInstance(parent)
		bind(binder, greatGrandparent)
		local grandparentClass = bind(binder, grandparent)

		local tracker = BoundAncestorTracker.new(binder, child)
		expect(tracker.Class.Value).toEqual(grandparentClass)

		tracker:Destroy()
		controller:Destroy()
	end)

	it("switches to a closer ancestor that binds afterwards", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local greatGrandparent = controller.newInstance()
		local grandparent = controller.newInstance(greatGrandparent)
		local parent = controller.newInstance(grandparent)
		local child = controller.newInstance(parent)
		local outerClass = bind(binder, greatGrandparent)

		local tracker = BoundAncestorTracker.new(binder, child)
		expect(tracker.Class.Value).toEqual(outerClass)

		local grandparentClass = bind(binder, grandparent)
		expect(tracker.Class.Value).toEqual(grandparentClass)

		binder:Untag(grandparent)
		BinderTestUtils.awaitUnbound(binder, grandparent)

		expect(tracker.Class.Value).toEqual(outerClass)

		tracker:Destroy()
		controller:Destroy()
	end)

	it("clears the value when the child leaves the bound ancestry", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local ancestor = controller.newInstance()
		local parent = controller.newInstance(ancestor)
		local child = controller.newInstance(parent)
		local class = bind(binder, ancestor)

		local tracker = BoundAncestorTracker.new(binder, child)
		expect(tracker.Class.Value).toEqual(class)

		child.Parent = controller.container
		expect(tracker.Class.Value).toBeNil()

		tracker:Destroy()
		controller:Destroy()
	end)

	it("ignores an unrelated instance binding", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local child = controller.newInstance(parent)
		local unrelated = controller.newInstance()

		local tracker = BoundAncestorTracker.new(binder, child)
		expect(tracker.Class.Value).toBeNil()

		bind(binder, unrelated)
		expect(tracker.Class.Value).toBeNil()

		tracker:Destroy()
		controller:Destroy()
	end)
end)
