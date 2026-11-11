--!strict
--[[
	@class MetricUnit.Spring.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local LinearValue = require("LinearValue")
local MetricUnit = require("MetricUnit")
local Spring = require("Spring")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function manualClock(): (() -> number, (number) -> ())
	local now = 0
	return function()
		return now
	end, function(seconds: number)
		now += seconds
	end
end

describe("MetricUnit in a Spring", function()
	it("animates a length to its target", function()
		local clock, advance = manualClock()
		local spring = Spring.new(MetricUnit.meters(0), clock)
		spring.Speed = 20
		spring.Target = MetricUnit.meters(10)

		advance(0.05)
		local midway = (spring.Position :: any):In("meter")
		expect(midway > 0 and midway < 10).toBe(true)
		-- Spring's clock is a plain number, so its velocity is in the position's units per second
		expect((spring.Velocity :: any):GetKind()).toBe("length")

		advance(10)
		expect((spring.Position :: any):In("meter")).toBeCloseTo(10, 6)
		expect((spring.Velocity :: any):In("meter")).toBeCloseTo(0, 6)
	end)

	it("starts from a spring made with no initial value", function()
		local clock, advance = manualClock()
		local spring = Spring.new(nil :: any, clock)
		spring.Target = MetricUnit.new(5, "volt")
		advance(30)
		expect((spring.Position :: any):In("volt")).toBeCloseTo(5, 6)
	end)

	it("takes an impulse in the position's units, and refuses one of another dimension", function()
		local clock, advance = manualClock()
		local spring = Spring.new(MetricUnit.meters(0), clock)
		spring:Impulse(MetricUnit.meters(4))
		advance(0.01)
		expect((spring.Position :: any):In("meter") > 0).toBe(true)
		expect(function()
			spring:Impulse(MetricUnit.new(4, "meterPerSecond") :: any)
		end).toThrow()
	end)

	it("skips time and snaps to a target without animating", function()
		local clock = manualClock()
		local spring = Spring.new(MetricUnit.celsius(0) - MetricUnit.celsius(0), clock)
		spring:SetTarget(MetricUnit.difference(20, "celsius"), true)
		expect((spring.Position :: any):In("kelvin")).toBe(20)
		spring.Target = MetricUnit.difference(0, "celsius")
		spring:TimeSkip(60)
		expect((spring.Position :: any):In("kelvin")).toBeCloseTo(0, 6)
	end)

	it("springs an absolute value through its offset from a reference", function()
		expect(function()
			Spring.new(MetricUnit.celsius(20))
		end).toThrow("cannot multiply an absolute temperature")

		local clock, advance = manualClock()
		local reference = MetricUnit.celsius(0)
		local spring = Spring.new(MetricUnit.celsius(15) - reference, clock)
		spring.Target = MetricUnit.celsius(25) - reference
		advance(60)
		expect((reference + spring.Position :: any):In("celsius")).toBeCloseTo(25, 6)
	end)
end)

describe("MetricUnit and LinearValue", function()
	it("passes through LinearValue untouched, since it is linear already", function()
		local value = MetricUnit.meters(3)
		expect(LinearValue.isLinear(value)).toBe(false)
		expect(LinearValue.toLinearIfNeeded(value)).toBe(value)
		expect(LinearValue.fromLinearIfNeeded(value)).toBe(value)
	end)
end)
