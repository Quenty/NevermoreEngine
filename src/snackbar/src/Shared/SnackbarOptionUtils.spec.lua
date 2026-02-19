--!nonstrict
--[[
	@class SnackbarOptionUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local SnackbarOptionUtils = require("SnackbarOptionUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("SnackbarOptionUtils.isSnackbarOptions(options)", function()
	it("should accept an empty table", function()
		expect(SnackbarOptionUtils.isSnackbarOptions({})).toEqual(true)
	end)

	it("should accept a table with a string CallToAction", function()
		expect(SnackbarOptionUtils.isSnackbarOptions({ CallToAction = "Undo" })).toEqual(true)
	end)

	it("should reject a non-table value", function()
		local result = SnackbarOptionUtils.isSnackbarOptions(5)
		expect(result).toEqual(false)
	end)
end)
