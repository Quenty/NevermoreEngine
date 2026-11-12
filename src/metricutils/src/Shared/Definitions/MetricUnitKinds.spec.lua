--!strict
--[[
	@class MetricUnitKinds.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUnitDimensionUtils = require("MetricUnitDimensionUtils")
local MetricUnitKinds = require("MetricUnitKinds")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("MetricUnitKinds", function()
	it("derives every kind from the base dimensions", function()
		expect(MetricUnitKinds.DENSITY).toEqual({ mass = 1, length = -3 })
		expect(MetricUnitKinds.POWER).toEqual({ mass = 1, length = 2, time = -3 })
		expect(MetricUnitKinds.VOLTAGE).toEqual({ mass = 1, length = 2, time = -3, current = -1 })
		expect(MetricUnitKinds.RESISTANCE).toEqual({ mass = 1, length = 2, time = -3, current = -2 })
		expect(MetricUnitKinds.CAPACITANCE).toEqual({ mass = -1, length = -2, time = 4, current = 2 })
		expect(MetricUnitKinds.MAGNETIC_FLUX_DENSITY).toEqual({ mass = 1, time = -2, current = -1 })
	end)

	it("reads a kind's dimensions and absoluteness from its name", function()
		expect((MetricUnitKinds.fromName("dataRate"))).toEqual({ memory = 1, time = -1 })
		expect((MetricUnitKinds.fromName("none"))).toBe(MetricUnitDimensionUtils.NONE)
		expect(select(2, MetricUnitKinds.fromName("temperature"))).toBe(true)
		expect(select(2, MetricUnitKinds.fromName("temperatureDifference"))).toBe(false)
		expect((MetricUnitKinds.fromName({ length = 4 }))).toEqual({ length = 4 })
		expect(function()
			MetricUnitKinds.fromName("velocity" :: any)
		end).toThrow('no kind named "velocity"')
	end)

	it("names the kind of a set of dimensions", function()
		expect(MetricUnitKinds.getKind(MetricUnitKinds.SPEED, false)).toBe("speed")
		expect(MetricUnitKinds.getKind(MetricUnitKinds.TEMPERATURE, true)).toBe("temperature")
		expect(MetricUnitKinds.getKind(MetricUnitKinds.TIME, true)).toBe("instant")
		expect(MetricUnitKinds.getKind(MetricUnitDimensionUtils.NONE, false)).toBe("none")
		expect(MetricUnitKinds.getKind({ length = 4 }, false)).toBeNil()
	end)

	it("describes a kind, absolute or a difference", function()
		expect(MetricUnitKinds.describeKind(MetricUnitKinds.TEMPERATURE, true)).toBe("absolute temperature")
		expect(MetricUnitKinds.describeKind(MetricUnitKinds.TEMPERATURE, false)).toBe("temperature difference")
		expect(MetricUnitKinds.describeKind(MetricUnitKinds.TIME, true)).toBe("instant")
		expect(MetricUnitKinds.describeKind(MetricUnitKinds.SPEED, false)).toBe("length/time")
	end)
end)
