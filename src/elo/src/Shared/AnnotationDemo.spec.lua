--!strict
--[[
	[DO NOT MERGE] Deliberate failures to show test failure annotations in CI.
	@class AnnotationDemo.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local EloUtils = require("EloUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("AnnotationDemo", function()
	it("fails an assertion in the spec", function()
		local expected = EloUtils.getPlayerOneExpected(EloUtils.createConfig(), 1400, 1400)
		expect(expected).toBe(0.75)
	end)

	it("errors inside the package source", function()
		EloUtils.getNewElo({} :: any, 1400, 1800, {})
	end)
end)
