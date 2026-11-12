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

-- Formatting puts a no-break space between a number and its unit; these compare it as a plain space
local function plain(text: string): string
	return (string.gsub(text, "\u{00A0}", " "))
end

local function formatUnit(unit: any, amount: number, options: any?): string
	return plain(MetricUnitFormatUtils.formatUnit(unit, amount, options))
end

local function formatData(value: any, options: any?): string
	return plain(MetricUnitFormatUtils.format(value, options))
end

local function format(value: any, options: MetricUnit.FormatOptions?): string
	return plain(MetricUnit.format(value, options))
end

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
		expect(format(MetricUnit.new(2, "liter"), { unitDisplay = "long", locale = "en-au" })).toBe("2 litres")
		expect(format(MetricUnit.tonnes(2), { unitDisplay = "long" })).toBe("2 metric tons")
		expect(format(MetricUnit.tonnes(2), { unitDisplay = "long", locale = "en-gb" })).toBe("2 tonnes")
	end)

	it("writes SI symbols with the locale's numbers in any locale", function()
		expect(format(MetricUnit.meters(1234.5), { unit = "meter", locale = "de-de" })).toBe("1 234,5 m")
		expect(format(MetricUnit.kilograms(2.5), { locale = "fr-fr" })).toBe("2,5 kg")
	end)

	it("writes derived units", function()
		expect(format(MetricUnit.new(1500, "newton"))).toBe("1.5 kN")
		expect(format(MetricUnit.new(1500, "newton"), { unitDisplay = "long" })).toBe("1.5 kilonewtons")
		expect(format(MetricUnit.new(2500, "watt"), { unitDisplay = "long" })).toBe("2.5 kilowatts")
		expect(format(MetricUnit.new(3, "kilowattHour"), { unit = "kilowattHour" })).toBe("3 kWh")
		expect(format(MetricUnit.new(25000, "squareMeter"), { unit = "hectare" })).toBe("2.5 ha")
		expect(format(MetricUnit.new(0.25, "liter"))).toBe("250 mL")
		expect(format(MetricUnit.new(4096, "kibibyte"), { unit = "mebibyte" })).toBe("4 MiB")
		expect(format(MetricUnit.new(9.81, "meterPerSecondSquared"), { unitDisplay = "long" })).toBe(
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
		expect(format(MetricUnit.kilograms(2) * MetricUnit.new(3, "meterPerSecond"))).toBe("6 m·kg/s")
		expect(format(MetricUnit.kilograms(2) / MetricUnit.kilometers(1))).toBe("0.002 kg/m")
	end)
end)

describe("MetricUnitFormatUtils.format rates", function()
	it("writes the numerator in its own display unit, per the shortest time unit it fills", function()
		expect(format(MetricUnit.new(5, "meterPerSecond"))).toBe("5 m/s")
		expect(format(MetricUnit.new(5, "meterPerSecond"), { unitDisplay = "long" })).toBe("5 meters per second")
		expect(format(MetricUnit.new(1600, "kilobytePerSecond"))).toBe("1.6 MB/s")
		expect(format(MetricUnit.new(1600, "kilobytePerSecond"), { unitDisplay = "long" })).toBe(
			"1.6 megabytes per second"
		)
		expect(format(MetricUnit.perDay(5))).toBe("5/d")
		expect(format(MetricUnit.perDay(5), { unitDisplay = "long" })).toBe("5 per day")
	end)

	it("takes a whole rate unit, a numerator unit or a per unit", function()
		expect(format(MetricUnit.new(18, "kilometerPerHour"), { unit = "kilometerPerHour" })).toBe("18 km/h")
		expect(format(MetricUnit.new(18, "kilometerPerHour"), { unit = "kilometerPerHour", unitDisplay = "long" })).toBe(
			"18 kilometers per hour"
		)
		expect(format(MetricUnit.new(1600, "kilobytePerSecond"), { unit = "kilobyte" })).toBe("1,600 kB/s")
		expect(format(MetricUnit.new(1600, "kilobytePerSecond"), { perUnit = "minute" })).toBe("96 MB/min")
		expect(format(MetricUnit.new(18, "kilometerPerHour"), { unit = "kilometer", perUnit = "hour" })).toBe("18 km/h")
		expect(format(MetricUnit.new(60, "hertz"), { unit = "hertz" })).toBe("60 Hz")
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
		expect(format(MetricUnit.difference(3, "celsius"))).toBe("3 K")
		expect(format(MetricUnit.difference(3, "celsius"), { unit = "celsius" })).toBe("3 °C")
		expect(format(MetricUnit.difference(5, "celsius"), { unit = "fahrenheit" })).toBe("9 °F")
		expect(format(MetricUnit.celsius(25) - MetricUnit.celsius(20), { unitDisplay = "long" })).toBe("5 kelvins")
	end)

	it("errors when the unit given is not a temperature", function()
		expect(function()
			format(MetricUnit.celsius(5), { unit = "meter" })
		end).toThrow("meter is length, not temperature")
	end)
end)

