--!strict
--[[
	Unit tests for RxBrioUtils.lua
]]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Jest = require("Jest")
local Observable = require("Observable")
local ObservableSpy = require("ObservableSpy")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("RxBrioUtils.combineLatest({})", function()
	it("should execute immediately", function()
		local observe = RxBrioUtils.combineLatest({})
		local brios = ObservableSpy.new(observe :: any)
		local brio = brios:GetLastValue()
		expect(brio).never.toBeNil()
		expect(Brio.isBrio(brio)).toEqual(true)
		expect(brio:IsDead()).toEqual(true)

		brios:Destroy()
	end)
end)

describe("RxBrioUtils.combineLatest({ value = Observable(Brio(5)) })", function()
	it("should execute immediately", function()
		local observe = RxBrioUtils.combineLatest({
			value = Observable.new(function(innerSub): ()
				innerSub:Fire(Brio.new(5))
			end),
			otherValue = 25,
		})

		local brios = ObservableSpy.new(observe :: any)
		local brio = brios:GetLastValue()
		expect(brio).never.toBeNil()
		expect(Brio.isBrio(brio)).toEqual(true)
		expect(not brio:IsDead()).toEqual(true)
		expect(brio:GetValue()).toEqual(expect.any("table"))
		expect(brio:GetValue().value).toEqual(5)

		brios:Destroy()
	end)
end)

describe("RxBrioUtils.flatCombineLatest", function()
	local doFire
	local brio = Brio.new(5)
	local observe = RxBrioUtils.flatCombineLatest({
		value = Observable.new(function(sub): ()
			sub:Fire(brio)
			doFire = function(...)
				sub:Fire(...)
			end
		end),
		otherValue = 25,
	})

	local results = ObservableSpy.new(observe :: any)

	it("should execute immediately", function()
		expect(results:GetCount()).toEqual(1)
		expect(results:GetLastValue()).toEqual(expect.any("table"))
		expect(Brio.isBrio(results:GetLastValue())).toEqual(false)
		expect(results:GetLastValue().value).toEqual(5)
		expect(results:GetLastValue().otherValue).toEqual(25)
	end)

	it("should reset when the brio is killed", function()
		expect(results:GetCount()).toEqual(1)

		brio:Kill()

		expect(results:GetCount()).toEqual(2)
		expect(results:GetLastValue()).toEqual(expect.any("table"))
		expect(Brio.isBrio(results:GetLastValue())).toEqual(false)
		expect(results:GetLastValue().value).toEqual(nil)
		expect(results:GetLastValue().otherValue).toEqual(25)
	end)

	it("should allow a new value", function()
		expect(results:GetCount()).toEqual(2)

		doFire(Brio.new(70))

		expect(results:GetCount()).toEqual(3)
		expect(results:GetLastValue()).toEqual(expect.any("table"))
		expect(Brio.isBrio(results:GetLastValue())).toEqual(false)
		expect(results:GetLastValue().value).toEqual(70)
		expect(results:GetLastValue().otherValue).toEqual(25)
	end)

	it("should only fire once if we replace the value", function()
		expect(results:GetCount()).toEqual(3)

		doFire(Brio.new(75))

		expect(results:GetCount()).toEqual(4)
		expect(results:GetLastValue()).toEqual(expect.any("table"))
		expect(Brio.isBrio(results:GetLastValue())).toEqual(false)
		expect(results:GetLastValue().value).toEqual(75)
		expect(results:GetLastValue().otherValue).toEqual(25)
	end)

	it("should cleanup the sub", function()
		results:Destroy()
	end)
end)

