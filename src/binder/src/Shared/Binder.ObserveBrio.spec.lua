--!strict
--[[
	@class Binder.ObserveBrio.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local BinderTestUtils = require("BinderTestUtils")
local Brio = require("Brio")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local setup = BinderTestUtils.setup
local makeTrackingClass = BinderTestUtils.makeTrackingClass
local awaitUnbound = BinderTestUtils.awaitUnbound

describe("Binder:ObserveBrio()", function()
	it("emits a live brio wrapping the class on bind", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local inst = controller.newInstance()

		local brios = {}
		local sub = binder:ObserveBrio(inst):Subscribe(function(brio: Brio.Brio<any>)
			table.insert(brios, brio)
		end)

		expect(#brios).toEqual(0)

		binder:Tag(inst)
		local ok, class = binder:Promise(inst):Yield()
		assert(ok, "Never bound")

		expect(#brios).toEqual(1)
		expect(Brio.isBrio(brios[1])).toEqual(true)
		expect(brios[1]:IsDead()).toEqual(false)
		expect(brios[1]:GetValue()).toEqual(class)

		sub:Destroy()
		controller.destroy()
	end)

	it("emits immediately when the instance is already bound", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local inst = controller.newInstance()
		binder:Tag(inst)
		local ok, class = binder:Promise(inst):Yield()
		assert(ok, "Never bound")

		local brios = {}
		local sub = binder:ObserveBrio(inst):Subscribe(function(brio: Brio.Brio<any>)
			table.insert(brios, brio)
		end)

		expect(#brios).toEqual(1)
		expect(brios[1]:IsDead()).toEqual(false)
		expect(brios[1]:GetValue()).toEqual(class)

		sub:Destroy()
		controller.destroy()
	end)

	it("kills the emitted brio when the instance unbinds", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local inst = controller.newInstance()

		local brios = {}
		local sub = binder:ObserveBrio(inst):Subscribe(function(brio: Brio.Brio<any>)
			table.insert(brios, brio)
		end)

		binder:Tag(inst)
		assert((binder:Promise(inst):Yield()), "Never bound")
		expect(brios[1]:IsDead()).toEqual(false)

		binder:Untag(inst)
		awaitUnbound(binder, inst)

		expect(brios[1]:IsDead()).toEqual(true)

		sub:Destroy()
		controller.destroy()
	end)

	it("emits a fresh live brio when the instance rebinds", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local inst = controller.newInstance()

		local brios = {}
		local sub = binder:ObserveBrio(inst):Subscribe(function(brio: Brio.Brio<any>)
			table.insert(brios, brio)
		end)

		binder:Tag(inst)
		assert((binder:Promise(inst):Yield()), "Never bound")

		binder:Untag(inst)
		awaitUnbound(binder, inst)

		binder:Tag(inst)
		local ok, class = binder:Promise(inst):Yield()
		assert(ok, "Never rebound")

		expect(#brios).toEqual(2)
		expect(brios[1]:IsDead()).toEqual(true)
		expect(brios[2]:IsDead()).toEqual(false)
		expect(brios[2]:GetValue()).toEqual(class)

		sub:Destroy()
		controller.destroy()
	end)
end)

describe("Binder:ObserveAllBrio()", function()
	it("emits a live brio for every already-bound class on subscribe", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local instA = controller.newInstance()
		local instB = controller.newInstance()
		binder:Tag(instA)
		binder:Tag(instB)
		assert((binder:Promise(instA):Yield()), "A never bound")
		assert((binder:Promise(instB):Yield()), "B never bound")

		local values = {}
		local sub = binder:ObserveAllBrio():Subscribe(function(brio: Brio.Brio<any>)
			expect(brio:IsDead()).toEqual(false)
			values[brio:GetValue()] = true
		end)

		expect(values[binder:Get(instA)]).toEqual(true)
		expect(values[binder:Get(instB)]).toEqual(true)

		sub:Destroy()
		controller.destroy()
	end)

	it("emits a brio when a new class is added", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local brios = {}
		local sub = binder:ObserveAllBrio():Subscribe(function(brio: Brio.Brio<any>)
			table.insert(brios, brio)
		end)

		expect(#brios).toEqual(0)

		local inst = controller.newInstance()
		binder:Tag(inst)
		assert((binder:Promise(inst):Yield()), "Never bound")

		expect(#brios).toEqual(1)
		expect(brios[1]:IsDead()).toEqual(false)
		expect(brios[1]:GetValue()).toEqual(binder:Get(inst))

		sub:Destroy()
		controller.destroy()
	end)

	it("kills the brio when the class is removed", function()
		local controller = setup()

		local binder = controller.addBinder(makeTrackingClass())
		controller.boot()

		local inst = controller.newInstance()
		binder:Tag(inst)
		assert((binder:Promise(inst):Yield()), "Never bound")

		local brios = {}
		local sub = binder:ObserveAllBrio():Subscribe(function(brio: Brio.Brio<any>)
			table.insert(brios, brio)
		end)

		expect(#brios).toEqual(1)

		binder:Untag(inst)
		awaitUnbound(binder, inst)

		expect(brios[1]:IsDead()).toEqual(true)

		sub:Destroy()
		controller.destroy()
	end)
end)
