--!strict
--[[
	@class MetricUnit.Math.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUnit = require("MetricUnit")
local MetricUnitSystems = require("MetricUnitSystems")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("MetricUnit.lerp", function()
	it("interpolates differences and absolutes alike", function()
		expect(MetricUnit.lerp(MetricUnit.meters(0), MetricUnit.meters(10), 0.25):In("meter")).toBe(2.5)
		local temperature = MetricUnit.lerp(MetricUnit.celsius(10), MetricUnit.celsius(20), 0.5)
		expect(temperature:IsAbsolute()).toBe(true)
		expect(temperature:In("celsius")).toBeCloseTo(15, 9)
		local instant = MetricUnit.lerp(MetricUnit.instant(0), MetricUnit.instant(100), 0.5)
		expect(instant:GetKind()).toBe("instant")
		expect(instant:InSeconds()).toBe(50)
	end)

	it("errors between different dimensions", function()
		expect(function()
			MetricUnit.lerp(MetricUnit.meters(1), MetricUnit.seconds(1), 0.5)
		end).toThrow("cannot subtract")
	end)
end)

describe("MetricUnit rounding", function()
	it("rounds, floors and ceils to a unit", function()
		expect(MetricUnit.round(MetricUnit.seconds(95), "minute"):In("minute")).toBe(2)
		expect(MetricUnit.floor(MetricUnit.seconds(95), "minute"):In("minute")).toBe(1)
		expect(MetricUnit.ceil(MetricUnit.seconds(61), "minute"):In("minute")).toBe(2)
		expect(MetricUnit.round(MetricUnit.meters(1234), "kilometer"):In("kilometer")).toBe(1)
	end)

	it("snaps to a multiple of a step", function()
		expect(MetricUnit.round(MetricUnit.meters(12.4), MetricUnit.meters(5)):In("meter")).toBe(10)
		expect(MetricUnit.round(MetricUnit.meters(12.6), MetricUnit.meters(5)):In("meter")).toBe(15)
		expect(function()
			MetricUnit.round(MetricUnit.meters(1), MetricUnit.meters(-5))
		end).toThrow("takes a positive step of length")
		expect(function()
			MetricUnit.round(MetricUnit.meters(1), MetricUnit.seconds(1))
		end).toThrow("takes a positive step of length, not time")
	end)

	it("rounds a temperature on its scale and an instant from its epoch", function()
		local warm = MetricUnit.round(MetricUnit.celsius(21.6), "celsius")
		expect(warm:IsAbsolute()).toBe(true)
		expect(warm:In("celsius")).toBeCloseTo(22, 9)
		local instant = MetricUnit.round(MetricUnit.instant(95), "minute")
		expect(instant:GetKind()).toBe("instant")
		expect(instant:InSeconds()).toBe(120)
	end)

	it("keeps the display preference and errors on an unknown unit", function()
		expect(MetricUnit.round(MetricUnit.kilometers(1.4):ToUSCustomary(), "mile"):GetDisplaySystem()).toBe(
			MetricUnitSystems.US_CUSTOMARY
		)
		expect(function()
			MetricUnit.round(MetricUnit.meters(1), "klicks" :: any)
		end).toThrow('MetricUnit.round knows no unit "klicks"')
	end)
end)

describe("MetricUnit aggregation", function()
	it("sums values of one dimension", function()
		expect(MetricUnit.sum({ MetricUnit.meters(1), MetricUnit.kilometers(1) }):In("meter")).toBe(1001)
		expect(MetricUnit.sum({ 1, 2 }):GetBaseAmount()).toBe(3)
		expect(function()
			MetricUnit.sum({ MetricUnit.celsius(1), MetricUnit.celsius(2) })
		end).toThrow("cannot add two absolute temperatures")
		expect(function()
			MetricUnit.sum({})
		end).toThrow("takes a list of at least one value")
	end)

	it("averages values, absolutes included", function()
		expect(MetricUnit.mean({ MetricUnit.meters(1), MetricUnit.meters(3) }):In("meter")).toBe(2)
		local temperature = MetricUnit.mean({ MetricUnit.celsius(10), MetricUnit.celsius(20) })
		expect(temperature:IsAbsolute()).toBe(true)
		expect(temperature:In("celsius")).toBeCloseTo(15, 9)
		expect(MetricUnit.mean({ MetricUnit.instant(10), MetricUnit.instant(20) }):InSeconds()).toBe(15)
	end)

	it("takes the smallest and largest of a list through min and max", function()
		local list = { MetricUnit.meters(1), MetricUnit.meters(5), MetricUnit.meters(3) }
		expect(MetricUnit.max(table.unpack(list)):In("meter")).toBe(5)
		expect(MetricUnit.min(table.unpack(list)):In("meter")).toBe(1)
	end)
end)

describe("MetricUnit rounding an absolute value by a step", function()
	it("rounds a temperature on the scale it is shown in", function()
		local step = MetricUnit.difference(5, "celsius")
		expect(MetricUnit.round(MetricUnit.celsius(21.6), step):In("celsius")).toBeCloseTo(20, 9)
		expect(MetricUnit.round(MetricUnit.celsius(23), step):In("celsius")).toBeCloseTo(25, 9)
		local fahrenheitStep = MetricUnit.difference(10, "fahrenheit")
		expect(MetricUnit.round(MetricUnit.fahrenheit(68), fahrenheitStep):In("fahrenheit")).toBeCloseTo(70, 9)
	end)

	it("rounds an instant from its epoch", function()
		local rounded = MetricUnit.round(MetricUnit.instant(95), MetricUnit.minutes(1))
		expect(rounded:In("second")).toBeCloseTo(120, 9)
	end)
end)
