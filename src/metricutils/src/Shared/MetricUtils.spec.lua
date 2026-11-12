--!strict
--[[
	@class MetricUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUtils = require("MetricUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("MetricUtils.getSoundDelaySeconds", function()
	it("takes one second for sound to cross 343 meters", function()
		expect(MetricUtils.getSoundDelaySeconds(343 * 3.57)).toBeCloseTo(1, 9)
	end)

	it("is zero at zero distance", function()
		expect(MetricUtils.getSoundDelaySeconds(0)).toBe(0)
	end)
end)

describe("MetricUtils.studsToMeters", function()
	it("converts at 3.57 studs per meter", function()
		expect(MetricUtils.studsToMeters(357)).toBeCloseTo(100, 9)
		expect(MetricUtils.studsToMeters(-3.57)).toBeCloseTo(-1, 9)
		expect(MetricUtils.studsToMeters(0)).toBe(0)
	end)
end)

describe("MetricUtils.studsToKilometers", function()
	it("converts studs to kilometers", function()
		expect(MetricUtils.studsToKilometers(3570)).toBeCloseTo(1, 9)
		expect(MetricUtils.studsToKilometers(0)).toBe(0)
	end)
end)

describe("MetricUtils.studsPerSecondToMetersPerSecond", function()
	it("converts a stud velocity to meters per second", function()
		expect(MetricUtils.studsPerSecondToMetersPerSecond(35.7)).toBeCloseTo(10, 9)
	end)
end)

describe("MetricUtils.studsPerSecondToKph", function()
	it("converts a stud velocity to kilometers per hour", function()
		expect(MetricUtils.studsPerSecondToKph(3.57)).toBeCloseTo(3.6, 9)
	end)
end)

describe("MetricUtils.studsPerSecondToMph", function()
	it("converts a stud velocity to miles per hour", function()
		expect(MetricUtils.studsPerSecondToMph(3.57 * 0.44704)).toBeCloseTo(1, 9)
	end)
end)

describe("MetricUtils.kphToStudsPerSecond", function()
	it("converts kilometers per hour to a stud velocity", function()
		expect(MetricUtils.kphToStudsPerSecond(3.6)).toBeCloseTo(3.57, 9)
	end)

	it("inverts studsPerSecondToKph", function()
		expect(MetricUtils.kphToStudsPerSecond(MetricUtils.studsPerSecondToKph(16))).toBeCloseTo(16, 9)
	end)
end)

describe("MetricUtils.mphToStudsPerSecond", function()
	it("converts miles per hour to a stud velocity", function()
		expect(MetricUtils.mphToStudsPerSecond(1)).toBeCloseTo(3.57 * 0.44704, 9)
	end)

	it("inverts studsPerSecondToMph", function()
		expect(MetricUtils.mphToStudsPerSecond(MetricUtils.studsPerSecondToMph(16))).toBeCloseTo(16, 9)
	end)
end)
