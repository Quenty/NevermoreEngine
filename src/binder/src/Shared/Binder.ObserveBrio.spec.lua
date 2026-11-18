--!strict
--[[
	@class Binder.ObserveBrio.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local BinderTestUtils = require("BinderTestUtils")
local Brio = require("Brio")
local Jest = require("Jest")
local ObservableSpy = require("ObservableSpy")
local PromiseTestUtils = require("PromiseTestUtils")
local RxBrioTestUtils = require("RxBrioTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("Binder:ObserveBrio()", function()
	it("emits a live brio wrapping the class on bind", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local inst = controller.newInstance()

		local brios = ObservableSpy.new(binder:ObserveBrio(inst))

		expect(#brios).toEqual(0)

		binder:Tag(inst)
		local class = PromiseTestUtils.awaitFulfilled(binder:Promise(inst))

		expect(#brios).toEqual(1)
		expect(Brio.isBrio(brios[1])).toEqual(true)
		expect(brios[1]:IsDead()).toEqual(false)
		expect(brios[1]:GetValue()).toEqual(class)

		brios:Destroy()
		controller:Destroy()
	end)

	it("emits immediately when the instance is already bound", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local inst = controller.newInstance()
		binder:Tag(inst)
		local class = PromiseTestUtils.awaitFulfilled(binder:Promise(inst))

		local brios = ObservableSpy.new(binder:ObserveBrio(inst))

		expect(#brios).toEqual(1)
		expect(brios[1]:IsDead()).toEqual(false)
		expect(brios[1]:GetValue()).toEqual(class)

		brios:Destroy()
		controller:Destroy()
	end)

	it("kills the emitted brio when the instance unbinds", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local inst = controller.newInstance()

		local brios = ObservableSpy.new(binder:ObserveBrio(inst))

		binder:Tag(inst)
		PromiseTestUtils.awaitFulfilled(binder:Promise(inst))
		expect(brios[1]:IsDead()).toEqual(false)

		binder:Untag(inst)
		expect(binder:Get(inst)).toBeNil()

		expect(brios[1]:IsDead()).toEqual(true)

		brios:Destroy()
		controller:Destroy()
	end)

	it("emits a fresh live brio when the instance rebinds", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local inst = controller.newInstance()

		local brios = ObservableSpy.new(binder:ObserveBrio(inst))

		binder:Tag(inst)
		PromiseTestUtils.awaitFulfilled(binder:Promise(inst))

		binder:Untag(inst)
		expect(binder:Get(inst)).toBeNil()

		binder:Tag(inst)
		local class = PromiseTestUtils.awaitFulfilled(binder:Promise(inst))

		expect(#brios).toEqual(2)
		expect(brios[1]:IsDead()).toEqual(true)
		expect(brios[2]:IsDead()).toEqual(false)
		expect(brios[2]:GetValue()).toEqual(class)

		brios:Destroy()
		controller:Destroy()
	end)
end)

describe("Binder:ObserveAllBrio()", function()
	it("emits a live brio for every already-bound class on subscribe", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local instA = controller.newInstance()
		local instB = controller.newInstance()
		binder:Tag(instA)
		binder:Tag(instB)
		PromiseTestUtils.awaitFulfilled(binder:Promise(instA))
		PromiseTestUtils.awaitFulfilled(binder:Promise(instB))

		local aliveClasses = RxBrioTestUtils.collectAliveSet(controller.maid, binder:ObserveAllBrio())

		expect(aliveClasses[binder:Get(instA)]).toEqual(true)
		expect(aliveClasses[binder:Get(instB)]).toEqual(true)

		controller:Destroy()
	end)

	it("emits a brio when a new class is added", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local brios = ObservableSpy.new(binder:ObserveAllBrio())

		expect(#brios).toEqual(0)

		local inst = controller.newInstance()
		binder:Tag(inst)
		PromiseTestUtils.awaitFulfilled(binder:Promise(inst))

		expect(#brios).toEqual(1)
		expect(brios[1]:IsDead()).toEqual(false)
		expect(brios[1]:GetValue()).toEqual(binder:Get(inst))

		brios:Destroy()
		controller:Destroy()
	end)

	it("kills the brio when the class is removed", function()
		local controller = BinderTestUtils.setup()

		local binder = controller.addBinder(BinderTestUtils.makeTrackingClass())
		controller.initServiceBag()

		local inst = controller.newInstance()
		binder:Tag(inst)
		PromiseTestUtils.awaitFulfilled(binder:Promise(inst))

		local brios = ObservableSpy.new(binder:ObserveAllBrio())

		expect(#brios).toEqual(1)

		binder:Untag(inst)
		expect(binder:Get(inst)).toBeNil()

		expect(brios[1]:IsDead()).toEqual(true)

		brios:Destroy()
		controller:Destroy()
	end)
end)
