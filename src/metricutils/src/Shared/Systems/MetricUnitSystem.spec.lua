--!strict
--[[
	@class MetricUnitSystem.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUnit = require("MetricUnit")
local MetricUnitDefinitions = require("MetricUnitDefinitions")
local MetricUnitSystem = require("MetricUnitSystem")
local MetricUnitSystems = require("MetricUnitSystems")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local MINI = MetricUnitSystems.roblox({ name = "robloxMini", metersPerStud = 0.028 })

local function plain(text: string): string
	return (string.gsub(text, "\u{00A0}", " "))
end

local function format(value: any, options: any?): string
	return plain(MetricUnit.format(value, options))
end

describe("MetricUnitSystems", function()
	it("names the well-known systems and chains their fallbacks", function()
		expect(MetricUnitSystems.METRIC:GetName()).toBe("metric")
		expect(MetricUnitSystems.US_CUSTOMARY:GetFallback()).toBe(MetricUnitSystems.US_CUSTOMARY_AND_IMPERIAL)
		expect(MetricUnitSystems.IMPERIAL:GetFallback()).toBe(MetricUnitSystems.US_CUSTOMARY_AND_IMPERIAL)
		expect(MetricUnitSystems.US_CUSTOMARY_AND_IMPERIAL:GetFallback()).toBe(MetricUnitSystems.METRIC)
		expect(MetricUnitSystems.ROBLOX:GetFallback()).toBe(MetricUnitSystems.METRIC)
		expect(MetricUnitSystem.isSystem(MetricUnitSystems.ROBLOX)).toBe(true)
		expect(MetricUnitSystem.isSystem({})).toBe(false)
	end)

	it("finds the system that declares a unit", function()
		expect(MetricUnitSystems.getSystemOfUnit(assert(MetricUnitDefinitions.getUnit("imperialPint")))).toBe(
			MetricUnitSystems.IMPERIAL
		)
		expect(MetricUnitSystems.getSystemOfUnit(assert(MINI:GetUnit("stud")))).toBe(MINI)
		expect(MetricUnitSystems.getSystemOfUnit(assert(MetricUnitDefinitions.getUnit("second")))).toBeNil()
	end)
end)

describe("a value shows itself in the system of the unit it was made from", function()
	it("prefers nothing when made from a metric unit", function()
		expect(MetricUnit.kilometers(8):GetDisplaySystem()).toBeNil()
		expect(format(MetricUnit.kilometers(8))).toBe("8 km")
	end)

	it("prefers the unit's system otherwise", function()
		expect(format(MetricUnit.new(5, "mile"))).toBe("5 mi")
		expect(format(MetricUnit.new(30, "milePerUsGallon"))).toBe("30 mpg (US)")
		expect(format(MetricUnit.new(2, "imperialPint"))).toBe("2 imp pt")
		expect(format(MetricUnit.studs(10))).toBe("10 studs")
	end)

	it("converts to another system for display", function()
		local distance = MetricUnit.new(5, "mile")
		expect(format(distance:ToMetric())).toBe("8.047 km")
		expect(format(MetricUnit.kilometers(8):ToImperial())).toBe("4.971 mi")
	end)
end)

describe("MetricUnitSystem:Format", function()
	it("shows any value in the system", function()
		expect(plain(MetricUnitSystems.IMPERIAL:Format(MetricUnit.new(2, "liter")))).toBe("3.52 imp pt")
		expect(plain(MetricUnitSystems.US_CUSTOMARY:Format(MetricUnit.new(2, "liter")))).toBe("2.113 US qt")
		expect(plain(MetricUnitSystems.METRIC:Format(MetricUnit.new(5, "mile")))).toBe("8.047 km")
		expect(plain(MINI:Format(MetricUnit.meters(0.14)))).toBe("5 studs")
	end)

	it("falls back for dimensions the system does not list", function()
		expect(plain(MINI:Format(MetricUnit.seconds(90)))).toBe("1 minute, 30 seconds")
		expect(plain(MetricUnitSystems.IMPERIAL:Format(MetricUnit.new(5, "volt")))).toBe("5 V")
	end)
end)

describe("MetricUnitSystems.roblox", function()
	it("reads stud amounts in and out at a game's own scale", function()
		local height = MINI:New(5, "stud")
		expect(height:In("meter")).toBeCloseTo(0.14, 9)
		expect(MINI:In(height, "stud")).toBeCloseTo(5, 9)
		expect(format(height)).toBe("5 studs")
		expect(format(height:ToMetric())).toBe("14 cm")
	end)

	it("scales speeds, accelerations and the mass unit with the stud", function()
		expect(MINI:New(10, "studPerSecond"):In("meterPerSecond")).toBeCloseTo(0.28, 9)
		expect(MINI:New(1, "studPerSecondSquared"):In("meterPerSecondSquared")).toBeCloseTo(0.028, 9)
		expect(MINI:New(1, "robloxMassUnit"):In("gram")).toBeCloseTo(21.952, 9)
		if typeof(Vector3) == "userdata" or typeof(Vector3) == "table" then
			local speed = MINI:New(Vector3.new(30, 40, 0).Magnitude, "studPerSecond")
			expect(speed:In("meterPerSecond")).toBeCloseTo(1.4, 9)
		end
	end)

	it("keeps Roblox's own studs apart from the game's", function()
		local height = MINI:New(5, "stud")
		expect(height:In("stud")).toBeCloseTo(0.5, 9)
		expect((MetricUnit.studs(10) + MINI:New(100, "stud")):In("meter")).toBeCloseTo(5.6, 9)
	end)

	it("keeps its studs through arithmetic", function()
		local height = MINI:New(5, "stud")
		expect(format(height * 2)).toBe("10 studs")
		expect(format(height / MetricUnit.seconds(1))).toBe("5 studs/s")
		expect(format(MetricUnit.round(MINI:New(5.4, "stud"), "stud"))).toBe("5 studs")
	end)

	it("pins a value to one of its units", function()
		local stud = assert(MINI:GetUnit("stud"))
		expect(format(MetricUnit.meters(0.14):As(stud))).toBe("5 studs")
		expect(MetricUnit.meters(0.14):As(stud):GetDisplayUnit()).toBe(stud)
		expect(MetricUnit.meters(0.14):In(stud)).toBeCloseTo(5, 9)
	end)

	it("parses studs at its scale", function()
		local value = assert(MINI:Parse("5 studs", "length"))
		expect(value:In("meter")).toBeCloseTo(0.14, 9)
		expect(format(value)).toBe("5 studs")
		local plainStuds = assert(MetricUnit.parse("5 studs", "length"))
		expect(plainStuds:In("meter")).toBeCloseTo(1.4, 9)
		local bare = assert(MINI:Parse("5", "length", { defaultUnit = "stud" }))
		expect(bare:In("meter")).toBeCloseTo(0.14, 9)
	end)

	it("shows the game's stud amounts in a player's chosen system", function()
		local distance = MINI:New(10000, "stud")
		expect(plain(MetricUnitSystems.METRIC:Format(distance))).toBe("280 m")
		expect(plain(MetricUnitSystems.US_CUSTOMARY:Format(distance))).toBe("918.635 ft")
		expect(format(distance)).toBe("10,000 studs")
	end)
end)

describe("MetricUnitSystem.new", function()
	local SPACE = MetricUnitSystem.new({
		name = "space",
		units = MetricUnitDefinitions.createUnits("length", "space", {
			{ id = "lightYear" :: any, factor = 9.4607e15, symbol = "ly", name = "light-year" },
			{ id = "parsec" :: any, factor = 3.0857e16, symbol = "pc", name = "parsec", prefixes = "si" },
		}),
		displayUnits = { { "parsec", "lightYear", "kilometer" } },
		fallback = MetricUnitSystems.METRIC,
	})

	it("declares units only it knows", function()
		expect(MetricUnitDefinitions.getUnit("lightYear" :: any)).toBeNil()
		expect(SPACE:New(2, "lightYear"):In("kilometer")).toBeCloseTo(1.89214e13, -8)
		expect(SPACE:In(SPACE:New(1, "kiloparsec"), "parsec")).toBeCloseTo(1000, 9)
		expect(SPACE:New(3, "meter"):In("meter")).toBe(3)
		expect(function()
			MetricUnit.new(1, "lightYear" :: any)
		end).toThrow('MetricUnit.new knows no unit "lightYear"')
		expect(function()
			SPACE:New(1, "furlong")
		end).toThrow('"space" knows no unit "furlong"')
	end)

	it("shows and writes its own units in English", function()
		local distance = SPACE:New(4.2, "lightYear")
		expect(format(distance)).toBe("1.288 pc")
		expect(format(distance, { unit = "lightYear", unitDisplay = "long" })).toBe("4.2 light-years")
		expect(plain(SPACE:Format(MetricUnit.kilograms(3)))).toBe("3 kg")
	end)

	it("parses its own units", function()
		local value = assert(SPACE:Parse("4.2 ly", "length"))
		expect(SPACE:In(value, "lightYear")).toBeCloseTo(4.2, 9)
	end)

	it("errors on a display unit it cannot find, when it first shows a value", function()
		local broken = MetricUnitSystem.new({ name = "broken", displayUnits = { { "furlong" } } })
		expect(function()
			broken:Format(MetricUnit.meters(1))
		end).toThrow('MetricUnitSystem "broken" knows no unit "furlong"')
	end)
end)
