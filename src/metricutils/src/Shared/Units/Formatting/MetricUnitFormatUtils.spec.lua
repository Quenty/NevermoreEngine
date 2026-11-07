--!strict
--[[
	@class MetricUnitFormatUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUnit = require("MetricUnit")
local MetricUnitFormatUtils = require("MetricUnitFormatUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local format = MetricUnit.format

describe("MetricUnitFormatUtils.formatNumber", function()
	it("rounds to three decimals and groups thousands by default", function()
		expect(MetricUnitFormatUtils.formatNumber(1234.5678)).toBe("1,234.568")
		expect(MetricUnitFormatUtils.formatNumber(-1234.5)).toBe("-1,234.5")
		expect(MetricUnitFormatUtils.formatNumber(2)).toBe("2")
		expect(MetricUnitFormatUtils.formatNumber(-0.0004)).toBe("0")
	end)

	it("uses the locale's grouping and decimal mark", function()
		expect(MetricUnitFormatUtils.formatNumber(1234.5, { locale = "de-de" })).toBe("1 234,5")
		expect(MetricUnitFormatUtils.formatNumber(1234.5, { locale = "es-es" })).toBe("1.234,5")
		expect(MetricUnitFormatUtils.formatNumber(1234.5, { locale = "en-gb" })).toBe("1,234.5")
	end)

	it("takes Intl-style digit options", function()
		expect(MetricUnitFormatUtils.formatNumber(2, { minimumFractionDigits = 2 })).toBe("2.00")
		expect(MetricUnitFormatUtils.formatNumber(2.345, { maximumFractionDigits = 1 })).toBe("2.3")
		expect(MetricUnitFormatUtils.formatNumber(2.35, { maximumFractionDigits = 0 })).toBe("2")
		expect(MetricUnitFormatUtils.formatNumber(123456, { maximumSignificantDigits = 2 })).toBe("120,000")
		expect(MetricUnitFormatUtils.formatNumber(0.012345, { maximumSignificantDigits = 2 })).toBe("0.012")
		expect(MetricUnitFormatUtils.formatNumber(1234.5, { useGrouping = false })).toBe("1234.5")
	end)
end)

describe("MetricUnitFormatUtils.format units", function()
	it("picks the unit that suits the size, or the one given", function()
		local length = MetricUnit.meters(2500)
		expect(format(length)).toBe("2.5 km")
		expect(format(length, { unit = "meter" })).toBe("2,500 m")
		expect(format(length, { autoUnit = false })).toBe("2,500 m")
		expect(format(length, { maximumSignificantDigits = 1 })).toBe("3 km")
		expect(format(MetricUnit.meters(0))).toBe("0 m")
	end)

	it("writes long names, pluralized, in American or Commonwealth spelling", function()
		expect(format(MetricUnit.meters(2500), { unitDisplay = "long" })).toBe("2.5 kilometers")
		expect(format(MetricUnit.kilometers(1), { unitDisplay = "long" })).toBe("1 kilometer")
		expect(format(MetricUnit.kilometers(1), { unitDisplay = "long", minimumFractionDigits = 1 })).toBe(
			"1.0 kilometers"
		)
		expect(format(MetricUnit.meters(2500), { unitDisplay = "long", locale = "en-gb" })).toBe("2.5 kilometres")
		expect(format(MetricUnit.liters(2), { unitDisplay = "long", locale = "en-au" })).toBe("2 litres")
		expect(format(MetricUnit.tonnes(2), { unitDisplay = "long" })).toBe("2 metric tons")
		expect(format(MetricUnit.tonnes(2), { unitDisplay = "long", locale = "en-gb" })).toBe("2 tonnes")
	end)

	it("writes SI symbols with the locale's numbers in any locale", function()
		expect(format(MetricUnit.meters(1234.5), { unit = "meter", locale = "de-de" })).toBe("1 234,5 m")
		expect(format(MetricUnit.kilograms(2.5), { locale = "fr-fr" })).toBe("2,5 kg")
	end)

	it("writes derived units", function()
		expect(format(MetricUnit.newtons(1500))).toBe("1.5 kN")
		expect(format(MetricUnit.newtons(1500), { unitDisplay = "long" })).toBe("1.5 kilonewtons")
		expect(format(MetricUnit.watts(2500), { unitDisplay = "long" })).toBe("2.5 kilowatts")
		expect(format(MetricUnit.kilowattHours(3), { unit = "kilowattHour" })).toBe("3 kWh")
		expect(format(MetricUnit.squareMeters(25000), { unit = "hectare" })).toBe("2.5 ha")
		expect(format(MetricUnit.liters(0.25))).toBe("250 mL")
		expect(format(MetricUnit.kibibytes(4096), { unit = "mebibyte" })).toBe("4 MiB")
		expect(format(MetricUnit.metersPerSecondSquared(9.81), { unitDisplay = "long" })).toBe(
			"9.81 meters per second squared"
		)
	end)

	it("takes phrase overrides", function()
		local length = MetricUnit.meters(2500)
		expect(format(length, { strings = { kilometer = { short = { one = "%s klick", other = "%s klicks" } } } })).toBe(
			"2.5 klicks"
		)
		expect(format(length, {
			strings = {
				kilometer = {
					short = function(_amount: number, numberText: string): string
						return numberText .. "!"
					end,
				},
			},
		})).toBe("2.5!")
	end)

	it("errors when the unit given is of another dimension", function()
		expect(function()
			format(MetricUnit.meters(1), { unit = "kilogram" })
		end).toThrow("kilogram is mass, not length")
	end)

	it("writes dimensionless values and unnamed compounds", function()
		expect(format(MetricUnit.none(0.25))).toBe("0.25")
		expect(format(MetricUnit.kilograms(2) * MetricUnit.metersPerSecond(3))).toBe("6 m·kg/s")
		expect(format(MetricUnit.kilograms(2) / MetricUnit.kilometers(1))).toBe("0.002 kg/m")
	end)
end)

describe("MetricUnitFormatUtils.format rates", function()
	it("writes the numerator on its ladder, per the shortest time unit it fills", function()
		expect(format(MetricUnit.metersPerSecond(5))).toBe("5 m/s")
		expect(format(MetricUnit.metersPerSecond(5), { unitDisplay = "long" })).toBe("5 meters per second")
		expect(format(MetricUnit.kilobytesPerSecond(1600))).toBe("1.6 MB/s")
		expect(format(MetricUnit.kilobytesPerSecond(1600), { unitDisplay = "long" })).toBe("1.6 megabytes per second")
		expect(format(MetricUnit.perDay(5))).toBe("5/d")
		expect(format(MetricUnit.perDay(5), { unitDisplay = "long" })).toBe("5 per day")
	end)

	it("takes a whole rate unit, a numerator unit or a per unit", function()
		expect(format(MetricUnit.kilometersPerHour(18), { unit = "kilometerPerHour" })).toBe("18 km/h")
		expect(format(MetricUnit.kilometersPerHour(18), { unit = "kilometerPerHour", unitDisplay = "long" })).toBe(
			"18 kilometers per hour"
		)
		expect(format(MetricUnit.kilobytesPerSecond(1600), { unit = "kilobyte" })).toBe("1,600 kB/s")
		expect(format(MetricUnit.kilobytesPerSecond(1600), { perUnit = "minute" })).toBe("96 MB/min")
		expect(format(MetricUnit.kilometersPerHour(18), { unit = "kilometer", perUnit = "hour" })).toBe("18 km/h")
		expect(format(MetricUnit.hertz(60), { unit = "hertz" })).toBe("60 Hz")
	end)

	it("takes per phrase overrides", function()
		expect(format(MetricUnit.perHour(3), { perStrings = { hour = { short = "%s an hour" } } })).toBe("3 an hour")
	end)
end)

describe("MetricUnitFormatUtils.format temperatures", function()
	it("writes an absolute temperature on a scale, °C by default", function()
		expect(format(MetricUnit.celsius(21.5))).toBe("21.5 °C")
		expect(format(MetricUnit.celsius(100), { unit = "fahrenheit" })).toBe("212 °F")
		expect(format(MetricUnit.celsius(0), { unit = "kelvin" })).toBe("273.15 K")
		expect(format(MetricUnit.celsius(1), { unitDisplay = "long" })).toBe("1 degree Celsius")
		expect(format(MetricUnit.celsius(20), { unitDisplay = "long" })).toBe("20 degrees Celsius")
	end)

	it("writes a difference without an offset, K by default", function()
		expect(format(MetricUnit.celsiusDifference(3))).toBe("3 K")
		expect(format(MetricUnit.celsiusDifference(3), { unit = "celsius" })).toBe("3 °C")
		expect(format(MetricUnit.celsiusDifference(5), { unit = "fahrenheit" })).toBe("9 °F")
		expect(format(MetricUnit.celsius(25) - MetricUnit.celsius(20), { unitDisplay = "long" })).toBe("5 kelvins")
	end)

	it("errors when the unit given is not a temperature", function()
		expect(function()
			format(MetricUnit.celsius(5), { unit = "meter" })
		end).toThrow("meter is not a temperature unit")
	end)
end)

describe("MetricUnitFormatUtils.formatUnit", function()
	it("writes an amount already in the unit", function()
		expect(MetricUnitFormatUtils.formatUnit("kilometerPerHour", 90)).toBe("90 km/h")
		expect(MetricUnitFormatUtils.formatUnit("liter", 1, { unitDisplay = "long" })).toBe("1 liter")
		expect(MetricUnitFormatUtils.formatUnit("celsius", 20)).toBe("20 °C")
		expect(MetricUnitFormatUtils.formatUnit("hour", 1.5)).toBe("1.5 hours")
		expect(MetricUnitFormatUtils.formatUnit("day", 1.5, { locale = "es-es" })).toBe("1,5 días")
	end)
end)
