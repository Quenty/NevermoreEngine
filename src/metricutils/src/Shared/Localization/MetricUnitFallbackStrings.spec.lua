--!strict
--[[
	@class MetricUnitFallbackStrings.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUnitDefinitions = require("MetricUnitDefinitions")
local MetricUnitFallbackStrings = require("MetricUnitFallbackStrings")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local LOCALES = { "en-us", "en-gb" }
local NB = MetricUnitFallbackStrings.NO_BREAK_SPACE

describe("MetricUnitFallbackStrings", function()
	it("resolves regional English to American or Commonwealth spelling", function()
		local function longKilometer(locale: string): any
			return (MetricUnitFallbackStrings.getUnitStringsForLocale(locale).kilometer.long :: any).other
		end
		expect(longKilometer("en-us")).toBe("%s" .. NB .. "kilometers")
		expect(longKilometer("en")).toBe("%s" .. NB .. "kilometers")
		expect(longKilometer("en-gb")).toBe("%s" .. NB .. "kilometres")
		expect(longKilometer("en-au")).toBe("%s" .. NB .. "kilometres")
		expect(longKilometer("en-ca")).toBe("%s" .. NB .. "kilometres")
		expect(MetricUnitFallbackStrings.getLocale("en-nz")).toBe(MetricUnitFallbackStrings.getLocale("en-gb"))
	end)

	it("spells only metre, litre and tonne differently", function()
		local american = MetricUnitFallbackStrings.getUnitStringsForLocale("en-us") :: any
		local commonwealth = MetricUnitFallbackStrings.getUnitStringsForLocale("en-gb") :: any
		expect(american.tonne.long.other).toBe("%s" .. NB .. "metric tons")
		expect(commonwealth.tonne.long.other).toBe("%s" .. NB .. "tonnes")
		expect(commonwealth.kilogramPerCubicMeter.long.one).toBe("%s" .. NB .. "kilogram per cubic metre")
		expect(commonwealth.usGallon.long.other).toBe("%s" .. NB .. "US gallons")
		expect(american.foot.long.other).toBe("%s" .. NB .. "feet")
		expect(commonwealth.foot.long.other).toBe("%s" .. NB .. "feet")
	end)

	it("knows which locales have their own names", function()
		expect(MetricUnitFallbackStrings.hasLocale("en-us")).toBe(true)
		expect(MetricUnitFallbackStrings.hasLocale("en-ie")).toBe(true)
		expect(MetricUnitFallbackStrings.hasLocale("de-de")).toBe(false)
	end)

	it("names every defined unit that has English names, in every locale", function()
		for _, locale in LOCALES do
			local units = MetricUnitFallbackStrings.getUnitStringsForLocale(locale) :: any
			for _, unit in MetricUnitDefinitions.getUnits() do
				if unit.names then
					expect(units[unit.id]).never.toBeNil()
					expect(units[unit.id].short).never.toBeNil()
					expect(units[unit.id].long).never.toBeNil()
				else
					expect(units[unit.id]).toBeNil()
				end
			end
		end
	end)

	it("writes the short phrase from the symbol", function()
		local units = MetricUnitFallbackStrings.getUnitStringsForLocale("en-us")
		expect((units.squareMeter.short :: any).one).toBe("%s" .. NB .. "m²")
		expect((units.celsius.short :: any).other).toBe("%s" .. NB .. "°C")
		expect((units.celsius.long :: any).one).toBe("%s" .. NB .. "degree Celsius")
		expect((units.stud.short :: any).one).toBe("%s" .. NB .. "stud")
		expect((units.stud.short :: any).other).toBe("%s" .. NB .. "studs")
	end)

	it("has a per phrase for every time unit a rate can be written per", function()
		local per = MetricUnitFallbackStrings.getPerStringsForLocale("en-us")
		expect(per.hour.short).toBe("%s/h")
		expect(per.hour.long).toBe("%s per hour")
		expect(per.day.short).toBe("%s/d")
		for _, id in { "second", "minute", "hour", "day", "week", "month", "year" } do
			expect((per :: any)[id]).never.toBeNil()
		end
	end)
end)
