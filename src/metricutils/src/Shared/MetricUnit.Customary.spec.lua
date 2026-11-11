--!strict
--[[
	@class MetricUnit.Customary.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUnit = require("MetricUnit")
local MetricUnitSystems = require("MetricUnitSystems")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function format(value: any, options: any?): string
	return (string.gsub(MetricUnit.format(value, options), "\u{00A0}", " "))
end

describe("MetricUnit US customary and British imperial", function()
	it("keeps US and imperial volumes apart", function()
		expect(MetricUnit.new(1, "usGallon"):In("liter")).toBeCloseTo(3.785411784, 9)
		expect(MetricUnit.new(1, "imperialGallon"):In("liter")).toBeCloseTo(4.54609, 9)
		expect(MetricUnit.new(1, "imperialPint"):In("usPint")).toBeCloseTo(1.20095, 5)
		expect(MetricUnit.new(1, "usCup"):In("usTablespoon")).toBeCloseTo(16, 9)
		expect(MetricUnit.new(1, "usTablespoon"):In("usTeaspoon")).toBeCloseTo(3, 9)
		expect(MetricUnit.new(1, "imperialPint"):In("imperialFluidOunce")).toBeCloseTo(20, 9)
	end)

	it("shows each system's units for a value that asks for it", function()
		local volume = MetricUnit.new(2, "liter")
		expect(format(volume:ToUSCustomary())).toBe("2.113 US qt")
		expect(format(volume:ToImperial())).toBe("3.52 imp pt")
		expect(format(MetricUnit.new(250, "milliliter"):ToUSCustomary())).toBe("1.057 cups")
		expect(format(MetricUnit.new(5, "milliliter"):ToUSCustomary())).toBe("1.014 tsp")

		local body = MetricUnit.kilograms(80)
		expect(format(body:ToUSCustomary())).toBe("176.37 lb")
		expect(format(body:ToImperial())).toBe("12.598 st")
		expect(format(MetricUnit.new(2, "tonne"):ToUSCustomary())).toBe("2.205 tn")

		local distance = MetricUnit.kilometers(5)
		expect(format(distance:ToUSCustomary())).toBe("3.107 mi")
		expect(format(distance:ToImperial())).toBe("3.107 mi")
		expect(distance:ToImperial():GetDisplaySystem()).toBe(MetricUnitSystems.IMPERIAL)
	end)

	it("covers areas, volumes and densities in feet and inches", function()
		expect(MetricUnit.new(1, "squareMile"):In("acre")).toBeCloseTo(640, 9)
		expect(MetricUnit.new(1, "cubicFoot"):In("cubicInch")).toBeCloseTo(1728, 9)
		expect(MetricUnit.new(1, "cubicYard"):In("cubicFoot")).toBeCloseTo(27, 9)
		expect(MetricUnit.new(1, "usGallon"):In("cubicInch")).toBeCloseTo(231, 9)
		expect(MetricUnit.new(62.428, "poundPerCubicFoot"):In("kilogramPerCubicMeter")).toBeCloseTo(1000, 2)
		expect(MetricUnit.new(1, "nauticalMile"):In("meter")).toBe(1852)
	end)
end)

describe("MetricUnit for cars", function()
	it("converts horsepower, torque and fuel economy", function()
		expect(MetricUnit.new(1, "horsepower"):In("watt")).toBeCloseTo(745.6999, 4)
		expect(MetricUnit.new(1, "metricHorsepower"):In("watt")).toBeCloseTo(735.49875, 9)
		expect(format(MetricUnit.new(100, "kilowatt"):ToUSCustomary())).toBe("134.102 hp")

		local torque = MetricUnit.new(300, "poundFoot")
		expect(torque:In("newtonMeter")).toBeCloseTo(406.7454, 4)
		expect(format(torque:As("newtonMeter"))).toBe("406.745 N·m")

		local economy = MetricUnit.new(30, "milePerUsGallon")
		expect(economy:GetKind()).toBe("fuelEconomy")
		expect(economy:In("kilometerPerLiter")).toBeCloseTo(12.7543, 4)
		expect(economy:In("milePerImperialGallon")).toBeCloseTo(36.0285, 4)
		expect((1 / economy):In("literPer100Kilometers")).toBeCloseTo(7.8405, 4)
		expect(format(economy:ToImperial())).toBe("36.028 mpg (UK)")
		expect(format(economy)).toBe("30 mpg (US)")
		expect(format(economy:ToMetric())).toBe("12.754 km/L")
	end)

	it("derives fuel economy from a distance and the fuel it used", function()
		local economy = MetricUnit.new(300, "mile") / MetricUnit.new(10, "usGallon")
		expect(economy:In("milePerUsGallon")).toBeCloseTo(30, 9)
		expect(format(economy:ToUSCustomary())).toBe("30 mpg (US)")
	end)

	it("converts BTU, psi, inches of mercury and Rankine", function()
		expect(MetricUnit.new(1, "britishThermalUnit"):In("joule")).toBeCloseTo(1055.05585262, 9)
		expect(MetricUnit.new(29.92, "inchOfMercury"):In("kilopascal")).toBeCloseTo(101.32, 2)
		expect(MetricUnit.new(32, "poundForcePerSquareInch"):In("kilopascal")).toBeCloseTo(220.632, 3)
		expect(MetricUnit.point(491.67, "rankine"):In("celsius")).toBeCloseTo(0, 9)
		expect(MetricUnit.new(10, "footPerSecondSquared"):In("meterPerSecondSquared")).toBeCloseTo(3.048, 9)
	end)

	it("parses car units as they are written", function()
		local function parse(text: string): MetricUnit.MetricUnit
			return assert(MetricUnit.parse(text)) :: any
		end
		expect(parse("300 hp"):In("horsepower")).toBe(300)
		expect(parse("400 Nm"):In("newtonMeter")).toBe(400)
		expect(parse("300 lb-ft"):In("poundFoot")).toBe(300)
		expect(parse("30 mpg"):In("milePerUsGallon")).toBe(30)
		expect(parse("12000 BTU"):In("britishThermalUnit")).toBe(12000)
		expect(parse("2 cups"):In("usCup")).toBe(2)
		expect(parse("150 PS"):In("metricHorsepower")).toBe(150)
	end)
end)
