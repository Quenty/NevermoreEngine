--!strict
--[[
	Unit tests for RxBrioUtils.lua
]]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local Jest = require("Jest")
local Observable = require("Observable")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("RxBrioUtils.combineLatest({})", function()
	it("should execute immediately", function()
		local observe = RxBrioUtils.combineLatest({})
		local brio
		local sub = observe:Subscribe(function(result)
			brio = result
		end)
		expect(brio).never.toBeNil()
		expect(Brio.isBrio(brio)).toEqual(true)
		expect(brio:IsDead()).toEqual(true)

		sub:Destroy()
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
		local brio

		local sub = observe:Subscribe(function(result)
			brio = result
		end)
		expect(brio).never.toBeNil()
		expect(Brio.isBrio(brio)).toEqual(true)
		expect(not brio:IsDead()).toEqual(true)
		expect(brio:GetValue()).toEqual(expect.any("table"))
		expect(brio:GetValue().value).toEqual(5)

		sub:Destroy()
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

	local lastResult = nil
	local fireCount = 0

	local sub = observe:Subscribe(function(result)
		lastResult = result
		fireCount = fireCount + 1
	end)

	it("should execute immediately", function()
		expect(fireCount).toEqual(1)
		expect(lastResult).toEqual(expect.any("table"))
		expect(Brio.isBrio(lastResult)).toEqual(false)
		expect(lastResult.value).toEqual(5)
		expect(lastResult.otherValue).toEqual(25)
	end)

	it("should reset when the brio is killed", function()
		expect(fireCount).toEqual(1)

		brio:Kill()

		expect(fireCount).toEqual(2)
		expect(lastResult).toEqual(expect.any("table"))
		expect(Brio.isBrio(lastResult)).toEqual(false)
		expect(lastResult.value).toEqual(nil)
		expect(lastResult.otherValue).toEqual(25)
	end)

	it("should allow a new value", function()
		expect(fireCount).toEqual(2)

		doFire(Brio.new(70))

		expect(fireCount).toEqual(3)
		expect(lastResult).toEqual(expect.any("table"))
		expect(Brio.isBrio(lastResult)).toEqual(false)
		expect(lastResult.value).toEqual(70)
		expect(lastResult.otherValue).toEqual(25)
	end)

	it("should only fire once if we replace the value", function()
		expect(fireCount).toEqual(3)

		doFire(Brio.new(75))

		expect(fireCount).toEqual(4)
		expect(lastResult).toEqual(expect.any("table"))
		expect(Brio.isBrio(lastResult)).toEqual(false)
		expect(lastResult.value).toEqual(75)
		expect(lastResult.otherValue).toEqual(25)
	end)

	it("should cleanup the sub", function()
		sub:Destroy()
	end)
end)

describe("RxBrioUtils.switchToBrio", function()
	it("should wrap a plain value in a brio", function()
		local result
		local sub = Observable.new(function(innerSub): ()
			innerSub:Fire(42)
		end)
			:Pipe({
				RxBrioUtils.switchToBrio() :: any,
			})
			:Subscribe(function(brio)
				result = brio
			end)

		expect(result).never.toBeNil()
		expect(Brio.isBrio(result)).toEqual(true)
		expect(result:IsDead()).toEqual(false)
		expect(result:GetValue()).toEqual(42)

		sub:Destroy()
	end)

	it("should wrap multiple plain values, packing them into a brio", function()
		local result
		local sub = Observable.new(function(innerSub): ()
			innerSub:Fire("a", "b")
		end)
			:Pipe({
				RxBrioUtils.switchToBrio() :: any,
			})
			:Subscribe(function(brio)
				result = brio
			end)

		expect(result).never.toBeNil()
		expect(Brio.isBrio(result)).toEqual(true)
		expect(result:IsDead()).toEqual(false)

		local a, b = result:GetValue()
		expect(a).toEqual("a")
		expect(b).toEqual("b")

		sub:Destroy()
	end)

	it("should clone an input brio instead of forwarding it directly", function()
		local inputBrio = Brio.new(99)
		local result
		local sub = Observable.new(function(innerSub): ()
			innerSub:Fire(inputBrio)
		end)
			:Pipe({
				RxBrioUtils.switchToBrio() :: any,
			})
			:Subscribe(function(brio)
				result = brio
			end)

		expect(result).never.toBeNil()
		expect(Brio.isBrio(result)).toEqual(true)
		expect(result:GetValue()).toEqual(99)
		-- Should be a clone, not the same object
		expect(result).never.toEqual(inputBrio)

		sub:Destroy()
		inputBrio:Kill()
	end)

	it("should kill the previous brio when a new value is emitted", function()
		local doFire
		local results = {}
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
			end)

		doFire(1)
		doFire(2)

		expect(#results).toEqual(2)
		expect(results[1]:IsDead()).toEqual(true)
		expect(results[2]:IsDead()).toEqual(false)
		expect(results[2]:GetValue()).toEqual(2)

		sub:Destroy()
	end)

	it("should kill the previous brio even when the new value is filtered by predicate", function()
		local doFire
		local results = {}
		local sub = Observable.new(function(innerSub): ()
			doFire = function(...)
				innerSub:Fire(...)
			end
		end)
			:Pipe({
				RxBrioUtils.switchToBrio(function(value)
					return value ~= "skip"
				end) :: any,
			})
			:Subscribe(function(brio)
				table.insert(results, brio)
			end)

		doFire("keep")
		expect(#results).toEqual(1)
		expect(results[1]:IsDead()).toEqual(false)

		doFire("skip") -- predicate rejects, but should still kill previous
		expect(#results).toEqual(1)
		expect(results[1]:IsDead()).toEqual(true)

		sub:Destroy()
	end)

	it("should ignore dead brios from the source", function()
		local deadBrio = Brio.new(10)
		deadBrio:Kill()

		local result
		local fireCount = 0
		local sub = Rx.of(deadBrio)
			:Pipe({
				RxBrioUtils.switchToBrio() :: any,
			})
			:Subscribe(function(brio)
				result = brio
				fireCount = fireCount + 1
			end)

		expect(fireCount).toEqual(0)
		expect(result).toBeNil()

		sub:Destroy()
	end)

	it("should kill clone when the source brio dies", function()
		local inputBrio = Brio.new(5)
		local result
		local sub = Observable.new(function(innerSub): ()
			innerSub:Fire(inputBrio)
		end)
			:Pipe({
				RxBrioUtils.switchToBrio() :: any,
			})
			:Subscribe(function(brio)
				result = brio
			end)

		expect(result).never.toBeNil()
		expect(result:IsDead()).toEqual(false)

		inputBrio:Kill()
		expect(result:IsDead()).toEqual(true)

		sub:Destroy()
	end)

	it("should kill the last brio on unsubscribe", function()
		local result
		local sub = Observable.new(function(innerSub): ()
			innerSub:Fire(77)
		end)
			:Pipe({
				RxBrioUtils.switchToBrio() :: any,
			})
			:Subscribe(function(brio)
				result = brio
			end)

		expect(result).never.toBeNil()
		expect(result:IsDead()).toEqual(false)

		sub:Destroy()
		expect(result:IsDead()).toEqual(true)
	end)

	it("should propagate failure from source", function()
		local failed = false
		local failMsg
		local sub = Observable.new(function(innerSub): ()
			innerSub:Fail("test error")
		end)
			:Pipe({
				RxBrioUtils.switchToBrio() :: any,
			})
			:Subscribe(function() end, function(err)
				failed = true
				failMsg = err
			end)

		expect(failed).toEqual(true)
		expect(failMsg).toEqual("test error")

		sub:Destroy()
	end)

	it("should propagate completion from source", function()
		local completed = false
		local sub = Observable.new(function(innerSub): ()
			innerSub:Complete()
		end)
			:Pipe({
				RxBrioUtils.switchToBrio() :: any,
			})
			:Subscribe(function() end, function() end, function()
				completed = true
			end)

		expect(completed).toEqual(true)

		sub:Destroy()
	end)

	it("should apply predicate to plain values", function()
		local doFire
		local results = {}
		local sub = Observable.new(function(innerSub): ()
			doFire = function(...)
				innerSub:Fire(...)
			end
		end)
			:Pipe({
				RxBrioUtils.switchToBrio(function(value)
					return value > 10
				end) :: any,
			})
			:Subscribe(function(brio)
				table.insert(results, brio)
			end)

		doFire(5)
		expect(#results).toEqual(0)

		doFire(15)
		expect(#results).toEqual(1)
		expect(results[1]:GetValue()).toEqual(15)

		doFire(3)
		expect(#results).toEqual(1)
		expect(results[1]:IsDead()).toEqual(true)

		sub:Destroy()
	end)

	it("should apply predicate to unwrapped brio values", function()
		local doFire
		local results = {}
		local sub = Observable.new(function(innerSub): ()
			doFire = function(...)
				innerSub:Fire(...)
			end
		end)
			:Pipe({
				RxBrioUtils.switchToBrio(function(value)
					return value > 10
				end) :: any,
			})
			:Subscribe(function(brio)
				table.insert(results, brio)
			end)

		doFire(Brio.new(5))
		expect(#results).toEqual(0)

		doFire(Brio.new(20))
		expect(#results).toEqual(1)
		expect(results[1]:GetValue()).toEqual(20)

		sub:Destroy()
	end)

	it("should handle rapid succession of emissions correctly", function()
		local doFire
		local results = {}
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
			end)

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

		sub:Destroy()
	end)

	it("should handle interleaved brio and plain value emissions", function()
		local doFire
		local results = {}
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
			end)

		local inputBrio = Brio.new("from-brio")
		doFire("plain")
		doFire(inputBrio)
		doFire("plain-again")

		expect(#results).toEqual(3)
		expect(results[1]:IsDead()).toEqual(true)
		expect(results[2]:IsDead()).toEqual(true)
		expect(results[3]:IsDead()).toEqual(false)
		expect(results[3]:GetValue()).toEqual("plain-again")

		sub:Destroy()
	end)

	it("should handle source brio dying while subscribed then new emission", function()
		local doFire
		local results = {}
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
			end)

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

		sub:Destroy()
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
		local fireCount = 0

		local sub = Observable.new(function(innerSub): ()
			doFire = function(...)
				innerSub:Fire(...)
			end
		end)
			:Pipe({
				RxBrioUtils.switchToBrio(function()
					return false
				end) :: any,
			})
			:Subscribe(function()
				fireCount = fireCount + 1
			end)

		doFire(1)
		doFire(2)
		doFire(Brio.new(3))

		expect(fireCount).toEqual(0)

		sub:Destroy()
	end)

	it("should error with non-function predicate", function()
		expect(function()
			RxBrioUtils.switchToBrio("bad" :: any)
		end).toThrow()
	end)
end)
