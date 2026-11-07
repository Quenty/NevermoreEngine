--!strict
--[[
	@class MetricUnitDimensions.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUnitDimensions = require("MetricUnitDimensions")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("MetricUnitDimensions", function()
	it("combines exponents, dropping zeros, frozen", function()
		local speed = MetricUnitDimensions.combine(MetricUnitDimensions.LENGTH, MetricUnitDimensions.TIME, -1)
		expect(speed).toEqual({ length = 1, time = -1 })
		expect(table.isfrozen(speed)).toBe(true)
		expect(MetricUnitDimensions.combine(speed, MetricUnitDimensions.TIME, 1)).toEqual({ length = 1 })
	end)

	it("takes any name as a dimension", function()
		local people = MetricUnitDimensions.combine({ people = 1 }, MetricUnitDimensions.LENGTH, -2)
		expect(MetricUnitDimensions.describe(people)).toBe("people/length^2")
	end)

	it("describes dimensions as a formula", function()
		expect(MetricUnitDimensions.describe(MetricUnitDimensions.NONE)).toBe("dimensionless")
		expect(MetricUnitDimensions.describe(MetricUnitDimensions.RATE)).toBe("1/time")
		expect(MetricUnitDimensions.describe({ length = 2, mass = 1 })).toBe("length^2·mass")
		expect(MetricUnitDimensions.describeKind(MetricUnitDimensions.TEMPERATURE, true)).toBe("absolute temperature")
		expect(MetricUnitDimensions.describeKind(MetricUnitDimensions.TEMPERATURE, false)).toBe(
			"temperature difference"
		)
	end)

	it("builds derived dimensions from the base ones", function()
		local force = MetricUnitDimensions.combine(MetricUnitDimensions.MASS, MetricUnitDimensions.ACCELERATION, 1)
		expect(MetricUnitDimensions.equal(force, MetricUnitDimensions.FORCE)).toBe(true)
		local energy = MetricUnitDimensions.combine(force, MetricUnitDimensions.LENGTH, 1)
		expect(MetricUnitDimensions.equal(energy, MetricUnitDimensions.ENERGY)).toBe(true)
		local power = MetricUnitDimensions.combine(energy, MetricUnitDimensions.TIME, -1)
		expect(MetricUnitDimensions.equal(power, MetricUnitDimensions.POWER)).toBe(true)
		local pressure = MetricUnitDimensions.combine(force, MetricUnitDimensions.AREA, -1)
		expect(MetricUnitDimensions.equal(pressure, MetricUnitDimensions.PRESSURE)).toBe(true)
		expect((MetricUnitDimensions.fromName("dataRate"))).toEqual({ memory = 1, time = -1 })
	end)

	it("tells equal dimensions apart", function()
		expect(MetricUnitDimensions.equal({ length = 1, time = -1 }, MetricUnitDimensions.SPEED)).toBe(true)
		expect(MetricUnitDimensions.equal({ length = 1 }, MetricUnitDimensions.SPEED)).toBe(false)
	end)
end)
