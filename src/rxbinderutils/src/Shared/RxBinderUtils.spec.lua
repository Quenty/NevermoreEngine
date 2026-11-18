--!strict
--[[
	@class RxBinderUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local BinderTestUtils = require("BinderTestUtils")
local Jest = require("Jest")
local ObservableSpy = require("ObservableSpy")
local RxBinderUtils = require("RxBinderUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup()
	local controller = BinderTestUtils.setup()

	controller.observeParent = function(binder, inst: Instance): ObservableSpy.ObservableSpy<any>
		return controller.maid:Add(ObservableSpy.new(RxBinderUtils.observeBoundParent(binder, inst)))
	end

	controller.observeAncestor = function(binder, inst: Instance): ObservableSpy.ObservableSpy<any>
		return controller.maid:Add(ObservableSpy.new(RxBinderUtils.observeBoundAncestor(binder, inst)))
	end

	return controller
end

describe("RxBinderUtils.observeBoundParent()", function()
	it("emits the already-bound parent on subscribe", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local parent = controller.newInstance()
		local inst = controller.newInstance(parent)
		local class = controller.bind(binder, parent)

		local emissions = controller.observeParent(binder, inst)

		expect(#emissions).toEqual(1)
		expect(emissions[1]).toEqual(class)

		controller:Destroy()
	end)

	it("emits nil when the parent is unbound", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local parent = controller.newInstance()
		local inst = controller.newInstance(parent)

		local emissions = controller.observeParent(binder, inst)

		expect(#emissions).toEqual(1)
		expect(emissions[1]).toEqual(nil)

		controller:Destroy()
	end)

	it("ignores a bound grandparent", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)
		controller.bind(binder, grandparent)

		local emissions = controller.observeParent(binder, inst)

		expect(#emissions).toEqual(1)
		expect(emissions[1]).toEqual(nil)

		controller:Destroy()
	end)

	it("emits when the parent binds afterwards", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local parent = controller.newInstance()
		local inst = controller.newInstance(parent)

		local emissions = controller.observeParent(binder, inst)

		local class = controller.bind(binder, parent)

		expect(#emissions).toEqual(2)
		expect(emissions[2]).toEqual(class)

		controller:Destroy()
	end)

	it("follows the new parent when the instance is reparented", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local first = controller.newInstance()
		local second = controller.newInstance()
		local inst = controller.newInstance(first)
		local firstClass = controller.bind(binder, first)
		local secondClass = controller.bind(binder, second)

		local emissions = controller.observeParent(binder, inst)
		expect(emissions[1]).toEqual(firstClass)

		inst.Parent = second

		expect(#emissions).toEqual(2)
		expect(emissions[2]).toEqual(secondClass)

		controller:Destroy()
	end)

	it("keeps tracking after the instance is left without a parent", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local first = controller.newInstance()
		local second = controller.newInstance()
		local inst = controller.newInstance(first)
		local firstClass = controller.bind(binder, first)
		local secondClass = controller.bind(binder, second)

		local emissions = controller.observeParent(binder, inst)
		expect(emissions[1]).toEqual(firstClass)

		inst.Parent = nil
		expect(emissions[#emissions]).toEqual(nil)

		inst.Parent = second
		expect(emissions[#emissions]).toEqual(secondClass)

		controller:Destroy()
	end)

	it("does not emit when an unrelated instance binds", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local parent = controller.newInstance()
		local inst = controller.newInstance(parent)
		local unrelated = controller.newInstance()

		local emissions = controller.observeParent(binder, inst)

		controller.bind(binder, unrelated)

		expect(#emissions).toEqual(1)

		controller:Destroy()
	end)
end)

describe("RxBinderUtils.observeBoundAncestor()", function()
	it("emits nil immediately when no ancestor is bound", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local inst = controller.newInstance()

		local emissions = controller.observeAncestor(binder, inst)

		expect(#emissions).toEqual(1)
		expect(emissions[1]).toEqual(nil)

		controller:Destroy()
	end)

	it("emits the already-bound direct parent on subscribe", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local parent = controller.newInstance()
		local inst = controller.newInstance(parent)
		local class = controller.bind(binder, parent)

		local emissions = controller.observeAncestor(binder, inst)

		expect(#emissions).toEqual(1)
		expect(emissions[1]).toEqual(class)

		controller:Destroy()
	end)

	it("emits a bound grandparent when the direct parent is unbound", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)
		local class = controller.bind(binder, grandparent)

		local emissions = controller.observeAncestor(binder, inst)

		expect(#emissions).toEqual(1)
		expect(emissions[1]).toEqual(class)

		controller:Destroy()
	end)

	it("never emits the instance's own bound class", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local inst = controller.newInstance()

		local emissions = controller.observeAncestor(binder, inst)

		controller.bind(binder, inst)

		expect(#emissions).toEqual(1)
		expect(emissions[1]).toEqual(nil)

		controller:Destroy()
	end)

	it("emits when an ancestor becomes bound after subscribing", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)

		local emissions = controller.observeAncestor(binder, inst)

		local class = controller.bind(binder, grandparent)

		expect(#emissions).toEqual(2)
		expect(emissions[2]).toEqual(class)

		controller:Destroy()
	end)

	it("switches to a nearer ancestor when one becomes bound", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)
		controller.bind(binder, grandparent)

		local emissions = controller.observeAncestor(binder, inst)

		local parentClass = controller.bind(binder, parent)

		expect(#emissions).toEqual(2)
		expect(emissions[2]).toEqual(parentClass)

		controller:Destroy()
	end)

	it("keeps tracking an ancestor that survives a rebuild of the watched chain", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)
		local grandparentClass = controller.bind(binder, grandparent)

		local emissions = controller.observeAncestor(binder, inst)

		local parentClass = controller.bind(binder, parent)
		expect(#emissions).toEqual(2)
		expect(emissions[2]).toEqual(parentClass)

		controller.unbind(binder, parent)

		expect(#emissions).toEqual(3)
		expect(emissions[3]).toEqual(grandparentClass)

		controller:Destroy()
	end)

	it("emits the closest bound ancestor when several ancestors are bound", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local greatGrandparent = controller.newInstance()
		local grandparent = controller.newInstance(greatGrandparent)
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)

		controller.bind(binder, greatGrandparent)
		controller.bind(binder, grandparent)
		local parentClass = controller.bind(binder, parent)

		local emissions = controller.observeAncestor(binder, inst)

		expect(#emissions).toEqual(1)
		expect(emissions[1]).toEqual(parentClass)

		controller:Destroy()
	end)

	it("keeps the closer ancestor when a farther one binds afterwards", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)
		local parentClass = controller.bind(binder, parent)

		local emissions = controller.observeAncestor(binder, inst)
		expect(emissions[1]).toEqual(parentClass)

		controller.bind(binder, grandparent)

		expect(#emissions).toEqual(1)

		controller:Destroy()
	end)

	it("walks past several unbound ancestors to the closest bound one", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local greatGrandparent = controller.newInstance()
		local grandparent = controller.newInstance(greatGrandparent)
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)
		local class = controller.bind(binder, greatGrandparent)

		local emissions = controller.observeAncestor(binder, inst)
		expect(emissions[1]).toEqual(class)

		local grandparentClass = controller.bind(binder, grandparent)

		expect(#emissions).toEqual(2)
		expect(emissions[2]).toEqual(grandparentClass)

		controller:Destroy()
	end)

	it("recovers to the next bound ancestor when the closest is destroyed", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)
		local grandparentClass = controller.bind(binder, grandparent)
		controller.bind(binder, parent)

		local emissions = controller.observeAncestor(binder, inst)
		expect(#emissions).toEqual(1)

		inst.Parent = grandparent
		parent:Destroy()

		expect(emissions[#emissions]).toEqual(grandparentClass)

		controller:Destroy()
	end)

	it("does not emit when an unrelated instance binds", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local inst = controller.newInstance()
		local unrelated = controller.newInstance()

		local emissions = controller.observeAncestor(binder, inst)

		controller.bind(binder, unrelated)

		expect(#emissions).toEqual(1)

		controller:Destroy()
	end)

	it("emits nil when the bound ancestor unbinds", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local parent = controller.newInstance()
		local inst = controller.newInstance(parent)
		controller.bind(binder, parent)

		local emissions = controller.observeAncestor(binder, inst)
		expect(#emissions).toEqual(1)

		controller.unbind(binder, parent)

		expect(#emissions).toEqual(2)
		expect(emissions[2]).toEqual(nil)

		controller:Destroy()
	end)

	it("falls back to the next bound ancestor when the nearest unbinds", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)
		local grandparentClass = controller.bind(binder, grandparent)
		controller.bind(binder, parent)

		local emissions = controller.observeAncestor(binder, inst)

		controller.unbind(binder, parent)

		expect(#emissions).toEqual(2)
		expect(emissions[2]).toEqual(grandparentClass)

		controller:Destroy()
	end)

	it("emits when the instance is reparented under a bound ancestor", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local parent = controller.newInstance()
		local inst = controller.newInstance()
		local class = controller.bind(binder, parent)

		local emissions = controller.observeAncestor(binder, inst)
		expect(emissions[1]).toEqual(nil)

		inst.Parent = parent

		expect(#emissions).toEqual(2)
		expect(emissions[2]).toEqual(class)

		controller:Destroy()
	end)

	it("emits nil when the instance is reparented out from under the bound ancestor", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local parent = controller.newInstance()
		local inst = controller.newInstance(parent)
		controller.bind(binder, parent)

		local emissions = controller.observeAncestor(binder, inst)
		expect(#emissions).toEqual(1)

		inst.Parent = controller.container

		expect(#emissions).toEqual(2)
		expect(emissions[2]).toEqual(nil)

		controller:Destroy()
	end)

	it("emits nil when a mid-chain ancestor is reparented out of the bound ancestor", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)
		controller.bind(binder, grandparent)

		local emissions = controller.observeAncestor(binder, inst)
		expect(#emissions).toEqual(1)

		parent.Parent = controller.container

		expect(#emissions).toEqual(2)
		expect(emissions[2]).toEqual(nil)

		controller:Destroy()
	end)

	it("stops emitting once unsubscribed", function()
		local controller = setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local parent = controller.newInstance()
		local inst = controller.newInstance(parent)

		local emissions = controller.observeAncestor(binder, inst)
		emissions:Destroy()

		controller.bind(binder, parent)

		expect(#emissions).toEqual(1)

		controller:Destroy()
	end)
end)