describe("RxBrioUtils.switchToBrio", function()
	it("should wrap a plain value in a brio", function()
		local brios = ObservableSpy.new(Observable.new(function(innerSub): ()
			innerSub:Fire(42)
		end):Pipe({
			RxBrioUtils.switchToBrio() :: any,
		}) :: any)

		local latestBrio = brios:GetLastValue()
		expect(latestBrio).never.toBeNil()
		expect(Brio.isBrio(latestBrio)).toEqual(true)
		expect(latestBrio:IsDead()).toEqual(false)
		expect(latestBrio:GetValue()).toEqual(42)

		brios:Destroy()
	end)

	it("should wrap multiple plain values, packing them into a brio", function()
		local brios = ObservableSpy.new(Observable.new(function(innerSub): ()
			innerSub:Fire("a", "b")
		end):Pipe({
			RxBrioUtils.switchToBrio() :: any,
		}) :: any)

		local latestBrio = brios:GetLastValue()
		expect(latestBrio).never.toBeNil()
		expect(Brio.isBrio(latestBrio)).toEqual(true)
		expect(latestBrio:IsDead()).toEqual(false)

		local a, b = brios:GetLastValue():GetValue()
		expect(a).toEqual("a")
		expect(b).toEqual("b")

		brios:Destroy()
	end)

	it("should clone an input brio instead of forwarding it directly", function()
		local inputBrio = Brio.new(99)
		local brios = ObservableSpy.new(Observable.new(function(innerSub): ()
			innerSub:Fire(inputBrio)
		end):Pipe({
			RxBrioUtils.switchToBrio() :: any,
		}) :: any)

		local latestBrio = brios:GetLastValue()
		expect(latestBrio).never.toBeNil()
		expect(Brio.isBrio(latestBrio)).toEqual(true)
		expect(latestBrio:GetValue()).toEqual(99)
		-- Should be a clone, not the same object
		expect(brios:GetLastValue()).never.toEqual(inputBrio)

		brios:Destroy()
		inputBrio:Kill()
	end)

	it("should kill the previous brio when a new value is emitted", function()
		local doFire
		local results = ObservableSpy.new(Observable.new(function(innerSub): ()
			doFire = function(...)
				innerSub:Fire(...)
			end
		end):Pipe({
			RxBrioUtils.switchToBrio() :: any,
		}) :: any)

		doFire(1)
		doFire(2)

		expect(#results).toEqual(2)
		expect(results[1]:IsDead()).toEqual(true)
		expect(results[2]:IsDead()).toEqual(false)
		expect(results[2]:GetValue()).toEqual(2)

		results:Destroy()
	end)

	it("should kill the previous brio even when the new value is filtered by predicate", function()
		local doFire
		local results = ObservableSpy.new(Observable.new(function(innerSub): ()
			doFire = function(...)
				innerSub:Fire(...)
			end
		end):Pipe({
			RxBrioUtils.switchToBrio(function(value)
				return value ~= "skip"
			end) :: any,
		}) :: any)

		doFire("keep")
		expect(#results).toEqual(1)
		expect(results[1]:IsDead()).toEqual(false)

		doFire("skip") -- predicate rejects, but should still kill previous
		expect(#results).toEqual(1)
		expect(results[1]:IsDead()).toEqual(true)

		results:Destroy()
	end)

	it("should ignore dead brios from the source", function()
		local deadBrio = Brio.new(10)
		deadBrio:Kill()

		local emissions = ObservableSpy.new(Rx.of(deadBrio):Pipe({
			RxBrioUtils.switchToBrio() :: any,
		}) :: any)

		expect(#emissions).toEqual(0)
		expect(emissions:GetLastValue()).toBeNil()

		emissions:Destroy()
	end)

	it("should kill clone when the source brio dies", function()
		local inputBrio = Brio.new(5)
		local brios = ObservableSpy.new(Observable.new(function(innerSub): ()
			innerSub:Fire(inputBrio)
		end):Pipe({
			RxBrioUtils.switchToBrio() :: any,
		}) :: any)

		expect(brios:GetLastValue()).never.toBeNil()
		expect(brios:GetLastValue():IsDead()).toEqual(false)

		inputBrio:Kill()
		expect(brios:GetLastValue():IsDead()).toEqual(true)

		brios:Destroy()
	end)

	it("should kill the last brio on unsubscribe", function()
		local brios = ObservableSpy.new(Observable.new(function(innerSub): ()
			innerSub:Fire(77)
		end):Pipe({
			RxBrioUtils.switchToBrio() :: any,
		}) :: any)

		expect(brios:GetLastValue()).never.toBeNil()
		expect(brios:GetLastValue():IsDead()).toEqual(false)

		brios:Destroy()
		expect(brios:GetLastValue():IsDead()).toEqual(true)
	end)

	it("should propagate failure from source", function()
		local results = ObservableSpy.new(Observable.new(function(innerSub): ()
			innerSub:Fail("test error")
		end):Pipe({
			RxBrioUtils.switchToBrio() :: any,
		}) :: any)

		expect(results:HasFailed()).toEqual(true)
		expect(results:GetError()).toEqual("test error")

		results:Destroy()
	end)

	it("should propagate completion from source", function()
		local results = ObservableSpy.new(Observable.new(function(innerSub): ()
			innerSub:Complete()
		end):Pipe({
			RxBrioUtils.switchToBrio() :: any,
		}) :: any)

		expect(results:IsComplete()).toEqual(true)

		results:Destroy()
	end)

	it("should apply predicate to plain values", function()
		local doFire
		local results = ObservableSpy.new(Observable.new(function(innerSub): ()
			doFire = function(...)
				innerSub:Fire(...)
			end
		end):Pipe({
			RxBrioUtils.switchToBrio(function(value)
				return value > 10
			end) :: any,
		}) :: any)

		doFire(5)
		expect(#results).toEqual(0)

		doFire(15)
		expect(#results).toEqual(1)
		expect(results[1]:GetValue()).toEqual(15)

		doFire(3)
		expect(#results).toEqual(1)
		expect(results[1]:IsDead()).toEqual(true)

		results:Destroy()
	end)

	it("should apply predicate to unwrapped brio values", function()
		local doFire
		local results = ObservableSpy.new(Observable.new(function(innerSub): ()
			doFire = function(...)
				innerSub:Fire(...)
			end
		end):Pipe({
			RxBrioUtils.switchToBrio(function(value)
				return value > 10
			end) :: any,
		}) :: any)

		doFire(Brio.new(5))
		expect(#results).toEqual(0)

		doFire(Brio.new(20))
		expect(#results).toEqual(1)
		expect(results[1]:GetValue()).toEqual(20)

		results:Destroy()
	end)

	it("should handle rapid succession of emissions correctly", function()
		local doFire
		local results = ObservableSpy.new(Observable.new(function(innerSub): ()
			doFire = function(...)
				innerSub:Fire(...)
			end
		end):Pipe({
			RxBrioUtils.switchToBrio() :: any,
		}) :: any)

		for i = 1, 100 do
			doFire(i)
		end

		expect(#results).toEqual(100)

		-- All but last should be dead
		for i = 1, 99 do
			expect(results[i]:IsDead()).toEqual(true)
		end
		expect(results[100]:IsDead()).toEqual(false)
		expect(results[100]:GetValue()).toEqual(100)

		results:Destroy()
	end)

	it("should handle interleaved brio and plain value emissions", function()
		local doFire
		local results = ObservableSpy.new(Observable.new(function(innerSub): ()
			doFire = function(...)
				innerSub:Fire(...)
			end
		end):Pipe({
			RxBrioUtils.switchToBrio() :: any,
		}) :: any)

		local inputBrio = Brio.new("from-brio")
		doFire("plain")
		doFire(inputBrio)
		doFire("plain-again")

		expect(#results).toEqual(3)
		expect(results[1]:IsDead()).toEqual(true)
		expect(results[2]:IsDead()).toEqual(true)
		expect(results[3]:IsDead()).toEqual(false)
		expect(results[3]:GetValue()).toEqual("plain-again")

		results:Destroy()
	end)

	it("should handle source brio dying while subscribed then new emission", function()
		local doFire
		local results = ObservableSpy.new(Observable.new(function(innerSub): ()
			doFire = function(...)
				innerSub:Fire(...)
			end
		end):Pipe({
			RxBrioUtils.switchToBrio() :: any,
		}) :: any)

		local brio1 = Brio.new("first")
		doFire(brio1)
		expect(#results).toEqual(1)
		expect(results[1]:IsDead()).toEqual(false)

		-- Source brio dies externally
		brio1:Kill()
		expect(results[1]:IsDead()).toEqual(true)

		-- New emission should still work
		doFire("second")
		expect(#results).toEqual(2)
		expect(results[2]:IsDead()).toEqual(false)
		expect(results[2]:GetValue()).toEqual("second")

		results:Destroy()
	end)

	it("should handle subscriber causing re-emission during fire", function()
		-- Race condition: subscriber fires a new value during the callback
		local doFire
		local results = {}
		local reEmitted = false

		local sub = Observable.new(function(innerSub): ()
			doFire = function(...)
				innerSub:Fire(...)
			end
		end)
			:Pipe({
				RxBrioUtils.switchToBrio() :: any,
			})
			:Subscribe(function(brio)
				table.insert(results, brio)

				-- On first emission, synchronously emit another value
				if not reEmitted then
					reEmitted = true
					doFire("re-emitted")
				end
			end)

		doFire("initial")

		expect(#results).toEqual(2)
		-- The initial brio should be dead because re-emission killed it
		expect(results[1]:IsDead()).toEqual(true)
		-- The re-emitted brio should be alive
		expect(results[2]:IsDead()).toEqual(false)
		expect(results[2]:GetValue()).toEqual("re-emitted")

		sub:Destroy()
	end)

	it("should not emit when predicate is provided and all values are rejected", function()
		local doFire

		local emissions = ObservableSpy.new(Observable.new(function(innerSub): ()
			doFire = function(...)
				innerSub:Fire(...)
			end
		end):Pipe({
			RxBrioUtils.switchToBrio(function()
				return false
			end) :: any,
		}) :: any)

		doFire(1)
		doFire(2)
		doFire(Brio.new(3))

		expect(#emissions).toEqual(0)

		emissions:Destroy()
	end)

	it("should error with non-function predicate", function()
		expect(function()
			RxBrioUtils.switchToBrio("bad" :: any)
		end).toThrow()
	end)
end)
