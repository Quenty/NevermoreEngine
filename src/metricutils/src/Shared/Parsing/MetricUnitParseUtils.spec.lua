--!strict
--[[
	@class MetricUnitParseUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUnit = require("MetricUnit")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type MetricUnit = MetricUnit.MetricUnit

local function parse(text: string, kind: any?, options: any?): MetricUnit
	local value, err = MetricUnit.parse(text, kind, options)
	if not value then
		error(string.format("could not parse %q: %s", text, tostring(err)))
	end
	return value
end

local function parseError(text: string, kind: any?, options: any?): string?
	local value, err = MetricUnit.parse(text, kind, options)
	expect(value).toBeNil()
	return err
end

describe("MetricUnit.parse", function()
	it("reads a number and a unit, with or without a space", function()
		expect(parse("5 km"):In("meter")).toBe(5000)
		expect(parse("5km"):In("meter")).toBe(5000)
		expect(parse("2.5 kilometers"):In("meter")).toBe(2500)
		expect(parse("2.5 Kilometres"):In("meter")).toBe(2500)
		expect(parse("1.5 MiB"):In("byte")).toBe(1572864)
		expect(parse("1 KB"):In("byte")).toBe(1000)
		expect(parse("60 mph"):In("milePerHour")).toBeCloseTo(60, 9)
		expect(parse("100 kbps"):In("kilobitPerSecond")).toBeCloseTo(100, 9)
		expect(parse("45%"):In("percent")).toBeCloseTo(45, 9)
		expect(parse("45°"):In("degree")).toBeCloseTo(45, 9)
		expect(parse("100 studs"):In("meter")).toBeCloseTo(28, 9)
	end)

	it("reads composed units", function()
		expect(parse("5 m/s"):In("meterPerSecond")).toBe(5)
		expect(parse("9.81 m/s²"):In("meterPerSecondSquared")).toBeCloseTo(9.81, 9)
		expect(parse("9.81 m/s^2"):In("meterPerSecondSquared")).toBeCloseTo(9.81, 9)
		expect(parse("1.6 MB/s"):In("kilobytePerSecond")).toBeCloseTo(1600, 6)
		expect(parse("5/d"):In("perDay")).toBeCloseTo(5, 9)
		local momentum = parse("6 m·kg/s")
		expect(momentum:GetDimensions()).toEqual({ length = 1, mass = 1, time = -1 })
		expect(momentum:GetBaseAmount()).toBe(6)
		expect(parse("2 m^4"):GetDimensions()).toEqual({ length = 4 })
		expect(parse("5 ft/s²"):In("meterPerSecondSquared")).toBeCloseTo(5 * 0.3048, 9)
		expect(parse("3 ft·lb"):GetDimensions()).toEqual({ length = 1, mass = 1 })
		expect(parse("2 kg*m/s"):GetDimensions()).toEqual({ length = 1, mass = 1, time = -1 })
	end)

	it("reads a temperature scale as absolute unless a difference is expected", function()
		local warm = parse("20 °C")
		expect(warm:IsAbsolute()).toBe(true)
		expect(warm:In("celsius")).toBeCloseTo(20, 9)
		expect(parse("20C"):In("celsius")).toBeCloseTo(20, 9)
		expect(parse("-3 °F"):In("fahrenheit")).toBeCloseTo(-3, 9)
		local rise = parse("20 C", "temperatureDifference")
		expect(rise:IsAbsolute()).toBe(false)
		expect(rise:In("kelvin")).toBeCloseTo(20, 9)
	end)

	it("adds up several parts of one dimension", function()
		expect(parse("1h30m"):In("minute")).toBe(90)
		expect(parse("1 hour, 30 minutes"):In("minute")).toBe(90)
		expect(parse("1 hour and 30 minutes"):In("minute")).toBe(90)
		expect(parse("5 ft 3 in"):In("inch")).toBeCloseTo(63, 9)
		expect(function()
			parse("20 C 5 F")
		end).toThrow("Write a temperature as one number and unit")
	end)

	it("reads clock text and ISO durations", function()
		expect(parse("1:30"):InSeconds()).toBe(90)
		expect(parse("1:30:00"):InSeconds()).toBe(5400)
		expect(parse("-0:45"):InSeconds()).toBe(-45)
		expect(parse("PT1H30M"):InSeconds()).toBe(5400)
		expect(string.find(parseError("P1Y") or "", "calendar spans", 1, true) ~= nil).toBe(true)
	end)

	it("resolves ambiguous units by kind, then by the other parts, then by SI symbol", function()
		expect(parse("5 m"):In("meter")).toBe(5)
		expect(parse("5 m", "time"):In("minute")).toBe(5)
		expect(parse("1m30s"):In("second")).toBe(90)
		expect(parse("2 M"):In("month")).toBe(2)
		expect(parseError("5 Mb")).toBe('Unknown unit "Mb"')
		expect(parse("5 MB"):In("megabyte")).toBe(5)
	end)

	it("reads bare numbers by kind and default unit", function()
		expect(parse("5"):GetKind()).toBe("none")
		expect(parse("5", "none"):GetBaseAmount()).toBe(5)
		expect(parseError("5", "length")).toBe('Add a unit, such as "5 m"')
		expect(parseError("45", "angle")).toBe('Add a unit, such as "45°"')
		expect(parse("5", "length", { defaultUnit = "meter" }):In("meter")).toBe(5)
		expect(parse("5", "instant", { defaultUnit = "second" }):IsAbsolute()).toBe(true)
	end)

	it("returns a message to show instead of erroring", function()
		expect(parseError("")).toBe("Enter a value")
		expect(parseError("abc")).toBe('Could not read "abc"')
		expect(parseError("5 klicks")).toBe('Unknown unit "klicks"')
		expect(parseError("5 kg", "length")).toBe('Expected length, but "5 kg" is mass')
		expect(parseError("5 m", "temperature")).toBe('Expected temperature, but "5 m" is length')
	end)

	it("reads numbers with the locale's decimal mark", function()
		expect(parse("1,5 km", nil, { locale = "de-de" }):In("meter")).toBe(1500)
		expect(parse("1 234,5 m", nil, { locale = "de-de" }):In("meter")).toBeCloseTo(1234.5, 9)
		expect(parse("1,234.5 m"):In("meter")).toBeCloseTo(1234.5, 9)
	end)

	it("reads back what short formatting writes", function()
		local values: { MetricUnit } = {
			MetricUnit.meters(2500),
			MetricUnit.kilometers(0.75),
			MetricUnit.millimeters(3),
			MetricUnit.meters(1234.5),
			MetricUnit.new(50, "squareMeter"),
			MetricUnit.new(0.25, "liter"),
			MetricUnit.new(3, "cubicMeter"),
			MetricUnit.bytes(512),
			MetricUnit.megabytes(1.6),
			MetricUnit.new(8, "bit"),
			MetricUnit.kilograms(80),
			MetricUnit.tonnes(2),
			MetricUnit.grams(20),
			MetricUnit.new(1500, "newton"),
			MetricUnit.new(4184, "joule"),
			MetricUnit.new(2500, "watt"),
			MetricUnit.new(101325, "pascal"),
			MetricUnit.new(997, "kilogramPerCubicMeter"),
			MetricUnit.new(5, "meterPerSecond"),
			MetricUnit.new(36, "kilometerPerHour"),
			MetricUnit.new(1600, "kilobytePerSecond"),
			MetricUnit.perDay(5),
			MetricUnit.perSecond(2),
			MetricUnit.new(60, "hertz"),
			MetricUnit.new(9.81, "meterPerSecondSquared"),
			MetricUnit.celsius(21.5),
			MetricUnit.celsius(-3),
			MetricUnit.degrees(45),
			MetricUnit.new(90, "degreePerSecond"),
			MetricUnit.new(2, "radianPerSecondSquared"),
			MetricUnit.none(0.45),
			MetricUnit.minutes(90),
			MetricUnit.years(1),
			MetricUnit.days(1.5),
			MetricUnit.milliseconds(250),
			MetricUnit.new(40, "microsecond"),
			MetricUnit.seconds(0),
			MetricUnit.kilograms(2) * MetricUnit.new(3, "meterPerSecond"),
			MetricUnit.pow(MetricUnit.meters(2), 4),
		}
		for _, value in values do
			local text = MetricUnit.format(value)
			local parsed = parse(text)
			expect(MetricUnit.format(parsed)).toBe(text)
			expect(parsed:GetKind()).toBe(value:GetKind())
		end

		-- A temperature difference reads back with its kind, since "5 K" alone is an absolute temperature
		local rise = MetricUnit.difference(5, "celsius")
		expect(MetricUnit.format(parse(MetricUnit.format(rise), "temperatureDifference"))).toBe("5\u{00A0}K")
	end)
end)

describe("MetricUnit.parse negative text in several parts", function()
	it("applies the leading minus sign to every part", function()
		expect(parse("-1 hour, 30 minutes"):In("minute")).toBeCloseTo(-90, 9)
		expect(parse("-5 ft 3 in"):In("inch")).toBeCloseTo(-63, 9)
		expect(parse("-1h30m"):In("second")).toBeCloseTo(-5400, 9)
		expect(parse("1 hour, 30 minutes"):In("minute")).toBeCloseTo(90, 9)
	end)

	it("reads back what the formatter writes for a negative duration", function()
		local written = MetricUnit.format(-MetricUnit.minutes(90))
		expect(parse(written):In("minute")).toBeCloseTo(-90, 9)
	end)
end)
