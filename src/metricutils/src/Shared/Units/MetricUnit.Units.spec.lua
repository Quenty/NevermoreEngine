--!strict
--[[
	@class MetricUnit.Units.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUnit = require("MetricUnit")
local MetricUnitFormatUtils = require("MetricUnitFormatUtils")
local MetricUnitScale = require("MetricUnitScale")
local MetricUtils = require("MetricUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local format = MetricUnit.format

describe("MetricUnit:In", function()
	it("reads by unit id, by @quenty/time's names for time, and by unit value", function()
		expect(MetricUnit.kilometers(2):In("meter")).toBe(2000)
		expect(MetricUnit.minutes(90):In("hour")).toBe(1.5)
		expect(MetricUnit.minutes(90):In("hours")).toBe(1.5)
		expect(MetricUnit.minutes(90):In("h")).toBe(1.5)
		expect(MetricUnit.minutes(90):In(MetricUnit.hours(1))).toBe(1.5)
		expect(MetricUnit.perDay(48):In("perHour")).toBeCloseTo(2, 9)
		expect(MetricUnit.years(1):In("quarter")).toBeCloseTo(4, 9)
	end)

	it("reads a temperature scale from its zero when absolute", function()
		expect(MetricUnit.celsius(100):In("fahrenheit")).toBeCloseTo(212, 9)
		expect(MetricUnit.celsiusDifference(5):In("fahrenheit")).toBeCloseTo(9, 9)
	end)

	it("errors on an unknown id, and on another dimension naming both", function()
		expect(function()
			MetricUnit.meters(1):In("klicks" :: any)
		end).toThrow('MetricUnit:In knows no unit "klicks"')
		expect(function()
			MetricUnit.meters(1):In("second")
		end).toThrow('In("second") reads time, not length')
		expect(function()
			MetricUnit.seconds(1):InSeconds()
		end).never.toThrow()
	end)
end)

describe("MetricUnit.new", function()
	it("makes a value from an amount and a unit id", function()
		expect(MetricUnit.new(5, "kilometer") == MetricUnit.kilometers(5)).toBe(true)
		expect(MetricUnit.new(90, "minutes") == MetricUnit.hours(1.5)).toBe(true)
		expect(MetricUnit.new(20, "celsius"):IsAbsolute()).toBe(true)
		expect(function()
			MetricUnit.new(1, "klicks" :: any)
		end).toThrow('MetricUnit.new knows no unit "klicks"')
	end)
end)

describe("MetricUnit dimension queries", function()
	it("names what a value measures", function()
		expect(MetricUnit.kilometers(1):GetKind()).toBe("length")
		expect((MetricUnit.kilometers(1) / MetricUnit.hours(1)):GetKind()).toBe("speed")
		expect(MetricUnit.celsius(5):GetKind()).toBe("temperature")
		expect(MetricUnit.celsiusDifference(5):GetKind()).toBe("temperatureDifference")
		expect(MetricUnit.none(1):GetKind()).toBe("none")
		expect(MetricUnit.pow(MetricUnit.meters(1), 4):GetKind()).toBeNil()
	end)

	it("checks kinds by name or exponents, and errors on an unknown name", function()
		local speed = MetricUnit.meters(1) / MetricUnit.seconds(1)
		expect(speed:IsKind("speed")).toBe(true)
		expect(speed:IsKind({ length = 1, time = -1 })).toBe(true)
		expect(MetricUnit.isKind(speed, "length")).toBe(false)
		expect(MetricUnit.isKind(5, "length")).toBe(false)
		expect(function()
			MetricUnit.isKind(speed, "velocity" :: any)
		end).toThrow('no dimension named "velocity"')
	end)

	it("gives the base amount, frozen dimensions and absoluteness", function()
		local length = MetricUnit.kilometers(2)
		expect(length:GetBaseAmount()).toBe(2000)
		expect(length:GetDimensions()).toEqual({ length = 1 })
		expect(table.isfrozen(length:GetDimensions())).toBe(true)
		expect(length:IsAbsolute()).toBe(false)
	end)

	it("lists the unit ids a value can be read in, metric first", function()
		local ids = MetricUnit.meters(1):GetUnitIds()
		expect(ids[1]).toBe("millimeter")
		expect(table.find(ids, "mile")).never.toBeNil()
		expect(table.find(ids, "stud")).never.toBeNil()
		expect(table.find(ids, "kilogram")).toBeNil()
		expect(table.find(MetricUnit.celsius(5):GetUnitIds(), "fahrenheit")).never.toBeNil()
	end)
end)

describe("MetricUnit studs", function()
	it("counts 3.57 studs to the metre, the same as MetricUtils", function()
		expect(MetricUnit.studs(357):In("meter")).toBeCloseTo(100, 9)
		expect(MetricUnit.meters(1):In("stud")).toBeCloseTo(3.57, 9)
		expect(MetricUnit.studs(1234):In("meter")).toBeCloseTo(MetricUtils.studsToMeters(1234), 12)
		expect(MetricUnit.studsPerSecond(100):In("kilometerPerHour")).toBeCloseTo(
			MetricUtils.studsPerSecondToKph(100),
			12
		)
		expect(MetricUnitScale.STUDS_PER_METER).toBe(3.57)
	end)

	it("formats studs only when asked", function()
		expect(format(MetricUnit.studs(357))).toBe("100 m")
		expect(format(MetricUnit.studs(357), { unit = "stud" })).toBe("357 studs")
		expect(format(MetricUnit.studs(1), { unit = "stud" })).toBe("1 stud")
		expect(format(MetricUnit.studsPerSecond(16), { unit = "studPerSecond" })).toBe("16 studs/s")
		expect(format(MetricUnit.studs(357), { system = "imperial" })).toBe("328.084 ft")
	end)
end)

describe("MetricUnit US customary and imperial units", function()
	it("converts with exact definitions", function()
		expect(MetricUnit.inches(1):In("millimeter")).toBeCloseTo(25.4, 9)
		expect(MetricUnit.fuzzyEq(MetricUnit.feet(3), MetricUnit.yards(1))).toBe(true)
		expect(MetricUnit.miles(1):In("foot")).toBeCloseTo(5280, 9)
		expect(MetricUnit.pounds(1):In("kilogram")).toBe(0.45359237)
		expect(MetricUnit.pounds(1):In("ounce")).toBeCloseTo(16, 9)
		expect(MetricUnit.stones(1):In("pound")).toBeCloseTo(14, 9)
		expect(MetricUnit.acres(1):In("squareFoot")).toBeCloseTo(43560, 6)
		expect(MetricUnit.usGallons(1):In("usFluidOunce")).toBeCloseTo(128, 9)
		expect(MetricUnit.imperialGallons(1):In("liter")).toBeCloseTo(4.54609, 9)
		expect(MetricUnit.milesPerHour(60):In("kilometerPerHour")).toBeCloseTo(96.56064, 9)
		expect(MetricUnit.knots(1):In("kilometerPerHour")).toBeCloseTo(1.852, 9)
		expect(MetricUnit.poundsForce(1):In("newton")).toBeCloseTo(4.4482216152605, 12)
		expect(MetricUnit.poundsForcePerSquareInch(1):In("pascal")).toBeCloseTo(6894.757293168, 6)
		expect((MetricUnit.poundsForce(1) / MetricUnit.pow(MetricUnit.inches(1), 2)):In("poundForcePerSquareInch")).toBeCloseTo(
			1,
			12
		)
	end)

	it("never picks a customary unit unless asked", function()
		expect(format(MetricUnit.miles(1))).toBe("1.609 km")
		expect(format(MetricUnit.miles(1), { unit = "mile" })).toBe("1 mi")
		expect(format(MetricUnit.feet(2), { unit = "foot", unitDisplay = "long" })).toBe("2 feet")
		expect(format(MetricUnit.feet(1), { unit = "foot", unitDisplay = "long" })).toBe("1 foot")
	end)

	it("picks customary units with system = imperial", function()
		local imperial: MetricUnit.FormatOptions = { system = "imperial" }
		expect(format(MetricUnit.kilometers(5), imperial)).toBe("3.107 mi")
		expect(format(MetricUnit.meters(1), imperial)).toBe("3.281 ft")
		expect(format(MetricUnit.centimeters(10), imperial)).toBe("3.937 in")
		expect(format(MetricUnit.kilograms(1), imperial)).toBe("2.205 lb")
		expect(format(MetricUnit.kilometersPerHour(100), imperial)).toBe("62.137 mph")
		expect(format(MetricUnit.celsius(100), imperial)).toBe("212 °F")
		expect(format(MetricUnit.celsiusDifference(5), imperial)).toBe("9 °F")
		expect(format(MetricUnit.bars(1), imperial)).toBe("14.504 psi")
		-- Dimensions without a customary ladder stay metric
		expect(format(MetricUnit.joules(1500), imperial)).toBe("1.5 kJ")
		expect(format(MetricUnit.kilometers(5), { system = "imperial", autoUnit = false })).toBe("5,000 m")
	end)
end)

describe("MetricUnitFormatUtils.format input", function()
	it("takes a MetricUnit or its plain data", function()
		expect(MetricUnitFormatUtils.format(MetricUnit.kilometers(1))).toBe("1 km")
		expect(MetricUnitFormatUtils.format(MetricUnit.toData(MetricUnit.kilometers(1)))).toBe("1 km")
		expect(MetricUnitFormatUtils.format({ amount = 278.15, dimensions = { temperature = 1 }, absolute = true })).toBe(
			"5 °C"
		)
		expect(function()
			MetricUnitFormatUtils.format({ hello = true })
		end).toThrow("expected a MetricUnit or MetricUnitData")
	end)

	it("writes bare rates by their per id, and frequencies in hertz", function()
		expect(format(MetricUnit.perHour(3), { unit = "perHour" })).toBe("3/h")
		expect(format(MetricUnit.perHour(3), { unit = "perHour", unitDisplay = "long" })).toBe("3 per hour")
		expect(format(MetricUnit.perHour(3), { perUnit = "h" })).toBe("3/h")
		expect(MetricUnitFormatUtils.formatUnit("perDay", 5)).toBe("5/d")
	end)
end)
