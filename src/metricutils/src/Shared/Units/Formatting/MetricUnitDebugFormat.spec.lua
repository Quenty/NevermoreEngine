--!strict
--[[
	@class MetricUnitDebugFormat.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUnit = require("MetricUnit")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("MetricUnit tostring", function()
	it("writes a single dimension in the largest unit it fills, by SI symbol", function()
		expect(tostring(MetricUnit.days(3.5))).toBe("3.5 d")
		expect(tostring(MetricUnit.years(2))).toBe("2 yr")
		expect(tostring(MetricUnit.minutes(90))).toBe("1.5 h")
		expect(tostring(MetricUnit.seconds(30))).toBe("30 s")
		expect(tostring(MetricUnit.kilometers(2))).toBe("2 km")
		expect(tostring(MetricUnit.meters(500))).toBe("500 m")
		expect(tostring(MetricUnit.millimeters(4))).toBe("4 mm")
		expect(tostring(MetricUnit.kilobytes(1_600))).toBe("1.6 MB")
		expect(tostring(MetricUnit.bytes(12))).toBe("12 B")
		expect(tostring(MetricUnit.tonnes(3))).toBe("3 t")
		expect(tostring(MetricUnit.grams(20))).toBe("20 g")
	end)

	it("writes zero in the base unit", function()
		expect(tostring(MetricUnit.kilometers(0))).toBe("0 m")
		expect(tostring(MetricUnit.days(0))).toBe("0 s")
	end)

	it("writes a rate per the shortest time unit it fills at least once", function()
		expect(tostring(MetricUnit.perYear(0.03))).toBe("0.03/yr")
		expect(tostring(MetricUnit.perDay(5))).toBe("5/d")
		expect(tostring(MetricUnit.perSecond(2))).toBe("2/s")
		expect(tostring(MetricUnit.hertz(60))).toBe("60/s")
	end)

	it("writes the numerator of a rate on its own ladder", function()
		expect(tostring(MetricUnit.kilometers(18) / MetricUnit.hours(1))).toBe("5 m/s")
		expect(tostring(MetricUnit.kilometers(20) / MetricUnit.years(1))).toBe("2.282 m/h")
		expect(tostring(MetricUnit.kilobytesPerSecond(1_600))).toBe("1.6 MB/s")
		expect(tostring(MetricUnit.bytes(20) / MetricUnit.days(1))).toBe("20 B/d")
	end)

	it("writes small times in ms and µs", function()
		expect(tostring(MetricUnit.milliseconds(250))).toBe("250 ms")
		expect(tostring(MetricUnit.microseconds(40))).toBe("40 µs")
	end)

	it("writes derived dimensions in their named units", function()
		expect(tostring(MetricUnit.kilometers(3) * MetricUnit.kilometers(2))).toBe("6 km²")
		expect(tostring(MetricUnit.squareMeters(50))).toBe("50 m²")
		expect(tostring(MetricUnit.liters(2.5))).toBe("2.5 L")
		expect(tostring(MetricUnit.cubicMeters(3))).toBe("3 m³")
		expect(tostring(MetricUnit.metersPerSecondSquared(9.81))).toBe("9.81 m/s²")
		expect(tostring(MetricUnit.newtons(1_500))).toBe("1.5 kN")
		expect(tostring(MetricUnit.kilowattHours(1))).toBe("3.6 MJ")
		expect(tostring(MetricUnit.watts(2_500))).toBe("2.5 kW")
		expect(tostring(MetricUnit.bars(1))).toBe("100 kPa")
		expect(tostring(MetricUnit.kilogramsPerCubicMeter(1_000))).toBe("1000 kg/m³")
		expect(tostring(MetricUnit.gigabytes(2))).toBe("2 GB")
		expect(tostring(MetricUnit.milligrams(5))).toBe("5 mg")
	end)

	it("writes other compounds in base units", function()
		expect(tostring(MetricUnit.kilograms(2) / MetricUnit.kilometers(1))).toBe("0.002 kg/m")
		expect(tostring(MetricUnit.kilograms(2) * MetricUnit.metersPerSecond(3))).toBe("6 m·kg/s")
	end)

	it("writes dimensionless values, large values and temperatures", function()
		expect(tostring(MetricUnit.none(0.25))).toBe("0.25")
		expect(tostring(MetricUnit.years(10_000))).toBe("10000 yr")
		expect(tostring(MetricUnit.celsius(5))).toBe("5 °C")
		expect(tostring(MetricUnit.celsius(5) - MetricUnit.celsius(2))).toBe("3 K")
	end)
end)
