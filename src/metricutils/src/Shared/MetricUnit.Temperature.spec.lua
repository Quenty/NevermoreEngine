--!strict
--[[
	@class MetricUnit.Temperature.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUnit = require("MetricUnit")

local DAY = MetricUnit.days(1):InSeconds()
local YEAR = MetricUnit.years(1):InSeconds()

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function format(value: any): string
	return (string.gsub(MetricUnit.format(value), "\u{00A0}", " "))
end

describe("MetricUnit absolute temperatures", function()
	it("reads each scale back from its own zero", function()
		expect(MetricUnit.celsius(5):In("celsius")).toBeCloseTo(5, 9)
		expect(MetricUnit.celsius(5):In("kelvin")).toBeCloseTo(278.15, 9)
		expect(MetricUnit.kelvin(0):In("celsius")).toBeCloseTo(-273.15, 9)
		expect(MetricUnit.fahrenheit(212):In("celsius")).toBeCloseTo(100, 9)
		expect(MetricUnit.celsius(-40):In("fahrenheit")).toBeCloseTo(-40, 9)
		expect(MetricUnit.fahrenheit(32):In("fahrenheit")).toBeCloseTo(32, 9)
		expect(MetricUnit.isKind(MetricUnit.kelvin(300), "temperature")).toBe(true)
		expect((MetricUnit.celsius(5)):IsAbsolute()).toBe(true)
	end)

	it("subtracts two absolutes to a difference", function()
		local difference = MetricUnit.celsius(5) - MetricUnit.celsius(2)
		expect(MetricUnit.isKind(difference, "temperatureDifference")).toBe(true)
		expect((difference):IsAbsolute()).toBe(false)
		expect(difference:In("kelvin")).toBeCloseTo(3, 9)
		expect(difference:In("celsius")).toBeCloseTo(3, 9)
		expect(difference:In("fahrenheit")).toBeCloseTo(5.4, 9)
	end)

	it("adds a difference to an absolute, on either side, to an absolute", function()
		local swing = MetricUnit.difference(12, "celsius")
		expect((MetricUnit.celsius(15) + swing):In("celsius")).toBeCloseTo(27, 9)
		expect((swing + MetricUnit.celsius(15)):In("celsius")).toBeCloseTo(27, 9)
		expect((MetricUnit.celsius(15) - swing):In("celsius")).toBeCloseTo(3, 9)
		expect(MetricUnit.isKind(MetricUnit.celsius(15) - swing, "temperature")).toBe(true)
		expect((MetricUnit.celsius(15) + 0):In("celsius")).toBeCloseTo(15, 9)
	end)

	it("errors adding two absolutes", function()
		expect(function()
			local _ = MetricUnit.celsius(5) + MetricUnit.celsius(2)
		end).toThrow(
			"cannot add two absolute temperatures; subtract them for a difference, or add a difference to one"
		)
	end)

	it("errors subtracting an absolute from a difference", function()
		expect(function()
			local _ = MetricUnit.difference(5, "celsius") - MetricUnit.celsius(2)
		end).toThrow("cannot subtract an absolute temperature from a temperature difference")
		expect(function()
			local _ = 0 - MetricUnit.celsius(2)
		end).toThrow("cannot subtract an absolute temperature from a temperature difference")
	end)

	it("errors scaling, negating or taking powers of an absolute, kelvin included", function()
		expect(function()
			local _ = MetricUnit.celsius(5) * 2
		end).toThrow("cannot multiply an absolute temperature")
		expect(function()
			local _ = 2 * MetricUnit.kelvin(300)
		end).toThrow("cannot multiply an absolute temperature")
		expect(function()
			local _ = MetricUnit.kelvin(300) / MetricUnit.seconds(1)
		end).toThrow("cannot divide an absolute temperature")
		expect(function()
			local _ = -MetricUnit.celsius(5)
		end).toThrow("cannot negate an absolute temperature")
		expect(function()
			MetricUnit.abs(MetricUnit.celsius(5))
		end).toThrow("cannot take the size of an absolute temperature")
		expect(function()
			MetricUnit.pow(MetricUnit.celsius(5), 2)
		end).toThrow("cannot exponentiate an absolute temperature")
	end)

	it("errors reading an absolute with In or a non-temperature reader", function()
		expect(function()
			MetricUnit.celsius(5):In(MetricUnit.difference(1, "kelvin"))
		end).toThrow("cannot take the ratio of an absolute temperature")
		expect(function()
			MetricUnit.celsius(5):In("day")
		end).toThrow('In("day") reads time, not absolute temperature')
		expect(function()
			MetricUnit.kilometers(5):In("celsius")
		end).toThrow('In("celsius") reads temperature, not length')
	end)
end)

describe("MetricUnit temperature differences", function()
	it("makes differences on each scale", function()
		expect(MetricUnit.difference(3, "kelvin"):In("kelvin")).toBe(3)
		expect(MetricUnit.difference(3, "celsius"):In("kelvin")).toBe(3)
		expect(MetricUnit.difference(9, "fahrenheit"):In("celsius")).toBeCloseTo(5, 9)
		expect(MetricUnit.isKind(MetricUnit.difference(1, "celsius"), "temperatureDifference")).toBe(true)
		expect(MetricUnit.isKind(MetricUnit.difference(1, "celsius"), "temperature")).toBe(false)
	end)

	it("scales, negates and divides freely", function()
		local swing = MetricUnit.difference(12, "celsius")
		expect((swing * 0.5):In("celsius")).toBeCloseTo(6, 9)
		expect((-swing):In("celsius")).toBeCloseTo(-12, 9)
		expect((swing / MetricUnit.years(1)):In(MetricUnit.difference(1, "kelvin") / MetricUnit.days(1))).toBeCloseTo(
			12 * DAY / YEAR,
			12
		)
	end)
end)

describe("MetricUnit temperature comparisons", function()
	it("compares two absolutes or two differences", function()
		expect(MetricUnit.celsius(5) < MetricUnit.celsius(6)).toBe(true)
		expect(MetricUnit.celsius(5) == MetricUnit.kelvin(278.15)).toBe(true)
		expect(MetricUnit.fuzzyEq(MetricUnit.fahrenheit(32), MetricUnit.celsius(0))).toBe(true)
		expect(MetricUnit.difference(1, "celsius") <= MetricUnit.difference(2, "fahrenheit")).toBe(true)
		expect(MetricUnit.max(MetricUnit.celsius(5), MetricUnit.celsius(9)):In("celsius")).toBeCloseTo(9, 9)
		expect(MetricUnit.isKind(MetricUnit.max(MetricUnit.celsius(5), MetricUnit.celsius(9)), "temperature")).toBe(
			true
		)
	end)

	it("errors comparing an absolute with a difference", function()
		expect(function()
			local _ = MetricUnit.celsius(5) < MetricUnit.difference(6, "celsius")
		end).toThrow("cannot compare an absolute temperature and a temperature difference")
		expect(function()
			local _ = MetricUnit.celsius(5) == MetricUnit.difference(5, "kelvin")
		end).toThrow("cannot compare an absolute temperature and a temperature difference")
		expect(function()
			MetricUnit.max(MetricUnit.celsius(5), 0)
		end).toThrow("cannot compare absolute temperature and the plain number 0")
	end)
end)

describe("MetricUnit temperature boundaries and data", function()
	it("expects an absolute temperature or a difference by name", function()
		expect(MetricUnit.expect(MetricUnit.celsius(5), "temperature", "air")).toBeCloseTo(278.15, 9)
		expect(MetricUnit.expect(MetricUnit.difference(12, "celsius"), "temperatureDifference", "swing")).toBe(12)
		expect(MetricUnit.expect(0, "temperatureDifference", "swing")).toBe(0)
		expect(function()
			MetricUnit.expect(MetricUnit.difference(12, "celsius"), "temperature", "air")
		end).toThrow("MetricUnit.expect: air expects absolute temperature, got temperature difference")
		expect(function()
			MetricUnit.expect(MetricUnit.celsius(12), "temperatureDifference", "swing")
		end).toThrow("MetricUnit.expect: swing expects temperature difference, got absolute temperature")
		expect(function()
			MetricUnit.expect(0, "temperature", "air")
		end).toThrow("MetricUnit.expect: air expects absolute temperature, got the plain number 0")
	end)

	it("round trips an absolute through plain data", function()
		local data = MetricUnit.toData(MetricUnit.kelvin(300))
		expect(data).toEqual({ amount = 300, dimensions = { temperature = 1 }, absolute = true })
		local back = MetricUnit.fromData(data)
		expect(MetricUnit.isKind(back, "temperature")).toBe(true)
		expect(back:In("kelvin")).toBe(300)
		expect(MetricUnit.toData(MetricUnit.difference(3, "kelvin"))).toEqual({
			amount = 3,
			dimensions = { temperature = 1 },
		})
	end)
end)

describe("MetricUnit.point and MetricUnit.difference", function()
	it("makes a point from a unit's zero, in any unit", function()
		expect(MetricUnit.point(20, "celsius") == MetricUnit.celsius(20)).toBe(true)
		expect(MetricUnit.point(90, "second") == MetricUnit.instant(90)).toBe(true)
		expect(MetricUnit.point(1.5, "minute"):In("second")).toBe(90)
		expect(MetricUnit.point(5, "meter"):IsAbsolute()).toBe(true)
	end)

	it("makes a difference, in any unit", function()
		expect(MetricUnit.difference(9, "fahrenheit"):In("kelvin")).toBeCloseTo(5, 9)
		expect(MetricUnit.difference(12, "celsius"):IsAbsolute()).toBe(false)
		expect(MetricUnit.difference(5, "meter") == MetricUnit.meters(5)).toBe(true)
	end)

	it("follows the point rules for every dimension", function()
		local gap = MetricUnit.point(7, "meter") - MetricUnit.point(2, "meter")
		expect(gap == MetricUnit.meters(5)).toBe(true)
		expect(function()
			local _ = MetricUnit.point(7, "meter") + MetricUnit.point(2, "meter")
		end).toThrow()
	end)

	it("formats a point on the scale people read and a difference in kelvin", function()
		expect(format(MetricUnit.point(20, "celsius"))).toBe("20 °C")
		expect(format(MetricUnit.difference(20, "celsius"))).toBe("20 K")
	end)

	it("errors on an unknown unit or a non-number", function()
		expect(function()
			MetricUnit.point(1, "klicks" :: any)
		end).toThrow('MetricUnit.point knows no unit "klicks"')
		expect(function()
			MetricUnit.difference("1" :: any, "meter")
		end).toThrow("MetricUnit.difference takes a number")
	end)
end)
