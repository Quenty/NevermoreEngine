--!nonstrict
--[[
	@class MaidTaskUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MaidTaskUtils = require("MaidTaskUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("MaidTaskUtils.isValidTask(job)", function()
	it("should return true for a function", function()
		expect(MaidTaskUtils.isValidTask(function() end)).toEqual(true)
	end)

	it("should return false for a number", function()
		expect(MaidTaskUtils.isValidTask(5)).toEqual(false)
	end)

	it("should return false for a string", function()
		expect(MaidTaskUtils.isValidTask("hello")).toEqual(false)
	end)

	it("should return true for a table with Destroy method", function()
		expect(MaidTaskUtils.isValidTask({ Destroy = function() end })).toEqual(true)
	end)

	it("should return false for nil", function()
		expect(MaidTaskUtils.isValidTask(nil)).toEqual(false)
	end)
end)
