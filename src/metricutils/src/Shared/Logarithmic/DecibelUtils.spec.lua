--!strict
--[[
	@class DecibelUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local DecibelUtils = require("DecibelUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("DecibelUtils", function()
	it("uses 20 log10 for amplitude ratios", function()
		expect(DecibelUtils.amplitudeToDecibels(1)).toBe(0)
		expect(DecibelUtils.amplitudeToDecibels(10)).toBeCloseTo(20, 9)
		expect(DecibelUtils.amplitudeToDecibels(0.5)).toBeCloseTo(-6.0206, 4)
		expect(DecibelUtils.decibelsToAmplitude(-20)).toBeCloseTo(0.1, 12)
		expect(DecibelUtils.amplitudeToDecibels(0)).toBe(-math.huge)
	end)

	it("uses 10 log10 for power ratios", function()
		expect(DecibelUtils.powerToDecibels(10)).toBeCloseTo(10, 9)
		expect(DecibelUtils.powerToDecibels(2)).toBeCloseTo(3.0103, 4)
		expect(DecibelUtils.decibelsToPower(-10)).toBeCloseTo(0.1, 12)
	end)

	it("round trips, and adds gains where ratios multiply", function()
		expect(DecibelUtils.decibelsToAmplitude(DecibelUtils.amplitudeToDecibels(0.37))).toBeCloseTo(0.37, 12)
		local gain = DecibelUtils.amplitudeToDecibels(0.5) + DecibelUtils.amplitudeToDecibels(0.5)
		expect(DecibelUtils.decibelsToAmplitude(gain)).toBeCloseTo(0.25, 12)
	end)
end)
