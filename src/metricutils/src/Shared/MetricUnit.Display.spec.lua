--!strict
--[[
	@class MetricUnit.Display.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUnit = require("MetricUnit")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function preferenceOf(value: MetricUnit.MetricUnit): string?
	local system = value:GetDisplaySystem()
	local unit = value:GetDisplayUnit()
	return if unit then unit.id elseif system then system:GetName() else nil
end

-- Formatting puts a no-break space between a number and its unit; these compare it as a plain space
local function plain(text: string): string
	return (string.gsub(text, "\u{00A0}", " "))
end

local function format(value: any, options: MetricUnit.FormatOptions?): string
	return plain(MetricUnit.format(value, options))
end

local function mismatches(cases: { { any } }): { string }
	local found = {}
	for _, case in cases do
		local text = string.gsub(tostring(case[1]), "\u{00A0}", " ")
		if text ~= case[2] then
			table.insert(found, string.format("expected %q, got %q", case[2], text))
		end
	end
	return found
end

describe("MetricUnit display preference", function()
	it("prefers imperial units or a pinned unit only when asked", function()
		local distance = MetricUnit.kilometers(5)
		expect(format(distance)).toBe("5 km")
		expect(format(distance:ToUSCustomary())).toBe("3.107 mi")
		expect(format(distance:As("mile"))).toBe("3.107 mi")
		expect(format(distance:As("meter"))).toBe("5,000 m")
		expect(format(MetricUnit.meters(28):As("stud"))).toBe("100 studs")
		expect(format(distance:ToUSCustomary():ToMetric())).toBe("5 km")
		expect(preferenceOf(distance:ToUSCustomary())).toBe("usCustomary")
		expect(preferenceOf(distance)).toBeNil()
	end)

	it("never takes a measurement system from the locale", function()
		local distance = MetricUnit.kilometers(5)
		expect(format(distance, { locale = "en-us" })).toBe("5 km")
		expect(format(distance, { locale = "en-us", unitDisplay = "long" })).toBe("5 kilometers")
		expect(format(MetricUnit.celsius(20), { locale = "en-us" })).toBe("20 °C")
	end)

	it("lets an explicit unit option win over the preference", function()
		expect(format(MetricUnit.kilometers(5):ToUSCustomary(), { unit = "meter" })).toBe("5,000 m")
	end)

	it("errors pinning a unit of another dimension", function()
		expect(function()
			MetricUnit.kilometers(5):As("kilogram")
		end).toThrow('MetricUnit:As("kilogram") is mass, not length')
	end)

	it("never changes the amount, comparison, reading or saved data", function()
		local distance = MetricUnit.kilometers(5)
		local imperial = distance:ToUSCustomary()
		expect(imperial == distance).toBe(true)
		expect(imperial:In("kilometer")).toBe(5)
		expect(MetricUnit.expect(imperial, "length", "reach")).toBe(5000)
		expect(MetricUnit.toData(imperial)).toEqual({ amount = 5000, dimensions = { length = 1 } })
		expect(preferenceOf(MetricUnit.fromData(MetricUnit.toData(imperial)))).toBeNil()
	end)

	it("carries through arithmetic of one dimension when the sides agree", function()
		local imperial = MetricUnit.kilometers(5):ToUSCustomary()
		expect(preferenceOf((imperial + MetricUnit.kilometers(1)))).toBe("usCustomary")
		expect(preferenceOf((MetricUnit.kilometers(1) + imperial))).toBe("usCustomary")
		expect(preferenceOf((imperial + MetricUnit.kilometers(1):ToMetric()))).toBeNil()
		expect(preferenceOf(MetricUnit.max(imperial, MetricUnit.kilometers(1)))).toBe("usCustomary")
		expect(preferenceOf(MetricUnit.sum({ imperial, MetricUnit.kilometers(1) }))).toBe("usCustomary")
		expect(preferenceOf(-imperial)).toBe("usCustomary")
	end)

	it("keeps a pinned unit through scaling, and its system through a change of dimension", function()
		local pinned = MetricUnit.kilometers(5):As("mile")
		expect(preferenceOf((pinned * 2))).toBe("mile")
		expect(preferenceOf((2 * pinned))).toBe("mile")
		expect(preferenceOf((pinned / 2))).toBe("mile")
		expect(preferenceOf((pinned + MetricUnit.kilometers(1)))).toBe("mile")
		expect(preferenceOf(pinned / MetricUnit.hours(1))).toBe("usCustomaryAndImperial")
		expect(format(MetricUnit.kilometers(5):ToUSCustomary() / MetricUnit.hours(1))).toBe("3.107 mph")
		-- A stud's system shows studs per second for the speed it makes
		expect(preferenceOf(MetricUnit.meters(1):As("stud") / MetricUnit.seconds(1))).toBe("roblox")
	end)
end)

describe("MetricUnit tostring", function()
	it("is the English short format with four significant digits", function()
		expect(mismatches({
			{ MetricUnit.days(3.5), "3 days, 12 hours" },
			{ MetricUnit.years(2), "2 years" },
			{ MetricUnit.minutes(90), "1 hour, 30 minutes" },
			{ MetricUnit.seconds(30), "30 seconds" },
			{ MetricUnit.kilometers(2), "2 km" },
			{ MetricUnit.meters(500), "500 m" },
			{ MetricUnit.millimeters(4), "4 mm" },
			{ MetricUnit.kilobytes(1_600), "1.6 MB" },
			{ MetricUnit.bytes(12), "12 B" },
			{ MetricUnit.tonnes(3), "3 t" },
			{ MetricUnit.grams(20), "20 g" },
			{ MetricUnit.kilometers(0), "0 m" },
			{ MetricUnit.days(0), "0 seconds" },
			{ MetricUnit.perYear(0.03), "0.03/yr" },
			{ MetricUnit.perDay(5), "5/d" },
			{ MetricUnit.perSecond(2), "2/s" },
			{ MetricUnit.new(60, "hertz"), "60/s" },
			{ MetricUnit.kilometers(18) / MetricUnit.hours(1), "5 m/s" },
			{ MetricUnit.kilometers(20) / MetricUnit.years(1), "2.282 m/h" },
			{ MetricUnit.new(1_600, "kilobytePerSecond"), "1.6 MB/s" },
			{ MetricUnit.bytes(20) / MetricUnit.days(1), "20 B/d" },
			{ MetricUnit.milliseconds(250), "250 milliseconds" },
			{ MetricUnit.new(40, "microsecond"), "40 microseconds" },
			{ MetricUnit.kilometers(3) * MetricUnit.kilometers(2), "6 km²" },
			{ MetricUnit.new(50, "squareMeter"), "50 m²" },
			{ MetricUnit.new(2.5, "liter"), "2.5 L" },
			{ MetricUnit.new(3, "cubicMeter"), "3 m³" },
			{ MetricUnit.new(9.81, "meterPerSecondSquared"), "9.81 m/s²" },
			{ MetricUnit.new(1_500, "newton"), "1.5 kN" },
			{ MetricUnit.new(1, "kilowattHour"), "3.6 MJ" },
			{ MetricUnit.new(2_500, "watt"), "2.5 kW" },
			{ MetricUnit.new(1, "bar"), "100 kPa" },
			{ MetricUnit.new(1_000, "kilogramPerCubicMeter"), "1,000 kg/m³" },
			{ MetricUnit.new(2, "gigabyte"), "2 GB" },
			{ MetricUnit.new(5, "milligram"), "5 mg" },
			{ MetricUnit.kilograms(2) / MetricUnit.kilometers(1), "0.002 kg/m" },
			{ MetricUnit.kilograms(2) * MetricUnit.new(3, "meterPerSecond"), "6 m·kg/s" },
			{ MetricUnit.none(0.25), "0.25" },
			{ MetricUnit.years(10_000), "10,000 years" },
			{ MetricUnit.celsius(5), "5 °C" },
			{ MetricUnit.celsius(5) - MetricUnit.celsius(2), "3 K" },
			{ MetricUnit.meters(1 / 3), "33.33 cm" },
			{ MetricUnit.kilometers(5):ToUSCustomary(), "3.107 mi" },
			{ MetricUnit.instant(90), "epoch + 1 minute, 30 seconds" },
		})).toEqual({})
	end)
end)
