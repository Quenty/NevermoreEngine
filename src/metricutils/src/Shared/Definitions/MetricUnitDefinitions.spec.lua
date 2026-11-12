--!strict
--[[
	@class MetricUnitDefinitions.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUnit = require("MetricUnit")
local MetricUnitDefinitions = require("MetricUnitDefinitions")
local MetricUnitDimensionUtils = require("MetricUnitDimensionUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- A unit is written by name unless @quenty/time's duration words or a per phrase write it
local function isWrittenByName(unit: MetricUnitDefinitions.UnitDefinition): boolean
	return unit.per == nil and (not unit.duration or unit.id == "microsecond")
end

describe("MetricUnitDefinitions", function()
	it("declares each unit once, and every unit makes and reads back through MetricUnit.new", function()
		local seen: { [string]: boolean } = {}
		for _, unit in MetricUnitDefinitions.getUnits() do
			expect(seen[unit.id]).toBeNil()
			seen[unit.id] = true
			expect(MetricUnitDefinitions.getUnit(unit.id)).toBe(unit)
			expect(MetricUnit.new(1, unit.id):In(unit.id)).toBeCloseTo(1, 9)
			expect(MetricUnitDimensionUtils.isDimensions(unit.dimensions)).toBe(true)
			expect(unit.factor > 0).toBe(true)
		end
	end)

	it("gives English names to every unit written by name, and to no other", function()
		for _, unit in MetricUnitDefinitions.getUnits() do
			if isWrittenByName(unit) then
				local names = unit.names
				assert(names, string.format("%s has no English names", unit.id))
				expect(#names.one > 0 and #names.other > 0).toBe(true)
			else
				expect(unit.names).toBeNil()
			end
		end
	end)

	it("resolves @quenty/time's names to time units", function()
		for alias, id in MetricUnitDefinitions.getTimeAliases() do
			local unit = MetricUnitDefinitions.getUnit(alias)
			assert(unit, alias)
			expect(unit.id).toBe(id)
			expect(unit.duration).toBe(true)
		end
	end)
end)
