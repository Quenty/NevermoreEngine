--!strict
--[[
	@class RxBinderUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local BinderTestUtils = require("BinderTestUtils")
local Jest = require("Jest")
local RxBinderUtils = require("RxBinderUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local setup = BinderTestUtils.setup
local makeTrackingClass = BinderTestUtils.makeTrackingClass
local awaitUnbound = BinderTestUtils.awaitUnbound

type Emission = { value: any }

local function bind(binder, inst: Instance): any
	binder:Tag(inst)
	local ok, class = binder:Promise(inst):Yield()
	assert(ok, "Never bound")
	return class
end

local function unbind(binder, inst: Instance)
	binder:Untag(inst)
	awaitUnbound(binder, inst)
end

local function observe(binder, inst: Instance): ({ Emission }, any)
	local emissions: { Emission } = {}
	local sub = RxBinderUtils.observeBoundAncestor(binder, inst):Subscribe(function(class)
		table.insert(emissions, { value = class })
	end)
	return emissions, sub
end

describe("RxBinderUtils.observeBoundParent()", function()
	local function observeParent(binder, inst: Instance): ({ Emission }, any)
		local emissions: { Emission } = {}
		local sub = RxBinderUtils.observeBoundParent(binder, inst):Subscribe(function(class)
			table.insert(emissions, { value = class })
		end)
		return emissions, sub
	end

	it("emits the already-bound parent on subscribe", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local parent = controller.newInstance()
		local inst = controller.newInstance(parent)
		local class = bind(binder, parent)

		local emissions, sub = observeParent(binder, inst)

		expect(#emissions).toEqual(1)
		expect(emissions[1].value).toEqual(class)

		sub:Destroy()
		controller:Destroy()
	end)

	it("emits nil when the parent is unbound", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local parent = controller.newInstance()
		local inst = controller.newInstance(parent)

		local emissions, sub = observeParent(binder, inst)

		expect(#emissions).toEqual(1)
		expect(emissions[1].value).toEqual(nil)

		sub:Destroy()
		controller:Destroy()
	end)

	it("ignores a bound grandparent", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)
		bind(binder, grandparent)

		local emissions, sub = observeParent(binder, inst)

		expect(#emissions).toEqual(1)
		expect(emissions[1].value).toEqual(nil)

		sub:Destroy()
		controller:Destroy()
	end)

	it("emits when the parent binds afterwards", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local parent = controller.newInstance()
		local inst = controller.newInstance(parent)

		local emissions, sub = observeParent(binder, inst)

		local class = bind(binder, parent)

		expect(#emissions).toEqual(2)
		expect(emissions[2].value).toEqual(class)

		sub:Destroy()
		controller:Destroy()
	end)

	it("follows the new parent when the instance is reparented", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local first = controller.newInstance()
		local second = controller.newInstance()
		local inst = controller.newInstance(first)
		local firstClass = bind(binder, first)
		local secondClass = bind(binder, second)

		local emissions, sub = observeParent(binder, inst)
		expect(emissions[1].value).toEqual(firstClass)

		inst.Parent = second

		expect(#emissions).toEqual(2)
		expect(emissions[2].value).toEqual(secondClass)

		sub:Destroy()
		controller:Destroy()
	end)

	it("keeps tracking after the instance is left without a parent", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local first = controller.newInstance()
		local second = controller.newInstance()
		local inst = controller.newInstance(first)
		local firstClass = bind(binder, first)
		local secondClass = bind(binder, second)

		local emissions, sub = observeParent(binder, inst)
		expect(emissions[1].value).toEqual(firstClass)

		inst.Parent = nil
		expect(emissions[#emissions].value).toEqual(nil)

		inst.Parent = second
		expect(emissions[#emissions].value).toEqual(secondClass)

		sub:Destroy()
		controller:Destroy()
	end)

	it("does not emit when an unrelated instance binds", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local parent = controller.newInstance()
		local inst = controller.newInstance(parent)
		local unrelated = controller.newInstance()

		local emissions, sub = observeParent(binder, inst)

		bind(binder, unrelated)

		expect(#emissions).toEqual(1)

		sub:Destroy()
		controller:Destroy()
	end)
end)

describe("RxBinderUtils.observeBoundAncestor()", function()
	it("emits nil immediately when no ancestor is bound", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local inst = controller.newInstance()

		local emissions, sub = observe(binder, inst)

		expect(#emissions).toEqual(1)
		expect(emissions[1].value).toEqual(nil)

		sub:Destroy()
		controller:Destroy()
	end)

	it("emits the already-bound direct parent on subscribe", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local parent = controller.newInstance()
		local inst = controller.newInstance(parent)
		local class = bind(binder, parent)

		local emissions, sub = observe(binder, inst)

		expect(#emissions).toEqual(1)
		expect(emissions[1].value).toEqual(class)

		sub:Destroy()
		controller:Destroy()
	end)

	it("emits a bound grandparent when the direct parent is unbound", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)
		local class = bind(binder, grandparent)

		local emissions, sub = observe(binder, inst)

		expect(#emissions).toEqual(1)
		expect(emissions[1].value).toEqual(class)

		sub:Destroy()
		controller:Destroy()
	end)

	it("never emits the instance's own bound class", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local inst = controller.newInstance()

		local emissions, sub = observe(binder, inst)

		bind(binder, inst)

		expect(#emissions).toEqual(1)
		expect(emissions[1].value).toEqual(nil)

		sub:Destroy()
		controller:Destroy()
	end)

	it("emits when an ancestor becomes bound after subscribing", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)

		local emissions, sub = observe(binder, inst)

		local class = bind(binder, grandparent)

		expect(#emissions).toEqual(2)
		expect(emissions[2].value).toEqual(class)

		sub:Destroy()
		controller:Destroy()
	end)

	it("switches to a nearer ancestor when one becomes bound", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)
		bind(binder, grandparent)

		local emissions, sub = observe(binder, inst)

		local parentClass = bind(binder, parent)

		expect(#emissions).toEqual(2)
		expect(emissions[2].value).toEqual(parentClass)

		sub:Destroy()
		controller:Destroy()
	end)

	it("keeps tracking an ancestor that survives a rebuild of the watched chain", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)
		local grandparentClass = bind(binder, grandparent)

		local emissions, sub = observe(binder, inst)

		local parentClass = bind(binder, parent)
		expect(#emissions).toEqual(2)
		expect(emissions[2].value).toEqual(parentClass)

		unbind(binder, parent)

		expect(#emissions).toEqual(3)
		expect(emissions[3].value).toEqual(grandparentClass)

		sub:Destroy()
		controller:Destroy()
	end)

	it("emits the closest bound ancestor when several ancestors are bound", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local greatGrandparent = controller.newInstance()
		local grandparent = controller.newInstance(greatGrandparent)
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)

		bind(binder, greatGrandparent)
		bind(binder, grandparent)
		local parentClass = bind(binder, parent)

		local emissions, sub = observe(binder, inst)

		expect(#emissions).toEqual(1)
		expect(emissions[1].value).toEqual(parentClass)

		sub:Destroy()
		controller:Destroy()
	end)

	it("keeps the closer ancestor when a farther one binds afterwards", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)
		local parentClass = bind(binder, parent)

		local emissions, sub = observe(binder, inst)
		expect(emissions[1].value).toEqual(parentClass)

		bind(binder, grandparent)

		expect(#emissions).toEqual(1)

		sub:Destroy()
		controller:Destroy()
	end)

	it("walks past several unbound ancestors to the closest bound one", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local greatGrandparent = controller.newInstance()
		local grandparent = controller.newInstance(greatGrandparent)
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)
		local class = bind(binder, greatGrandparent)

		local emissions, sub = observe(binder, inst)
		expect(emissions[1].value).toEqual(class)

		local grandparentClass = bind(binder, grandparent)

		expect(#emissions).toEqual(2)
		expect(emissions[2].value).toEqual(grandparentClass)

		sub:Destroy()
		controller:Destroy()
	end)

	it("recovers to the next bound ancestor when the closest is destroyed", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)
		local grandparentClass = bind(binder, grandparent)
		bind(binder, parent)

		local emissions, sub = observe(binder, inst)
		expect(#emissions).toEqual(1)

		inst.Parent = grandparent
		parent:Destroy()

		expect(emissions[#emissions].value).toEqual(grandparentClass)

		sub:Destroy()
		controller:Destroy()
	end)

	it("does not emit when an unrelated instance binds", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local inst = controller.newInstance()
		local unrelated = controller.newInstance()

		local emissions, sub = observe(binder, inst)

		bind(binder, unrelated)

		expect(#emissions).toEqual(1)

		sub:Destroy()
		controller:Destroy()
	end)

	it("emits nil when the bound ancestor unbinds", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local parent = controller.newInstance()
		local inst = controller.newInstance(parent)
		bind(binder, parent)

		local emissions, sub = observe(binder, inst)
		expect(#emissions).toEqual(1)

		unbind(binder, parent)

		expect(#emissions).toEqual(2)
		expect(emissions[2].value).toEqual(nil)

		sub:Destroy()
		controller:Destroy()
	end)

	it("falls back to the next bound ancestor when the nearest unbinds", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)
		local grandparentClass = bind(binder, grandparent)
		bind(binder, parent)

		local emissions, sub = observe(binder, inst)

		unbind(binder, parent)

		expect(#emissions).toEqual(2)
		expect(emissions[2].value).toEqual(grandparentClass)

		sub:Destroy()
		controller:Destroy()
	end)

	it("emits when the instance is reparented under a bound ancestor", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local parent = controller.newInstance()
		local inst = controller.newInstance()
		local class = bind(binder, parent)

		local emissions, sub = observe(binder, inst)
		expect(emissions[1].value).toEqual(nil)

		inst.Parent = parent

		expect(#emissions).toEqual(2)
		expect(emissions[2].value).toEqual(class)

		sub:Destroy()
		controller:Destroy()
	end)

	it("emits nil when the instance is reparented out from under the bound ancestor", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local parent = controller.newInstance()
		local inst = controller.newInstance(parent)
		bind(binder, parent)

		local emissions, sub = observe(binder, inst)
		expect(#emissions).toEqual(1)

		inst.Parent = controller.container

		expect(#emissions).toEqual(2)
		expect(emissions[2].value).toEqual(nil)

		sub:Destroy()
		controller:Destroy()
	end)

	it("emits nil when a mid-chain ancestor is reparented out of the bound ancestor", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local grandparent = controller.newInstance()
		local parent = controller.newInstance(grandparent)
		local inst = controller.newInstance(parent)
		bind(binder, grandparent)

		local emissions, sub = observe(binder, inst)
		expect(#emissions).toEqual(1)

		parent.Parent = controller.container

		expect(#emissions).toEqual(2)
		expect(emissions[2].value).toEqual(nil)

		sub:Destroy()
		controller:Destroy()
	end)

	it("stops emitting once unsubscribed", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local parent = controller.newInstance()
		local inst = controller.newInstance(parent)

		local emissions, sub = observe(binder, inst)
		sub:Destroy()

		bind(binder, parent)

		expect(#emissions).toEqual(1)

		controller:Destroy()
	end)
end)
