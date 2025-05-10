--[[
	Unit tests for RxBrioUtils.lua
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Brio = require("Brio")
local Jest = require("Jest")
local Observable = require("Observable")
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
			value = Observable.new(function(sub)
				sub:Fire(Brio.new(5))
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
		value = Observable.new(function(sub)
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
