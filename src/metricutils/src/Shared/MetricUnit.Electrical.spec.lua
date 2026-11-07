--!strict
--[[
	@class MetricUnit.Electrical.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUnit = require("MetricUnit")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function format(value: any): string
	return (string.gsub(MetricUnit.format(value), "\u{00A0}", " "))
end

local function parse(text: string, kind: any?): MetricUnit.MetricUnit
	local value, err = MetricUnit.parse(text, kind)
	if not value then
		error(string.format("could not parse %q: %s", text, tostring(err)))
	end
	return value
end

describe("MetricUnit circuits", function()
	it("follows Ohm's law and the power law", function()
		local voltage = MetricUnit.new(12, "volt")
		local resistance = MetricUnit.new(4.7, "kilohm")
		local current = voltage / resistance
		expect(current:GetKind()).toBe("current")
		expect(current:In("milliampere")).toBeCloseTo(2.5532, 4)
		expect((current * resistance):In("volt")).toBeCloseTo(12, 9)
		expect((voltage * current):GetKind()).toBe("power")
		expect((voltage * current):In("watt")).toBeCloseTo(0.030638, 6)
	end)

	it("makes seconds from RC and L/R time constants", function()
		local tau = MetricUnit.new(10, "kilohm") * MetricUnit.new(100, "nanofarad")
		expect(tau:GetKind()).toBe("time")
		expect(tau:In("millisecond")).toBeCloseTo(1, 9)
		local inductive = MetricUnit.new(10, "millihenry") / MetricUnit.new(1, "ohm")
		expect(inductive:In("millisecond")).toBeCloseTo(10, 9)
	end)

	it("relates charge, capacitance and stored energy", function()
		local capacitance = MetricUnit.new(470, "microfarad")
		local voltage = MetricUnit.new(5, "volt")
		local charge = capacitance * voltage
		expect(charge:GetKind()).toBe("charge")
		expect(charge:In("coulomb")).toBeCloseTo(0.00235, 9)
		expect((charge / MetricUnit.seconds(1)):In("milliampere")).toBeCloseTo(2.35, 9)
		local energy = 0.5 * capacitance * MetricUnit.pow(voltage, 2)
		expect(energy:In("joule")).toBeCloseTo(0.005875, 9)
	end)

	it("relates flux, flux density, inductance and conductance", function()
		local flux = MetricUnit.new(2, "volt") * MetricUnit.seconds(3)
		expect(flux:GetKind()).toBe("magneticFlux")
		expect(flux:In("weber")).toBe(6)
		expect((flux / MetricUnit.new(2, "squareMeter")):In("tesla")).toBe(3)
		expect((flux / MetricUnit.new(2, "ampere")):In("henry")).toBe(3)
		expect((1 / MetricUnit.new(50, "ohm")):In("siemens")).toBeCloseTo(0.02, 9)
	end)

	it("names every electrical kind", function()
		expect(MetricUnit.new(1, "ampere"):GetKind()).toBe("current")
		expect(MetricUnit.new(1, "coulomb"):GetKind()).toBe("charge")
		expect(MetricUnit.new(1, "volt"):GetKind()).toBe("voltage")
		expect(MetricUnit.new(1, "ohm"):GetKind()).toBe("resistance")
		expect(MetricUnit.new(1, "siemens"):GetKind()).toBe("conductance")
		expect(MetricUnit.new(1, "farad"):GetKind()).toBe("capacitance")
		expect(MetricUnit.new(1, "henry"):GetKind()).toBe("inductance")
		expect(MetricUnit.new(1, "weber"):GetKind()).toBe("magneticFlux")
		expect(MetricUnit.new(1, "tesla"):GetKind()).toBe("magneticFluxDensity")
	end)
end)

describe("MetricUnit electrical formatting", function()
	it("picks the prefix a component is labelled with", function()
		expect(format(MetricUnit.new(4700, "ohm"))).toBe("4.7 kΩ")
		expect(format(MetricUnit.new(0.1, "microfarad"))).toBe("100 nF")
		expect(format(MetricUnit.new(0.0015, "ampere"))).toBe("1.5 mA")
		expect(format(MetricUnit.new(3.3, "volt"))).toBe("3.3 V")
		expect(format(MetricUnit.new(2200, "microhenry"))).toBe("2.2 mH")
		expect(format(MetricUnit.new(0.05, "tesla"))).toBe("50 mT")
		expect(format(MetricUnit.new(2, "volt") / MetricUnit.seconds(1))).toBe("2 V/s")
	end)
end)

describe("MetricUnit electrical parsing", function()
	it("reads component values as they are written", function()
		expect(parse("4.7kΩ"):In("ohm")).toBeCloseTo(4700, 9)
		expect(parse("4.7 kilohms"):In("ohm")).toBeCloseTo(4700, 9)
		expect(parse("100nF"):In("nanofarad")).toBeCloseTo(100, 9)
		expect(parse("10 uF"):In("microfarad")).toBeCloseTo(10, 9)
		expect(parse("10 µF"):In("microfarad")).toBeCloseTo(10, 9)
		expect(parse("12 V"):In("volt")).toBe(12)
		expect(parse("2 amps"):In("ampere")).toBe(2)
	end)

	it("reads the Greek mu and the ohm sign as the micro sign and omega", function()
		expect(parse("10 \u{03BC}F"):In("microfarad")).toBeCloseTo(10, 9)
		expect(parse("5 \u{2126}"):In("ohm")).toBe(5)
	end)

	it("keeps C and F as temperatures unless a charge or capacitance is expected", function()
		expect(parse("20 C"):GetKind()).toBe("temperature")
		expect(parse("20 F"):GetKind()).toBe("temperature")
		expect(parse("20 C", "charge"):In("coulomb")).toBe(20)
		expect(parse("20 F", "capacitance"):In("farad")).toBe(20)
	end)
end)
