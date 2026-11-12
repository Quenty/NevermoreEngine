--!strict
--[[
	@class MetricUnitDimensionUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUnitDimensionUtils = require("MetricUnitDimensionUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("MetricUnitDimensionUtils", function()
	it("combines exponents, dropping zeros, frozen", function()
		local speed = MetricUnitDimensionUtils.combine({ length = 1 }, { time = 1 }, -1)
		expect(speed).toEqual({ length = 1, time = -1 })
		expect(table.isfrozen(speed)).toBe(true)
		expect(MetricUnitDimensionUtils.combine(speed, { time = 1 }, 1)).toEqual({ length = 1 })
		expect(MetricUnitDimensionUtils.combine(speed, speed, -1)).toEqual(MetricUnitDimensionUtils.NONE)
	end)

	it("takes any name as a dimension", function()
		local people = MetricUnitDimensionUtils.combine({ people = 1 }, { length = 1 }, -2)
		expect(MetricUnitDimensionUtils.describe(people)).toBe("people/length^2")
	end)

	it("scales exponents, erroring on a fractional one", function()
		expect(MetricUnitDimensionUtils.scale({ length = 2 }, 0.5)).toEqual({ length = 1 })
		expect(function()
			MetricUnitDimensionUtils.scale({ length = 1 }, 0.5)
		end).toThrow("length to the power 0.5 has a fractional exponent")
	end)

	it("describes dimensions as a formula", function()
		expect(MetricUnitDimensionUtils.describe(MetricUnitDimensionUtils.NONE)).toBe("dimensionless")
		expect(MetricUnitDimensionUtils.describe({ time = -1 })).toBe("1/time")
		expect(MetricUnitDimensionUtils.describe({ length = 2, mass = 1 })).toBe("length^2·mass")
	end)

	it("tells equal dimensions apart, and valid ones from others", function()
		expect(MetricUnitDimensionUtils.equal({ length = 1, time = -1 }, { time = -1, length = 1 })).toBe(true)
		expect(MetricUnitDimensionUtils.equal({ length = 1 }, { length = 1, time = -1 })).toBe(false)
		expect(MetricUnitDimensionUtils.isDimensions({ length = 2 })).toBe(true)
		expect(MetricUnitDimensionUtils.isDimensions({ length = 0.5 })).toBe(false)
		expect(MetricUnitDimensionUtils.isDimensions({ length = 0 })).toBe(false)
	end)
end)
