--!nonstrict
--[[
	@class DeathReportUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local DeathReportUtils = require("DeathReportUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("DeathReportUtils.isDeathReport(deathReport)", function()
	it("should return true for a valid death report table", function()
		expect(DeathReportUtils.isDeathReport({ type = "deathReport" })).toEqual(true)
	end)

	it("should return false for nil", function()
		expect(DeathReportUtils.isDeathReport(nil)).toEqual(false)
	end)

	it("should return false for a table with wrong type", function()
		expect(DeathReportUtils.isDeathReport({ type = "other" })).toEqual(false)
	end)
end)

describe("DeathReportUtils.getDefaultColor()", function()
	it("should return a Color3", function()
		local color = DeathReportUtils.getDefaultColor()
		expect(typeof(color)).toEqual("Color3")
	end)
end)
