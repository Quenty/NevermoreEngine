--!nonstrict
--[[
	@class SoundGroupPathUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local SoundGroupPathUtils = require("SoundGroupPathUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("SoundGroupPathUtils.isSoundGroupPath(soundGroupPath)", function()
	it("should return true for a string", function()
		expect(SoundGroupPathUtils.isSoundGroupPath("a")).toEqual(true)
	end)

	it("should return false for a non-string", function()
		expect(SoundGroupPathUtils.isSoundGroupPath(5 :: any)).toEqual(false)
	end)
end)

describe("SoundGroupPathUtils.toPathTable(soundGroupPath)", function()
	it("should split a dotted path into a table", function()
		local result = SoundGroupPathUtils.toPathTable("a.b.c")
		expect(result).toEqual({ "a", "b", "c" })
	end)

	it("should return a single-element table for a simple path", function()
		local result = SoundGroupPathUtils.toPathTable("master")
		expect(result).toEqual({ "master" })
	end)
end)
