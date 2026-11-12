--!strict
--[[
	@class MetricUnit.SI.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUnit = require("MetricUnit")
local MetricUnitDefinitions = require("MetricUnitDefinitions")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function format(value: any, options: any?): string
	return (string.gsub(MetricUnit.format(value, options), "\u{00A0}", " "))
end

local function parse(text: string, kind: any?): MetricUnit.MetricUnit
	local value, err = MetricUnit.parse(text, kind)
	if not value then
		error(string.format("could not parse %q: %s", text, tostring(err)))
	end
	return value
end

describe("MetricUnit SI prefixes", function()
	it("makes every SI prefix of a prefixable unit", function()
		expect(#MetricUnitDefinitions.getPrefixes()).toBe(32)
		for _, prefix in MetricUnitDefinitions.getPrefixes() do
			local unit = MetricUnitDefinitions.getUnit(prefix.name .. "volt")
			local isBinary = string.find(prefix.symbol, "i", 1, true) ~= nil
			if isBinary then
				expect(unit).toBeNil()
			else
				assert(unit, prefix.name .. "volt")
				expect(unit.symbol).toBe(prefix.symbol .. "V")
				expect(unit.factor).toBe(prefix.factor)
			end
		end
		expect(MetricUnit.new(3, "nanometer" :: any):In("meter")).toBeCloseTo(3e-9, 20)
		expect(MetricUnit.new(1, "quettameter" :: any):In("meter")).toBe(1e30)
	end)

	it("prefixes the gram, so the kilogram is one SI base unit", function()
		local kilogram = assert(MetricUnitDefinitions.getUnit("kilogram"))
		expect(kilogram.factor).toBe(1)
		expect(kilogram.prefix).toEqual({ name = "kilo", base = "gram" })
		expect(MetricUnitDefinitions.getUnit("kilokilogram" :: any)).toBeNil()
		expect(MetricUnit.new(5, "microgram"):In("milligram")).toBeCloseTo(0.005, 12)
	end)

	it("gives bytes binary prefixes and only multiples", function()
		expect(MetricUnit.new(1, "mebibyte" :: any):In("byte")).toBe(1024 ^ 2)
		expect(MetricUnit.new(1, "terabyte"):In("gigabyte")).toBe(1000)
		expect(MetricUnitDefinitions.getUnit("millibyte" :: any)).toBeNil()
		expect(MetricUnitDefinitions.getUnit("kibibit" :: any)).toBeNil()
	end)

	it("names prefixed units in English, eliding the vowel before ohm", function()
		expect(format(MetricUnit.new(3, "nanometer" :: any), { unit = "nanometer", unitDisplay = "long" })).toBe(
			"3 nanometers"
		)
		expect(format(MetricUnit.new(1, "kilohm"), { unit = "kilohm", unitDisplay = "long" })).toBe("1 kilohm")
		expect(format(MetricUnit.new(2, "megohm"), { unit = "megohm", unitDisplay = "long" })).toBe("2 megohms")
		expect(format(MetricUnit.new(2, "millihenry"), { unit = "millihenry", unitDisplay = "long" })).toBe(
			"2 millihenries"
		)
		expect(format(MetricUnit.new(2, "kilometer"), { unit = "kilometer", unitDisplay = "long", locale = "en-gb" })).toBe(
			"2 kilometres"
		)
	end)

	it("parses any prefix by symbol, name, or u for micro", function()
		expect(parse("5 GHz"):In("hertz")).toBe(5e9)
		expect(parse("3 nm"):In("nanometer" :: any)).toBeCloseTo(3, 9)
		expect(parse("2 megawatts"):In("watt")).toBe(2e6)
		expect(parse("10 us"):In("microsecond")).toBeCloseTo(10, 9)
		expect(parse("4 uA"):In("microampere")).toBeCloseTo(4, 9)
		expect(parse("250 ml"):In("liter")).toBeCloseTo(0.25, 9)
		expect(parse("2 dL"):In("deciliter")).toBeCloseTo(2, 9)
		expect(parse("3 milliamps"):In("ampere")).toBeCloseTo(0.003, 9)
		expect(parse("5 M"):GetKind()).toBe("time")
	end)
end)

describe("MetricUnit amount of substance and light", function()
	it("converts mass, moles and concentration", function()
		local waterMolarMass = MetricUnit.new(18.015, "gramPerMole")
		local moles = MetricUnit.grams(36.03) / waterMolarMass
		expect(moles:GetKind()).toBe("amount")
		expect(moles:In("mole")).toBeCloseTo(2, 9)
		local concentration = moles / MetricUnit.new(4, "liter")
		expect(concentration:GetKind()).toBe("molarConcentration")
		expect(concentration:In("millimolePerLiter")).toBeCloseTo(500, 6)
		expect((moles / MetricUnit.seconds(2)):In("katal")).toBeCloseTo(1, 9)
	end)

	it("reads liquid volume from mass through a density", function()
		local water = MetricUnit.new(1000, "kilogramPerCubicMeter")
		local volume = MetricUnit.kilograms(2) / water
		expect(volume:In("liter")).toBeCloseTo(2, 9)
		expect(format(volume)).toBe("2 L")
		expect((MetricUnit.new(330, "milliliter") * water):In("gram")).toBeCloseTo(330, 9)
		expect(MetricUnit.new(1, "usGallon"):In("centiliter")).toBeCloseTo(378.5411784, 6)
	end)

	it("derives lumens and lux from the candela and the steradian", function()
		local flux = MetricUnit.new(100, "candela") * MetricUnit.new(2, "steradian")
		expect(flux:GetKind()).toBe("luminousFlux")
		expect(flux:In("lumen")).toBe(200)
		local illuminance = flux / MetricUnit.new(4, "squareMeter")
		expect(illuminance:GetKind()).toBe("illuminance")
		expect(illuminance:In("lux")).toBe(50)
		expect(MetricUnit.pow(MetricUnit.radians(1), 2):In("steradian")).toBe(1)
	end)

	it("shares dimensions where SI does, showing the first unit unless asked", function()
		local dose = MetricUnit.new(2, "joule") / MetricUnit.kilograms(1)
		expect(dose:GetKind()).toBe("absorbedDose")
		expect(format(dose)).toBe("2 Gy")
		expect(format(dose:As("sievert"))).toBe("2 Sv")
		expect(MetricUnit.new(5, "becquerel"):In("hertz")).toBe(5)
		expect(format(MetricUnit.new(3, "millisievert"))).toBe("3 mGy")
	end)
end)