describe("MetricUnitFormatUtils.formatUnit", function()
	it("writes an amount already in the unit", function()
		expect(formatUnit("kilometerPerHour", 90)).toBe("90 km/h")
		expect(formatUnit("liter", 1, { unitDisplay = "long" })).toBe("1 liter")
		expect(formatUnit("celsius", 20)).toBe("20 °C")
		expect(formatUnit("hour", 1.5)).toBe("1.5 hours")
		expect(formatUnit("day", 1.5, { locale = "es-es" })).toBe("1,5 días")
	end)
end)

describe("MetricUnitFormatUtils.format with a translator", function()
	local function fakeTranslator(locale: string, entries: { [string]: string }): any
		return {
			GetLocaleId = function()
				return locale
			end,
			FormatByKey = function(_self: any, key: string, args: { [string]: any }?): string
				local text = entries[key]
				if not text then
					error("No key " .. key)
				end
				return (string.gsub(text, "{n}", function()
					return (args :: any).n
				end))
			end,
			ObserveFormatByKey = function()
				error("unused")
			end,
		}
	end

	local spanish = fakeTranslator("es-es", {
		["units.mile.long.one"] = "{n} milla",
		["units.mile.long.other"] = "{n} millas",
		["units.mile.short.other"] = "{n} mi",
		["units.kilometer.long.other"] = "{n} kilómetros",
		["per.hour.long"] = "{n} por hora",
	})

	it("writes long names in the translator's language, with its plural rules and numbers", function()
		expect(format(MetricUnit.new(3, "mile"):ToUSCustomary(), { unitDisplay = "long", translator = spanish })).toBe(
			"3 millas"
		)
		expect(format(MetricUnit.new(1, "mile"):ToUSCustomary(), { unitDisplay = "long", translator = spanish })).toBe(
			"1 milla"
		)
		expect(format(MetricUnit.new(1.5, "mile"):ToUSCustomary(), { unitDisplay = "long", translator = spanish })).toBe(
			"1,5 millas"
		)
		expect(format(MetricUnit.new(5, "kilometerPerHour"), {
			unitDisplay = "long",
			unit = "kilometer",
			perUnit = "hour",
			translator = spanish,
		})).toBe("5 kilómetros por hora")
	end)

	it("keeps symbols for short display, and English when a key is missing", function()
		expect(format(MetricUnit.new(3, "mile"):ToUSCustomary(), { translator = spanish })).toBe("3 mi")
		expect(format(MetricUnit.kilograms(3), { unitDisplay = "long", translator = spanish })).toBe("3 kilograms")
		local broken = fakeTranslator("es-es", {})
		expect(format(MetricUnit.new(3, "mile"):ToUSCustomary(), { unitDisplay = "long", translator = broken })).toBe(
			"3 miles"
		)
	end)
end)

describe("MetricUnitFormatUtils.format input", function()
	it("takes a MetricUnit or its plain data", function()
		expect(formatData(MetricUnit.kilometers(1))).toBe("1 km")
		expect(formatData(MetricUnit.toData(MetricUnit.kilometers(1)))).toBe("1 km")
		expect(formatData({ amount = 278.15, dimensions = { temperature = 1 }, absolute = true })).toBe("5 °C")
		expect(function()
			formatData({ hello = true })
		end).toThrow("expected a MetricUnit or MetricUnitData")
	end)

	it("writes bare rates by their per id, and frequencies in hertz", function()
		expect(format(MetricUnit.perHour(3), { unit = "perHour" })).toBe("3/h")
		expect(format(MetricUnit.perHour(3), { unit = "perHour", unitDisplay = "long" })).toBe("3 per hour")
		expect(format(MetricUnit.perHour(3), { perUnit = "h" })).toBe("3/h")
		expect(formatUnit("perDay", 5)).toBe("5/d")
	end)
end)

describe("MetricUnitFormatUtils.format rates written as asked", function()
	it("writes a rate in the numerator unit asked for, whatever the value's system shows", function()
		expect(format(MetricUnit.new(60, "milePerHour"), { unit = "kilometer" })).toBe("0.027 km/s")
		expect(format(MetricUnit.new(60, "milePerHour"), { unit = "kilometer", perUnit = "hour" })).toBe("96.561 km/h")
		expect(format(MetricUnit.new(10, "studPerSecond"), { unit = "meter" })).toBe("2.8 m/s")
	end)

	it("writes a rate per the time unit asked for, whatever the value's system shows", function()
		expect(format(MetricUnit.new(60, "milePerHour"), { perUnit = "second" })).toBe("88 ft/s")
		expect(format(MetricUnit.new(60, "milePerHour"), { unit = "meter", perUnit = "second" })).toBe("26.822 m/s")
	end)
end)

describe("MetricUnitFormatUtils plural forms by locale", function()
	it("picks duration words by the locale's plural rule", function()
		expect(format(MetricUnit.hours(1.5), { locale = "fr-fr", unit = "hour" })).toBe("1,5 heure")
		expect(format(MetricUnit.hours(1.5), { locale = "en-us", unit = "hour" })).toBe("1.5 hours")
	end)
end)
