--!strict
--[[
	@class MetricUnitLocalizationUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUnitCatalog = require("MetricUnitCatalog")
local MetricUnitDimensions = require("MetricUnitDimensions")
local MetricUnitLocalizationUtils = require("MetricUnitLocalizationUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local LOCALES = { "en-us", "en-gb" }

-- Every named dimension's units, so the check below covers the whole catalog
local KINDS: { MetricUnitDimensions.DimensionName } = {
	"time",
	"length",
	"area",
	"volume",
	"memory",
	"mass",
	"rate",
	"speed",
	"acceleration",
	"force",
	"energy",
	"power",
	"pressure",
	"density",
	"dataRate",
	"temperature",
}

describe("MetricUnitLocalizationUtils", function()
	it("resolves regional English to American or Commonwealth spelling", function()
		local function longKilometer(locale: string): any
			return (MetricUnitLocalizationUtils.getUnitStringsForLocale(locale).kilometer.long :: any).other
		end
		expect(longKilometer("en-us")).toBe("%s kilometers")
		expect(longKilometer("en")).toBe("%s kilometers")
		expect(longKilometer("en-gb")).toBe("%s kilometres")
		expect(longKilometer("en-au")).toBe("%s kilometres")
		expect(longKilometer("en-ca")).toBe("%s kilometres")
		expect(MetricUnitLocalizationUtils.getLocale("en-nz")).toBe(MetricUnitLocalizationUtils.getLocale("en-gb"))
	end)

	it("spells only metre, litre and tonne differently", function()
		local american = MetricUnitLocalizationUtils.getUnitStringsForLocale("en-us") :: any
		local commonwealth = MetricUnitLocalizationUtils.getUnitStringsForLocale("en-gb") :: any
		expect(american.tonne.long.other).toBe("%s metric tons")
		expect(commonwealth.tonne.long.other).toBe("%s tonnes")
		expect(commonwealth.kilogramPerCubicMeter.long.one).toBe("%s kilogram per cubic metre")
		expect(commonwealth.usGallon.long.other).toBe("%s US gallons")
		expect(american.foot.long.other).toBe("%s feet")
		expect(commonwealth.foot.long.other).toBe("%s feet")
	end)

	it("knows which locales have their own names", function()
		expect(MetricUnitLocalizationUtils.hasLocale("en-us")).toBe(true)
		expect(MetricUnitLocalizationUtils.hasLocale("en-ie")).toBe(true)
		expect(MetricUnitLocalizationUtils.hasLocale("de-de")).toBe(false)
	end)

	it("names every unit written by name in every locale", function()
		for _, locale in LOCALES do
			local units = MetricUnitLocalizationUtils.getUnitStringsForLocale(locale) :: any
			for _, kind in KINDS do
				local dimensions = MetricUnitDimensions.fromName(kind :: MetricUnitDimensions.DimensionName)
				for _, id in MetricUnitCatalog.getUnitIds(dimensions) do
					local unit = MetricUnitCatalog.getUnit(id)
					assert(unit, id)
					-- Time units use @quenty/time's duration words, and bare rates the per phrases
					local hasWords = unit.duration and id ~= "microsecond"
					if not hasWords and unit.per == nil then
						expect(units[id]).never.toBeNil()
						expect(units[id].short).never.toBeNil()
						expect(units[id].long).never.toBeNil()
					end
				end
			end
		end
	end)

	it("writes the short phrase from the symbol", function()
		local units = MetricUnitLocalizationUtils.getUnitStringsForLocale("en-us")
		expect((units.squareMeter.short :: any).one).toBe("%s m²")
		expect((units.celsius.short :: any).other).toBe("%s °C")
		expect((units.celsius.long :: any).one).toBe("%s degree Celsius")
		expect((units.stud.short :: any).one).toBe("%s stud")
		expect((units.stud.short :: any).other).toBe("%s studs")
	end)

	it("has a per phrase for every time unit a rate can be written per", function()
		local per = MetricUnitLocalizationUtils.getPerStringsForLocale("en-us")
		expect(per.hour.short).toBe("%s/h")
		expect(per.hour.long).toBe("%s per hour")
		expect(per.day.short).toBe("%s/d")
		for _, id in { "second", "minute", "hour", "day", "week", "month", "year" } do
			expect((per :: any)[id]).never.toBeNil()
		end
	end)
end)
